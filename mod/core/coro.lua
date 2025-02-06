-- symmetric coroutines from the paper at
--     http://www.inf.puc-rio.br/~roberto/docs/corosblp.pdf
-- Written by Cosmin Apreutesei. Public Domain.

-- Reworked from the (in)famous coro lib
---@diagnostic disable: duplicate-set-field

local old_create = coroutine.create;
local old_close = coroutine.close;
local old_running = coroutine.running;
local old_status = coroutine.status;
local old_resume = coroutine.resume;
local old_yield = coroutine.yield;
--- @diagnostic disable-next-line: deprecated

local main, is_main = coroutine.running();
if main ~= nil and not is_main then
	error "This library must be initialized in the main thread";
elseif main == nil then
	main = old_create(function () end);
	old_resume(main);
end

local threads = setmetatable({}, { __mode = "k" });
local resumers = setmetatable({}, { __mode = "k" });
local responsible = setmetatable({}, { __mode = "k" });

local current = main;

threads[main] = "main";

local function assert_thread(thread, level)
	if type(thread) ~= "thread" then
		local err = string.format("coroutine expected but %s given", type(thread));
		error(err, level);
	end

	return thread;
end

local function unprotect(thread, ok, ...)
	if not ok then
		local s = debug.traceback(thread, (...));
		s = string.gsub(s, "stack traceback:", tostring(thread) .. " stack traceback:");
		error(s, 2);
	end
	return ...;
end

local function finish(thread, ...)
	local caller = resumers[thread];
	if not caller then
		error("coroutine ended without transferring control", 4);
	end
	return caller, true, ...;
end

local function go(thread, arg_box)
	while true do
		current = thread
		if thread == main then
			-- transfer to the main thread: stop the scheduler.
			return unbox(arg_box);
		end

		-- transfer to a coroutine: resume it and check the result.
		arg_box = box(old_resume(thread, unbox(arg_box)));

		if not arg_box[1] then
			-- the coroutine finished with an error. pass the error back to the
			-- caller thread, or to the main thread if there's no caller thread.
			thread = resumers[thread] or main;
			arg_box = box(arg_box[1], arg_box[2], debug.traceback());
		else
			-- loop over the next transfer request.
			thread = arg_box[2];
			arg_box = rebox(arg_box, 3);
		end
	end
end
local coro = {};

function coro.create(f)
	local thread;
	thread = old_create(function(ok, ...)
		return finish(thread, f(...));
	end);
	responsible[thread] = current;
	return thread;
end

function coro.running()
	return current, current == main;
end

function coro.status(thread)
	assert_thread(thread, 2);
	return old_status(thread);
end

function coro.ptransfer(thread, ...)
	assert(thread ~= current, "trying to transfer to the running thread");

	if current ~= main then
		-- we're inside a coroutine: signal the transfer request by yielding.
		return old_yield(thread, true, ...);
	else
		-- we're in the main thread: start the scheduler.
		local arg_box = box(true, ...);

		while true do
			current = thread;

			if thread == main then
				-- transfer to the main thread: stop the scheduler.
				return unbox(arg_box);
			end

			-- transfer to a coroutine: resume it and check the result.
			arg_box = box(old_resume(thread, unbox(arg_box)));

			if not arg_box[1] then
				-- the coroutine finished with an error. pass the error back to the
				-- caller thread, or to the main thread if there's no caller thread.
				thread = responsible[thread] or main;
				arg_box = box(arg_box[1], arg_box[2], debug.traceback());
			else
				-- loop over the next transfer request.
				thread = arg_box[2];
				arg_box = rebox(arg_box, 3);
			end
		end
	end
end

function coro.transfer(thread, ...)
	-- print(current, ">", thread, ...);
	return unprotect(thread, coro.ptransfer(thread, ...));
end

function coro.wrap(f)
	local calling_thread, yielding_thread;
	local function yield(...)
		yielding_thread = current;
		return coro.transfer(calling_thread, ...);
	end
	local function finish(...)
		yielding_thread = nil;
		return coro.transfer(calling_thread, ...);
	end
	local function wrapper(...)
		return finish(f(yield, ...));
	end

	local thread = coro.create(wrapper);
	yielding_thread = thread;

	return function(...)
		resumers[thread] = calling_thread;
		calling_thread = current;
		assert(yielding_thread, "cannot transfer to dead coroutine");
		return coro.transfer(yielding_thread, ...);
	end, thread;
end

--- @generic T, T1, T2, T3, T4, T5, Args
--- @param f fun(yield: (fun(p1?: T1, p2?: T2, p3?: T3, p4?: T4, p5?: T5): ...), ...: Args)
--- @return fun(...: Args): fun(...): T1, T2, T3, T4, T5
function coro.gen(f)
	return function (...)
		local prev = box(...);

		return coro.wrap(function (yield)
			return f(yield, unbox(prev));
		end);
	end
end

function coro.close(t)
	if old_close == nil then
		return false, "Closing coroutines is not supported";
	else
		return old_close(t);
	end
end

local coroutine = {};

function coroutine.close(co)
	coro.close(co);
end
function coroutine.create(f)
	return coro.create(f);
end

function coroutine.isyieldable()
	return true;
end

function coroutine.resume(co, ...)
	resumers[co] = coro.running();
	responsible[co] = coro.running();
	return coro.ptransfer(co, ...);
end

function coroutine.yield(...)
	local cb = resumers[coro.running()];
	if cb == nil then
		error("Must call 'yield' from a thread that has been invoked asymmetrically", 2);
	end

	return coro.transfer(cb, ...);
end

function coroutine.wrap(f)
	local co = coroutine.create(f);

	return function (...)
		return assert(coroutine.resume(co, ...));
	end
end

function coroutine.running()
	return coro.running();
end

function coroutine.status(co)
	return coro.status(co);
end

return function (glob)
	glob.coroutine = coroutine;
	glob.coro = coro;
end

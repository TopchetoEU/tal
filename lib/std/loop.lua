local impl = require "impl";
local errors = require "std.errors";
local debug = require "std.basic.debug";
local traced_err = require "std.errors.traced_err";
local error = errors.throw;
require "std.basic.coroutine";

local loop = {};

local fork_i = 1;

--- @type { cb: thread | function, n: integer, [integer]: ... }[]
local queue = {};
--- @type { time: number, cb: thread | function, n: integer, [integer]: ... }[]
local sleeps = {};
--- @type thread?
local loop_th;

local run_loop;

local function process_handle(next, timeout, cb, ...)
	if cb == nil then
		if not timeout then return false end
	elseif cb == coroutine.running() then
		return true, ...;
	else
		loop_th = coroutine.running();
		local ok, e;
		if type(cb) == "function" then
			ok, e = errors.spcall(cb, ...);
		else
			ok, e = cb:resume(...);
		end
		loop_th = nil;

		-- An error from another thread, completely unrelated to ours could've thrown this.
		-- This causes seemingly innocent IO operations to vomit out other threads' errors.
		-- TODO: invent an 'elegant' way to avoid printing the IO op's stack trace
		if not ok then error(e) end
	end

	return next();
end
local function has_non_daemons()
	for i = 1, #sleeps do
		if type(sleeps[i].cb) == "thread" and not sleeps[i].cb:is_daemon() then
			return true;
		end
	end

	for i = 1, #queue do
		if type(queue[i].cb) == "thread" and not queue[i].cb:is_daemon() then
			return true;
		end
	end

	for th in pairs(coroutine.get_cancels()) do
		th:cancel();
	end

	return false;
end

local function task_next()
	local task = table.remove(queue, 1);
	if task then
		return process_handle(task_next, nil, task.cb, table.unpack(task, 1, task.n));
	end

	local timeout;
	if #sleeps > 0 then timeout = sleeps[#sleeps].time end

	return process_handle(run_loop, timeout, impl:next(timeout));
end
function run_loop()
	local now = impl:time "mono";

	local f, l = 1, #sleeps;
	local result = nil;

	if not non_daemons then
		for i = 1, #sleeps do
			if type(sleeps[i].cb) == "thread" then
				sleeps[i].cb:cancel();
			end
		end
		for i = 1, #queue do
			if type(queue[i].cb) == "thread" then
				queue[i].cb:cancel();
			end
		end
		for th in pairs(coroutine.get_cancels()) do
			th:cancel();
		end
	end

	while f <= l do
		local mid = math.floor((f + l) / 2)
		if sleeps[mid].time <= now then
			result = mid;
			l = mid - 1;
		else
			f = mid + 1;
		end
	end

	if result then
		for i = #sleeps, result, -1 do
			table.insert(queue, table.remove(sleeps, i));
		end
	end

	return task_next();
end

--- @return ...
local function await_fin(status, ...)
	if status == nil then
		errors.throw(...);
	elseif status == false then
		errors.throw(errors.never);
	else
		return ...;
	end
end

--- @param task thread
function loop.push(task, ...)
	local pack = table.pack(...);
	pack.cb = task;
	table.insert(queue, pack);
end
function loop.rest()
	loop.push((coroutine.running()));
	return loop.await();
end
--- If no loop is running, runs the loop in the call. Otherwise, yields
--- @return ...
function loop.await()
	if not loop_th then
		return await_fin(run_loop());
	else
		assert(loop_th ~= coroutine.running(), "how?!?!");
		return coroutine.yield();
	end
end

local function sync_ret_handle(ok, ...)
	coroutine.set_cancel(nil, nil);
	if not ok then errors.throw(...) end
	return ...;
end

--- @param cancel? fun()
--- @param ... any
--- @return any ...
function loop.sync_ret(cancel, ...)
	if not cancel then return ... end
	coroutine.set_cancel(nil, cancel);
	return sync_ret_handle(loop.await());
end

function loop.fork(main, ...)
	local fork_trace = debug.traceback(nil, 2);

	local th = coroutine.create(function (...)
		local ok, err = errors.spcall(...);
		if not ok then
			if errors.is(err, errors.cancelled) then return end
			errors.throw(traced_err.new(err, "fork", fork_trace));
		end
	end);

	th:name("Fork " .. fork_i);
	loop.push(th, main, ...);
	loop.rest();

	fork_i = fork_i + 1;

	return th;
end
--- @param ts number
--- @param cb thread | function If a function is passed, it will be called with ... in the loop thread
function loop.wait_until(ts, cb, ...)
	local f, l = 1, #sleeps;

	while f <= l do
		local mid = math.floor((f + l) / 2);
		if sleeps[mid].time > ts then
			f = mid + 1;
		else
			l = mid - 1;
		end
	end

	local pack = table.pack(...);
	pack.cb = cb;
	pack.time = ts;
	table.insert(sleeps, f, pack);

	return function () table.delete(sleeps, pack) end;
end
function loop.run()
	if loop_th then return true end

	local status, e = run_loop();
	if status == true then
		return false, "unexpected result from loop run";
	elseif status == false then
		return true;
	else
		return false, e;
	end
end

return loop;

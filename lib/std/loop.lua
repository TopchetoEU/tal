local impl = require "impl";
local errors = require "std.errors";
local debug = require "std.basic.debug";
local traced_err = require "std.errors.traced_err";
local error = errors.throw;
require "std.basic.coroutine";

local loop = {};

local fork_i = 1;

--- @class std.loop.task
--- @field cb thread | function
--- @field ok boolean
--- @field n integer
--- @field [integer] any

--- @class std.loop.wait_task: std.loop.task
--- @field time number

--- @type table<thread, fun()>
local cancels = setmetatable({}, { __mode = "k" });
--- @type std.loop.task[]
local queue = {};
--- @type std.loop.wait_task[]
local sleeps = {};
--- @type thread?
local loop_th;

local run_loop;

--- @return boolean, ...
local function process_handle(next, timeout, cb, is_ok, ...)
	if cb == nil then
		return next();
	elseif cb == coroutine.running() then
		if is_ok then
			return true, ...;
		else
			error(...);
		end
	else
		loop_th = coroutine.running();
		local ok, e;
		if type(cb) == "function" then
			if not is_ok then error(...) end
			ok, e = errors.spcall(cb, ...);
		else
			ok, e = cb:resume(is_ok, ...);
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
	for th in pairs(cancels) do
		if not th:is_daemon() then
			return true;
		end
	end

	return false;
end

--- @return boolean, ...
local function task_next()
	local task = table.remove(queue, 1);
	if task then
		return process_handle(task_next, nil, task.cb, task.ok, table.unpack(task, 1, task.n));
	end

	local timeout;
	if #sleeps > 0 then timeout = sleeps[#sleeps].time end

	if timeout or next(cancels) then
		return process_handle(run_loop, timeout, impl:next(timeout));
	end

	return false;
end
--- @return boolean, ...
function run_loop()
	local now = impl:time "mono";

	if has_non_daemons() then
		while #sleeps > 0 and sleeps[#sleeps].time <= now do
			table.insert(queue, table.remove(sleeps));
		end
	else
		table.clear(sleeps);
		for i = 1, #queue do
			if type(queue[i].cb) == "thread" then
				queue[i].cb:cancel();
			end
		end
		for th in pairs(cancels) do
			th:cancel();
		end
	end

	return task_next();
end

--- @param task thread
function loop.resolve(task, ...)
	local pack = table.pack(...);
	pack.cb = task;
	pack.ok = true;
	table.insert(queue, pack);
end
--- @param err any
function loop.reject(task, err)
	table.insert(queue, { cb = task, n = 1, ok = false, err });
end

--- @return ...
local function await_fin_main(th, ok, status, ...)
	cancels[th] = nil;
	if not ok then error(status) end
	if not status then errors.throw "loop finished execution early" end
	return ...;
end
--- @param ok boolean
--- @return ...
local function await_fin_yield(th, ok, ...)
	cancels[th] = nil;
	if not ok then error((...)) end
	return ...;
end
--- If no loop is running, runs the loop in the call. Otherwise, yields
--- @param cancel? fun() If nil, directly returns/throws the other arguments
--- @param ok? boolean Upon a sync return, if true, returns the varargs, if false throws them
--- @param ... any
--- @return ...
function loop.await(cancel, ok, ...)
	coroutine.cancelpt();

	if not cancel then
		if ok then
			return ...;
		else
			error((...));
		end
	end

	local th = coroutine.running();
	cancels[th] = cancel or function () loop.reject(th, errors.cancelled) end;

	if not loop_th then
		return await_fin_main(th, pcall(run_loop));
	else
		assert(loop_th ~= th);
		return await_fin_yield(th, coroutine.yield());
	end
end
function loop.rest()
	loop.resolve((coroutine.running()));
	return loop.await(function () end);
end

function loop.fork(main, ...)
	local fork_trace = debug.traceback(nil, 2);

	local th = coroutine.create(function (_, ...)
		local ok, err = errors.spcall(...);
		if not ok then
			if errors.is(err, errors.cancelled) then return end
			errors.throw(traced_err.new(err, "fork", fork_trace));
		end
	end);

	th:name("Fork " .. fork_i);
	loop.resolve(th, main, ...);
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
	pack.ok = true;
	pack.cb = cb;
	pack.time = ts;
	table.insert(sleeps, f, pack);

	return function ()
		table.delete(sleeps, pack);
		loop.reject(cb, errors.cancelled);
	end;
end
function loop.run()
	if loop_th then return true end

	local status = run_loop();
	if status == true then
		return false, "unexpected result from loop run";
	end
end

--- Not like coroutine.cancel, this only cancels an action that blocks a thread that the loop manages
--- @param th thread
function loop.cancel(th)
	for i = #sleeps, 1, -1 do
		if sleeps[i].cb == th then
			table.remove(sleeps[i]);
			loop.resolve(th);
		end
	end

	local cancel = cancels[th];
	cancels[th] = nil;
	if cancel then cancel() end
end

return loop;

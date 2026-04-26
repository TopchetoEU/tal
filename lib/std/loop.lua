local impl = require "impl";

local loop = {};

--- @type table<thread, string>
local names = {};
local fork_i = 1;

--- @type { cb: thread, n: integer, [integer]: ... }[]
local tasks = {};
--- @type { time: number, cb: thread, n: integer, [integer]: ... }[]
local sleeps = {};
--- @type thread?
local loop_th;

debug.setmetatable(coroutine.running(), {
	__tostring = function (self)
		return loop.name(self);
	end
})

local run_loop;

local function process_handle(next, timeout, cb, ...)
	if cb == nil then
		if not timeout then
			loop_th = nil;
			return false;
		end
	elseif cb == loop_th then
		loop_th = nil;
		return true, ...;
	else
		local ok, err = coroutine.resume(cb, ...);
		if not ok then
			loop_th = nil;
			return nil, err;
		end
	end

	return next();
end

local function task_next()
	local task = table.remove(tasks, 1);
	if not task then
		local timeout;

		if #sleeps > 0 then
			timeout = sleeps[#sleeps].time;
		end

		return process_handle(run_loop, timeout, impl:next(timeout));
	end

	return process_handle(task_next, task.cb, table.unpack(task, 1, task.n));
end
function run_loop()
	loop_th = coroutine.running();

	local now = impl:monotime();

	local f, l = 1, #sleeps;
	local result = nil;

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
			table.insert(tasks, table.remove(sleeps, i));
		end
	end

	return task_next();
end

local function await_fin(status, ...)
	if status == nil then
		error(..., 0);
	elseif status == false then
		error("loop ended before main thread got invoked")
	else
		return ...;
	end
end

--- @param task thread
function loop.push(task, ...)
	if type(task) == "thread" then
		loop.push(loop.awake, task, ...);
	else
		table.insert(tasks, { cb = task, n = select("#", ...), ... });
	end
end
function loop.rest()
	loop.push((coroutine.running()));
	return loop.await();
end
--- If no loop is running, runs the loop in the call. Otherwise, yields
function loop.await()
	if not loop_th then
		return await_fin(run_loop());
	else
		return coroutine.yield();
	end
end

--- @generic ResT
--- @param sync boolean
--- @param res ResT
--- @param ... any
--- @return ResT
--- @return any ...
function loop.sync_ret(sync, res, ...)
	if sync then return res, ... end
	return loop.await();
end

function loop.fork(main, ...)
	local th = coroutine.create(function (...)
		local ok, err = xpcall(...);
		if not ok then return error(err, 0) end
	end);

	loop.name(th, "Fork " .. fork_i);
	loop.push(th, main, debug.traceback, ...);
	loop.rest();

	fork_i = fork_i + 1;

	return th;
end
--- @param ts number
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

	table.insert(sleeps, f, { time = ts, cb = cb, n = select("#", ...), ... });
end
function loop.run()
	if loop_th then return true end

	local status, err = run_loop();
	if status == true then
		return false, "unexpected result from loop run";
	elseif status == false then
		return true;
	else
		return false, err;
	end
end

--- @param th thread
--- @param name? string
function loop.name(th, name)
	if name then
		names[th] = name;
		return th;
	else
		return names[th] or "Unnamed thread";
	end
end

function loop.dbg_print()
	print(#tasks);
end

return loop;

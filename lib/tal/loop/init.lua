local libev = require "nat.libev";
require "tal.loop.evs";
local invoke = require "std.sync.invoke";

--- @class tal.looplib
--- @field curr tal.loop
local loop = {};

--- @class tal.loop
--- @field tasks (function | thread)[]
--- @field sleeps { time: number, task: (function | thread) }[]
--- @field ev ev
local loop_index = {};
local loop_meta = { __index = loop_index };

local function loop_with_fin(old, ...)
	if old then
		loop.curr = old;
	end
	return ...;
end
local function loop_with(self, ...)
	local old = loop.curr;
	loop.curr = self;
	return loop_with_fin(old, invoke(...));
end
local function loop_handle(self, cb, ...)
	if cb == false then
		return false;
	elseif cb == nil then
		return nil, ...;
	elseif cb == "timeout" then
		return "timeout";
	else
		local ok, err = loop_with(self, cb, ...);

		if ok then return true end
		return nil, err;
	end
end

--- @param task function | thread
function loop_index:push(task, ...)
	if select("#", ...) > 0 then
		table.insert(self.tasks, { cb = task, n = select("#", ...), ... });
	else
		table.insert(self.tasks, task);
	end
end
function loop_index:fork(func, ...)
	local ok, err = loop_with(self, coroutine.create(func), ...);
	if not ok then error(err, 0) end
end
function loop_index:rest()
	self:push(coroutine.running());
	return coroutine.yield();
end
--- @param ts number
function loop_index:wait_until(ts)
	local f, l = 1, #self.sleeps;

	while f <= l do
		local mid = math.floor((f + l) / 2);
		if self.sleeps[mid].time > ts then
			f = mid + 1;
		else
			l = mid - 1;
		end
	end

	table.insert(self.sleeps, f, { time = ts, task = coroutine.running() });
	coroutine.yield();
end
function loop_index:run()
	while true do
		local now = libev.monotime();

		local f, l = 1, #self.sleeps;
		local result = nil;

		while f <= l do
			local mid = math.floor((f + l) / 2)
			if self.sleeps[mid].time <= now then
				result = mid;
				l = mid - 1;
			else
				f = mid + 1;
			end
		end

		if result then
			for i = #self.sleeps, result, -1 do
				table.insert(self.tasks, table.remove(self.sleeps, i).task);
			end
		end

		while #self.tasks > 0 do
			local task = table.remove(self.tasks, 1);
			local ok, err = loop_handle(self, task);
			if not ok then return nil, err end
		end

		local timeout;

		if #self.sleeps > 0 then
			timeout = self.sleeps[#self.sleeps].time;
		end

		if not timeout and not self.ev:busy() then return true end

		local ok, err = loop_handle(self, self.ev:poll(timeout));
		if ok == nil then return nil, err end
	end
end

--- @param task function | thread
function loop.push(task, ...)
	if not loop.curr then error("loop not running", 2) end
	return loop.curr:push(task, ...);
end
function loop.fork(func, ...)
	if not loop.curr then error("loop not running", 2) end
	return loop.curr:fork(func, ...);
end
function loop.rest()
	return loop.curr:rest();
end
--- @param ts number
function loop.wait_until(ts)
	return loop.curr:wait_until(ts);
end
--- @param ev ev
--- @param entry function | thread
function loop.run(ev, entry, ...)
	if loop.curr then return nil, "loop already running" end
	local curr = loop.new(ev);
	curr:fork(entry, ...);
	return curr:run();
end

--- @param ev ev
function loop.new(ev)
	return setmetatable({
		ev = ev,
		tasks = {},
		sleeps = {},
	}, loop_meta);
end

return loop;

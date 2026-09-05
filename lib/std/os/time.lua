local loop = require "std.loop";
local libev= require "nat.libev";

local time = {};

function time.now()
	return libev.realtime();
end
function time.monotime()
	return libev.monotime();
end

--- @param timestamp number
function time.sleep_until(timestamp)
	return iassert(loop.sync_ret(loop.wait_until(timestamp, coroutine.running(), true)));
end
--- @param secs number
function time.sleep(secs)
	return time.sleep_until(time.monotime() + secs);
end

function time.timer(delay)
	local base = time.monotime();
	local last = base;
	local i = 0;

	return function ()
		i = i + 1;
		time.sleep_until(base + delay * i);

		local curr = time.monotime();
		local delta = curr - last;
		last = curr;
		return delta;
	end
end

return time;

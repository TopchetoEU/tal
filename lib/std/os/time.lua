local loop = require "std.loop";
local impl = require "impl";

local time = {};

--- @param kind? "mono" | "real" | "cpu" = "mono"
function time.time(kind)
	return impl:time(kind or "mono");
end

--- @deprecated use time.time "real"
function time.now()
	return impl:time "real";
end
--- @deprecated use time.time "mono"
function time.monotime()
	return impl:time "mono";
end

--- @param timestamp number
function time.sleep_until(timestamp)
	return iassert(loop.sync_ret(loop.wait_until(timestamp, coroutine.running(), true)));
end
--- @param secs number
function time.sleep(secs)
	return time.sleep_until(time.time "mono" + secs);
end

function time.timer(delay)
	local base = time.time "mono";
	local last = base;
	local i = 0;

	return function ()
		i = i + 1;
		time.sleep_until(base + delay * i);

		local curr = time.time "mono";
		local delta = curr - last;
		last = curr;
		return delta;
	end
end

return time;

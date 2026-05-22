local loop = require "std.loop";
local libev= require "nat.libev";

local timing = {};

function timing.now()
	return libev.realtime();
end
function timing.monotime()
	return libev.monotime();
end

--- @param timestamp number
function timing.sleep_until(timestamp)
	return iassert(loop.await(loop.wait_until(timestamp, coroutine.running(), loop.awake), true));
end
--- @param secs number
function timing.sleep(secs)
	return timing.sleep_until(timing.monotime() + secs);
end

function timing.timer(delay)
	local base = timing.monotime();
	local last = base;
	local i = 0;

	return function ()
		i = i + 1;
		timing.sleep_until(base + delay * i);

		local curr = timing.monotime();
		local delta = curr - last;
		last = curr;
		return delta;
	end
end

return timing;

local loop = require "tal.loop";
local libev= require "nat.libev";

local timing = {};

function timing.now()
	return libev.realtime();
end
function timing.monotime()
	return libev.monotime();
end

function timing.sleep(secs)
	return loop.wait_until(timing.monotime() + secs);
end
function timing.timer(delay)
	local base = timing.monotime();
	local last = base;
	local i = 0;

	return function ()
		i = i + 1;
		loop.wait_until(base + delay * i);

		local curr = timing.monotime();
		local delta = curr - last;
		last = curr;
		return delta;
	end
end

return timing;

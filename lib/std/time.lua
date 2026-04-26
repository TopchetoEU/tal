local loop = require "std.loop";
local libev= require "nat.libev";

local timing = {};

function timing.now()
	return libev.realtime();
end
function timing.monotime()
	return libev.monotime();
end

--- @generic CtxT
--- @param time number
--- @param ctx CtxT
--- @param cb fun(ctx: CtxT, ...)
function timing.sleep_until_async(time, ctx, cb, ...)
	return loop.wait_until(time, cb, ctx, ...);
end
--- @generic CtxT
--- @param secs number
--- @param ctx CtxT
--- @param cb fun(ctx: CtxT, ...)
function timing.sleep_async(secs, ctx, cb, ...)
	return timing.sleep_until_async(timing.monotime() + secs, ctx, cb, ...);
end
--- @generic CtxT
--- @param time number
function timing.sleep_until(time)
	return loop.await(timing.sleep_until_async(time, coroutine.running(), loop.awake));
end
--- @generic CtxT
--- @param secs number
function timing.sleep(secs)
	return loop.await(timing.sleep_async(secs, coroutine.running(), loop.awake));
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

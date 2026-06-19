-- Demonstrates tal's concurrent capabilities

local loop = require "std.loop";
local time = require "std.os.time";

return function ()
	loop.fork(function ()
		while true do
			time.sleep(.5);
			print("a");
		end
	end)
	loop.fork(function ()
		while true do
			time.sleep(.3333);
			print("b");
		end
	end)
end

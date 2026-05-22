-- An example use of tal's pipes

local pipe = require "std.sync.pipe";
local loop = require "std.loop";

return function()
	loop.fork(function()
		local pin = pipe.new();
		local pout = pipe.new();

		loop.fork(function()
			while true do
				local num = pin:read();
				if not num then break end

				pout:write(math.sqrt(num));
			end
		end);

		for i = 1, 100 do
			pin:write(i);
			print("SQRT", pout:read());
		end
	end);

	loop.fork(function()
		for i = 1, 100 do
			print(i);
			-- In long blocking loops, use this to not suffocate the other threads
			loop.rest();
		end
	end)
end

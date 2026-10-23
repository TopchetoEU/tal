local fs = require "std.os.fs";

local function ask(prompt)
	local rawend = fs.ttyraw();

	io.stderr:write(prompt, " [y/n] ");

	local answer;

	while answer == nil do
		local c = io.stdin:read(1);
		if c == "y" then
			io.stderr:write(c);
			answer = true;
			break;
		elseif c == "n" then
			io.stderr:write(c);
			answer = false;
			break;
		end
	end

	rawend();
	io.stderr:write "\n";

	return answer;
end

return function ()
	print(ask "Are we using curses?");

end

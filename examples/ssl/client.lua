local ssl = require "std.io.ssl";
local loop = require "std.loop";
local utils = require "examples.ssl.utils";
local json = require "std.fmt.json";
local net = require "std.io.net";
local argp = require "std.fmt.argp";

return function (...)
	local argv = argp.new(...);

	local ip = "127.0.0.1";
	local port = 4312;
	local username;

	for arg, isopt in argv:iter() do
		if isopt then
			if arg == "--addr" then
				ip = argv:pop();
			elseif arg == "--port" then
				port = assert(tonumber(argv:pop(), 10), "invalid port");
			elseif arg == "--username" or arg == "-u" then
				username = argv:pop();
			else
				error("unknown option '" .. arg .. "'");
			end
		else
			error("unexpected argument '" .. arg .. "'");
		end
	end

	local f = ssl { backend = assert(net.connect(ip, port)), owned = true, role = "client" };

	if not username then
		io.stderr:write "Username: ";
		username = io.stdin:read "l";
	end

	loop.fork(function ()
		while true do
			local cmd = json.parse(assert(utils.read_string(f)));
			utils.print_event(cmd);
		end
	end);

	loop.fork(function ()
		utils.write_string(f, username);
		f:flush();

		for line in io.lines() do
			if line:find "^%/" then
				utils.write_string(f, json.stringify {
					type = "cmd",
					cmd = line:sub(2),
				});
			else
				utils.write_string(f, json.stringify {
					type = "msg",
					msg = line,
				});
			end

			f:flush();
		end
		f:close();
	end);
end

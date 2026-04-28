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
	local rest;

	while argv:has() do
		local opts = not rest and argv:popopt() or nil;
		if opts then
			for opt in opts do
				if opt == "--" then
					rest = true;
				elseif opt == "--addr" then
					ip = argv:apop "expected address";
				elseif opt == "--port" then
					port = assert(tonumber(argv:apop "expected port", 10), "invalid port");
				elseif opt == "--username" or opt == "-u" then
					username = argv:apop "expected username";
				else
					error("unknown option '" .. opt .. "'");
				end
			end
		else
			error("unexpected argument '" .. argv:pop() .. "'");
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

local ssl = require "std.io.ssl";
local loop = require "std.loop";
local utils = require "examples.ssl.utils";
local json = require "std.fmt.json";
local net = require "std.io.net";
local argp = require "std.argp";
local signal = require "std.os.signal";

return function (...)
	signal.on "INT";
	signal.on "BADPIPE";
	loop.fork(function ()
		for sig in signal.wait do
			if sig == "INT" then error "interrupted" end
		end
	end):name "INT listener";

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

	local f = ssl { backend = net.connect(ip, port), owned = true, role = "client" };

	if not username then
		io.stderr:write "Username: ";
		username = io.stdin:read "l";
	end

	loop.fork(function ()
		for raw in utils.read_string, f do
			local cmd = json.parse(raw);
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

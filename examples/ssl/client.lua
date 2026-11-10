local argp = require "std.argp";
local loop = require "std.loop";
local json = require "std.fmt.json";
local net = require "std.os.net";
local signal = require "std.os.signal";
local ssl = require "std.proto.ssl";
local pipe = require "std.sync.pipe";

local utils = require "examples.ssl.utils";

return function (...)
	local sigs = pipe.new();
	signal.mute "BADPIPE";
	signal.on("INT", sigs);

	loop.fork(function ()
		sigs:read();
		error "interrupted";
	end):name "INT listener":daemon(true);

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

	local conn = ssl.new { backend = net.connect(ip, port), owned = true, role = "client" }:to_text();

	if not username then
		io.stderr:write "Username: ";
		username = io.stdin:read "l";
	end

	local sender = loop.fork(function ()
		utils.write_string(conn, username);
		conn:flush();

		for line in io.lines() do
			if line:find "^%/" then
				utils.write_string(conn, json.stringify {
					type = "cmd",
					cmd = line:sub(2),
				});
			else
				utils.write_string(conn, json.stringify {
					type = "msg",
					msg = line,
				});
			end

			conn:flush();
		end
		conn:close();
	end);

	loop.fork(function ()
		for raw in utils.read_string, conn do
			local cmd = json.parse(raw);
			utils.print_event(cmd);
		end

		sender:cancel();
	end);
end

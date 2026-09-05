local ssl = require "std.pipes.ssl";
local io = require "std.io";
local loop = require "std.loop";
local pipe = require "std.sync.pipe";
local utils = require "examples.ssl.utils";
local net = require "std.os.net";
local json = require "std.fmt.json";
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

	local ip = "0.0.0.0";
	local port = 4312;
	local cert_p, key_p;
	local rest;

	for arg, isopt in argv:iter() do
		if isopt then
			if arg == "--addr" then
				ip = argv:pop();
			elseif arg == "--port" then
				port = assert(tonumber(argv:pop(), 10), "invalid port");
			elseif arg == "--cert" then
				cert_p = argv:pop();
			elseif arg == "--key" then
				key_p = argv:pop();
			else
				error("unknown option '" .. arg .. "'");
			end
		else
			error("unexpected argument '" .. arg .. "'");
		end
	end

	assert(cert_p, "--cert must be specified");
	assert(key_p, "--key must be specified");

	local res = assert(net.getaddrinfo(ip, "b"));
	assert(#res > 0, "bind address not resolved");

	local f = assert(io.open(cert_p));
	local cert = f:read "a";
	f:close();

	local f = assert(io.open(key_p));
	local key = f:read "a";
	f:close();

	local server = net.bind(ip or "127.0.0.1", port or 4312);

	local broadcast_pipe = pipe.new();
	--- @type table<std.strtxt, true>
	local conns = {};
	local i = 1;

	loop.fork(function ()
		while true do
			local msg = broadcast_pipe:read();
			utils.print_event(msg);
			for conn in pairs(conns) do
				utils.write_string(conn, json.stringify(msg));
				conn:flush();
			end
		end
	end);

	for conn, conn_ip, conn_port in server:iter() do
		loop.fork(function ()
			print("Connection from " .. conn_ip .. ":" .. conn_port);
			local sconn = ssl.new { backend = conn, owned = true, role = "server", key = key, cert = cert }:to_text();
			conns[sconn] = true;

			local username;

			local ok, err, trace = spcall(function ()
				username = assert(utils.read_string(sconn), "expected username");
				i = i + 1;

				broadcast_pipe:write { type = "join", who = username };

				for raw in utils.read_string, sconn do
					local msg, err = json.parse(raw);

					if msg.type == "username" then
						username = msg.username;
					elseif msg.type == "msg" then
						broadcast_pipe:write { type = "msg", from = username, msg = msg.msg };
					elseif msg.type == "cmd" then
						local cmd, args = msg.cmd:match "(%S+)%s-(.*)";

						if cmd == "leave" then
							break;
						elseif cmd == "shout" then
							broadcast_pipe:write { type = "shout", from = username, msg = args };
						elseif cmd == "help" then
							utils.write_string(sconn, json.stringify {
								type = "system",
								msg = "Supported commands: /leave /shout [what] /help"
							});
						else
							utils.write_string(sconn, json.stringify {
								type = "system",
								msg = "Bad syntax with your command"
							});
						end
					end

					if err then error(err) end
					if not msg then break end
				end
			end, debug.traceback);

			if not ok then eprint(err, trace, "in client handler") end

			sconn:close();
			conns[sconn] = nil;

			if username then
				broadcast_pipe:write { type = "leave", who = username };
			end
		end);
	end
end

local ssl = require "std.io.ssl";
local io = require "std.io";
local loop = require "std.loop";
local pipe = require "std.sync.pipe"
local utils = require "examples.ssl.utils";
local net = require "std.io.net";
local json = require "std.fmt.json";
local argp = require "std.fmt.argp";

return function (...)
	local argv = argp.new(...);

	local ip = "0.0.0.0";
	local port = 4312;
	local cert_p, key_p;
	local rest;

	for arg, isopt in argv:iter() do
		if isopt then
			if arg == "--addr" then
				ip = argv:pop "expected address";
			elseif arg == "--port" then
				port = assert(tonumber(argv:pop "expected port", 10), "invalid port");
			elseif arg == "--cert" then
				cert_p = argv:pop "expected cert file";
			elseif arg == "--key" then
				key_p = argv:pop "expected key file";
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
	local cert = assert(f:read "a");
	f:close();

	local f = assert(io.open(key_p));
	local key = assert(f:read "a");
	f:close();

	local server = assert(net.bind(ip or "127.0.0.1", port or 4312));

	local broadcast_pipe = pipe();
	--- @type table<std.io.stream, true>
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

	loop.fork(function ()
		while true do
			local conn = assert(server:next());

			loop.fork(function ()
				print("Connection from " .. conn.ip .. ":" .. conn.port);
				local sconn = ssl { backend = conn.client, owned = true, role = "server", key = key, cert = cert };
				conns[sconn] = true;

				local username;

				local ok, err = xpcall(function ()
					username = assert(utils.read_string(sconn));
					i = i + 1;

					broadcast_pipe:write { type = "join", who = username };

					while true do
						local msg, err = json.parse(assert(utils.read_string(sconn)));

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

				if not ok then
					print(err);
				end

				sconn:close();
				conns[sconn] = nil;

				if username then
					broadcast_pipe:write { type = "leave", who = username };
				end
			end);
		end
	end);
end

local url = require "std.http.url";
local net = require "std.os.net";
local headers = require "std.http.headers";
local http = require "std.http";
local ssl = require "std.pipes.ssl";
local sig = require "std.sig";
local ffi = require "nat.ffi"

--- @param arg { url: string, method?: string, headers?: std.http.headers, body?: string | std.str | fun(): string? }
return function (arg)
	local parsed = url.parse(arg.url);
	if not parsed.scheme then sig.error("arg.url", "scheme must be specified") end
	if
		parsed.scheme ~= "http" and
		parsed.scheme ~= "https"
	then sig.error("arg.url", "only http and https supported") end
	if not parsed.host then sig.error("arg.url", "host must be specified") end
	if parsed.username or parsed.password then sig.error("arg.url", "username and password not supported") end

	if not arg.headers then
		arg.headers = headers.new();
	end

	if not arg.headers:get "host" then
		arg.headers:add("host", parsed.host);
	end

	local default_port = 80;
	if parsed.scheme == "https" then
		default_port = 443;
	end

	local conn = net.nameconnect(parsed.host, parsed.port or default_port, "tcp");

	if parsed.scheme == "https" then
		conn = ssl.new { backend = conn, owned = true, host = parsed.host };
	end

	local body_out = http.write_req(conn, {
		method = arg.method or "GET",
		path = url.stringify { path = parsed.path, params = parsed.params },
		headers = arg.headers,
	}, arg.body ~= nil);

	if arg.body then
		--- @cast body_out std.str

		if type(arg.body) == "string" then
			body_out:fullwrite(ffi.toptr(arg.body));
		elseif type(arg.body) == "function" then
			for el in arg.body do
				body_out:fullwrite(ffi.toptr(el));
			end
		else
			body_out:pipe(arg.body);
		end

		body_out:close();
	end

	local res = assert(http.read_res(conn), "no response");
	return res;
end

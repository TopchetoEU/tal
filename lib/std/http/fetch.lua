local url = require "std.fmt.url";
local net = require "std.io.net";
local headers = require "std.http.headers";
local http = require "std.http";
local ssl = require "std.io.ssl";
local sig = require "std.sig";

--- @param arg { url: string, method?: string, headers?: std.http.headers, body?: string | std.io.stream | fun(): string? }
return function (arg)
	local parsed = url.parse(arg.url);
	if not parsed.scheme then sig.error("arg.url", "scheme must be specified") end
	if
		parsed.scheme ~= "http" and
		parsed.scheme ~= "https"
	then sig.error("arg.url", "only http and https supported") end
	if not parsed.host then sig.error("arg.url", "host must be specified") end
	if parsed.username or parsed.password then sig.error("arg.url", "username and password not supported") end

	local dns_res = net.getaddrinfo(parsed.host, "");

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

	local ok, conn;
	for i = 1, #dns_res do
		ok, conn = pcall(net.connect, dns_res[i], parsed.port or default_port);
		if ok then break end
	end

	if not ok then error(conn) end
	if not conn then error("unknown host") end

	if parsed.scheme == "https" then
		conn = ssl { backend = conn, owned = true, host = parsed.host };
	end

	local body_out = http.write_req(conn, {
		method = arg.method or "GET",
		path = url.stringify { path = parsed.path, params = parsed.params },
		headers = arg.headers,
	}, arg.body ~= nil);

	if arg.body then
		--- @cast body_out std.io.stream
		body_out:pipe(arg.body);
		body_out:close();
	end

	local res = assert(http.read_res(conn), "no response");
	return res;
end

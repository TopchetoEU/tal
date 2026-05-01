local url = require "std.fmt.url";
local net = require "std.io.net";
local headers = require "std.http.headers";
local http = require "std.http";
local ssl  = require "std.io.ssl"

--- @param arg { url: string, method?: string, headers?: http_headers, body?: http_body }
return function (arg)
	local parsed = assert(url.parse(arg.url));
	if not parsed.scheme then return nil, "scheme must be specified" end
	if
		parsed.scheme ~= "http" and
		parsed.scheme ~= "https"
	then
		return nil, "only http and https supported";
	end
	if not parsed.host then return nil, "host must be specified" end
	if parsed.username then return nil, "username and password not supported" end

	local dns_res, err = net.getaddrinfo(parsed.host, "");
	if not dns_res then return nil, err or "unable to resolve host" end

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

	local conn, err;
	for i = 1, #dns_res do
		conn, err = net.connect(dns_res[i], parsed.port or default_port);
		if conn then break end
	end

	if not conn then return nil, err or "couldn't connect" end

	if parsed.scheme == "https" then
		conn = ssl { backend = conn, owned = true, host = parsed.host };
	end

	local body_out, err = http.write_req(conn, arg.method or "GET", url.stringify { path = parsed.path, params = parsed.params }, arg.headers, arg.body ~= nil);
	if not body_out then return nil, err end

	if arg.body then
		--- @cast body_out std.io.stream
		local _, err = http.write_body(body_out, arg.body);
		if not _ then return nil, err end
	end

	local res, err = http.read_res(conn);
	if not res then return nil, err end

	local body, err = http.read_body(conn, res.headers);
	if not body and err then return nil, err end

	return { code = res.code, headers = res.headers, body = body };
end

-- --- @param stream std.io.stream
-- --- @param code? integer
-- --- @param hdrs? http_headers
-- --- @param body? http_body
-- local function http_respond(stream, code, hdrs, body)
-- 	local body_out, err = http_write_res(stream, code or 200, hdrs or headers.new(), body);
-- 	if not body_out then return nil, err end

-- 	if body then
-- 		local _, err = http_write_body(body_out, body);
-- 		if not _ then return nil, err end
-- 	end
-- 	return true;
-- end

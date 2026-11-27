local url = require "std.path.url";
local net = require "std.os.net";
local headers = require "std.proto.http.headers";
local http = require "std.proto.http";
local ssl = require "std.proto.ssl";
local sig = require "std.sig";
local time = require "std.os.time";

--- @class std.proto.http.fetch_opts
--- @field url string
--- @field method? "GET" | "POST" | "PUT" | "DELETE" | string
--- @field headers? std.proto.http.headers
--- @field body? string | std.str | fun(): string?
---
--- @field no_redirect? boolean
--- @field no_ratelimit? boolean
--- @field no_ua? boolean
--- @field no_error? boolean
--- @field max_depth? integer
---
--- @field waitfn? fun(time: number)

--- @param arg std.proto.http.fetch_opts | string
local function fetch(arg)
	if type(arg) == "string" then
		arg = { url = arg };
	end

	if not arg.max_depth then arg.max_depth = 16 end
	if not arg.waitfn then arg.waitfn = time.sleep end
	if arg.max_depth and arg.max_depth <= 0 then error "too many attempts or redirect recursion too deep" end

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

	arg.headers:set("host", parsed.host);
	if not arg.no_ua and not arg.headers:get "user-agent" then
		arg.headers:set("user-agent", "tal/" .. _TAL);
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
		body_out:to_text():pipe(arg.body):close();
	end

	local res = assert(http.read_res(conn), "no response");

	if not arg.no_ratelimit and res.code == 429 then
		local retry_after = tonumber(res.headers:get "Retry-After");
		if retry_after then
			res.body:close();

			arg.waitfn(retry_after);

			arg.max_depth -= 1;
			return fetch(arg);
		end
	end

	if not arg.no_redirect and (res.code == 301 or res.code == 302) then
		local location = res.headers:get "Location";
		if location then
			res.body:close();

			arg.max_depth -= 1;
			arg.url = url.stringify(url.navigate(parsed, location));
			return fetch(arg);
		end
	end

	if not arg.no_error and (res.code // 100) >= 4 then
		if res.body then res.body:close() end
		error("http code " .. res.code);
	end

	return res;
end

return fetch;

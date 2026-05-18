local headers = require "std.http.headers";
local stream = require "std.io.stream";
local buffer = require "string.buffer";
local ffi = require "ffi";

local codes_msgs = {
	[100] = "Continue",
	[101] = "Switching Protocols",
	[102] = "Processing",
	[103] = "Early Hints",

	[200] = "OK",
	[201] = "Created",
	[202] = "Accepted",
	[203] = "Non-Authorative Information",
	[204] = "No Content",
	[205] = "Reset Content",
	[206] = "Partial Content",
	[207] = "Multi-Status",
	[208] = "Already Reported",
	[209] = "IM Used",

	[300] = "Multiple Choices",
	[301] = "Moved Permanently",
	[302] = "Found",
	[303] = "See Other",
	[304] = "Not Modified",
	[305] = "Use Proxy",
	[306] = "Switch Proxy",
	[307] = "Temporary Redirect",
	[308] = "Premanent Redirect",

	[400] = "Bad Request",
	[401] = "Unauthorized",
	[402] = "Payment Required",
	[403] = "Forbidden",
	[404] = "Not Found",
	[405] = "Method Not Allowed",
	[406] = "Not Acceptable",
	[407] = "Proxy Authentication Required",
	[408] = "Request Timeout",
	[409] = "Conflict",
	[410] = "Gone",
	[411] = "Length Required",
	[412] = "Precondition Failed",
	[413] = "Payload Too Large",
	[414] = "URI Too Long",
	[415] = "Unsupported Media Type",
	[416] = "Range Not Satisfiable",
	[417] = "Expectation Failed",
	[418] = "I'm a teapot",
	[421] = "Misdirected Request",
	[422] = "Unprocessable Content",
	[423] = "Locked",
	[424] = "Failed Dependency",
	[425] = "Too Early",
	[426] = "Upgrade Required",
	[428] = "Precondition Required",
	[429] = "Too Many Requests",
	[431] = "Request Header Fields Too Large",
	[451] = "Unavailable For Legal Reasons",

	[500] = "Internal Server Error",
	[501] = "Not Implemented",
	[502] = "Bad Gateway",
	[503] = "Service Unavailable",
	[504] = "Gateway Timeout",
	[505] = "HTTP Version Not Supported",
	[506] = "Variant Also Negotiates (",
	[507] = "Insufficient Storage",
	[508] = "Loop Detected",
	[510] = "Not Extended",
	[511] = "Network Authentication Required",
};

--- @class std.http.req
--- @field method string
--- @field path string
--- @field headers std.http.headers
--- @field body? std.io.stream

--- @class std.http.res
--- @field code integer
--- @field headers std.http.headers
--- @field body? std.io.stream

local http = {};

--- @param conn std.io.stream
function http.read_headers(conn)
	local res = headers.new();

	while true do
		local line = conn:read "L";
		if not line then return nil end

		if line == "\r\n" then return res end

		local key, val = line:match "^(.-): ?(.*)\r\n$";
		if not key then error "unexpected header format" end
		key = key:lower();

		-- if val:find ", " then
		-- 	local i = 1;
		-- 	repeat
		-- 		local l = val:find(", ", i);
		-- 		res:add(key, val:sub(i, l and (l - 1) or -1));
		-- 		if l then i = l + 1; end
		-- 	until not l;
		-- else
			res:add(key, val);
		-- end
	end
end
--- @param conn std.io.stream
--- @param hdr std.http.headers
--- @return std.io.stream?
function http.read_body(conn, hdr)
	local len = tonumber((hdr:get "content-length"));
	local chunked = false;

	local encoding = { hdr:get "transfer-encoding" };
	for i = 1, #encoding do
		for _, el in encoding[i]:split ", " do
			if el == "chunked" then
				chunked = true;
			else
				error("unknown transfer encoding '" .. el .. "'");
			end
		end
	end

	if chunked then
		local self = { str = conn, done = false, buff = buffer.new() };

		function self:read(ptr, n)
			if not self.str then ierror "closed" end
			if self.done then return nil end

			if #self.buff == 0 then
				local line = self.str:read "L";
				if not line then ierror "pipe broken" end

				local slen = line:match "^([%da-zA-Z]+)\r?\n$";
				if not slen then ierror "malformed chunked encoding" end
				local len = tonumber(slen, 16);

				if len == 0 then
					self.done = true;
					return nil;
				end

				local line = iassert(self.str:read(len), "broken pipe");
				self.buff:put(line);

				local term = iassert(self.str:read "L", "broken pipe");
				if not term:find "^\r?\n$" then ierror "malformed chunked encoding" end
			end

			if n > #self.buff then
				n = #self.buff;
			end
			ffi.copy(ptr, self.buff:ref(), n);
			self.buff:skip(n);

			return n;
		end
		function self:write()
			ierror "readonly";
		end
		function self:close()
			if self.str then
				self.str:close();
				self.str = nil;
			end
		end

		return stream.new(self, true);
	elseif len then
		local self = {
			str = conn,
			n = len,
		};

		function self:read(ptr, n)
			if not self.str then ierror "closed" end
			if self.n == 0 then return 0 end

			n = n or 8192;
			if n > self.n then
				n = self.n;
			end

			local n = self.str:ptrread(false, ptr, n);
			self.n = self.n - n;
			return n;
		end
		function self:write(n, ptr)
			ierror "readonly";
		end
		function self:close()
			if self.str then
				self.str:close();
				self.str = nil;
			end
		end

		return stream.new(self, true);
	else
		return nil;
	end
end
--- @param conn std.io.stream
--- @return std.http.req? head
function http.read_req(conn)
	local line = conn:read "L";
	if not line then return nil end

	local type, path, version = line:match "^(%S-) (%S-) HTTP/(%S-)\r?\n$";
	if not type then error "bad HTTP request" end
	if version ~= "1.1" and version ~= "1.0" then error("bad HTTP version " .. version) end

	local hdr = assert(http.read_headers(conn), "bad HTTP headers");
	local body = http.read_body(conn, hdr);

	return { method = type, path = path, headers = hdr, body = body };
end
--- @param conn std.io.stream
--- @return std.http.res? code
function http.read_res(conn)
	local line = conn:read "L";
	if not line then return nil end

	local version, code = line:match "^HTTP/(%S-) (%S-) (.-)\r\n$";
	if not version then return error "bad HTTP response" end
	if version ~= "1.1" and version ~= "1.0" then error("bad HTTP version " .. version) end

	local hdr = assert(http.read_headers(conn), "bad HTTP headers");
	local body = http.read_body(conn, hdr);

	return {
		code = tonumber(code),
		headers = hdr,
		body = body,
	};
end

--- @param conn std.io.stream
--- @param hdr std.http.headers
function http.write_headers(conn, hdr)
	for key in hdr:keys() do
		for _, val in ipairs { hdr:get(key) } do
			conn:write(("%s: %s\r\n"):format(key, val));
		end
	end

	conn:write "\r\n";
end
--- @param conn std.io.stream
--- @param hdr std.http.headers
--- @param body? false
--- @return std.io.stream?
--- @overload fun(conn: std.io.stream, hdr: std.http.headers, body: true): std.io.stream
function http.write_body(conn, hdr, body)
	if not body then return nil end

	local len = hdr:get "content-length";
	if len and tonumber(len) then return conn end

	hdr:set("transfer-encoding", "chunked");

	return stream.new({
		str = conn,
		read = function ()
			ierror "writeonly";
		end,
		write = function (self, ptr, n)
			if self.str == nil then ierror "closed" end
			if n > 0 then
				self.str:write(("%x\r\n"):format(n));
				self.str:ptrwrite(true, ptr, n);
				self.str:write("\r\n");
				return n;
			else
				return 0;
			end
		end,
		close = function (self)
			if self.str then
				local str = self.str;
				self.str = nil;

				-- The finalizer of the underlying stream might've been called before us, so we silence the error
				pcall(str.write, str, "0\r\n\r\n");
				str:close();
			end
		end
	}, true);
end
--- @param conn std.io.stream
--- @param req std.http.req
--- @param body? boolean
--- @return std.io.stream?
--- @overload fun(conn: std.io.stream, req: std.http.req, body: true): std.io.stream
function http.write_req(conn, req, body)
	req.body = http.write_body(conn, req.headers, body);

	conn:write(("%s %s HTTP/1.1\r\n"):format(req.method, req.path));
	http.write_headers(conn, req.headers);

	return req.body;
end
--- @param conn std.io.stream
--- @param res std.http.res
--- @param body? boolean
--- @return std.io.stream?
--- @overload fun(conn: std.io.stream, res: std.http.res, body: true): std.io.stream
function http.write_res(conn, res, body)
	res.body = http.write_body(conn, res.headers, body);

	conn:write(("HTTP/1.1 %d %s\r\n"):format(res.code, codes_msgs[res.code] or "Unknown"));
	http.write_headers(conn, res.headers);

	return res.body;
end

return http;

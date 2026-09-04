local headers = require "std.http.headers";
local buffer = require "string.buffer";
local ffi = require "ffi";
local str = require "std.str"

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
	[418] = "Fuck you", -- sent to naughty clients to flip 'em off
	[419] = "Page expired", -- not standard
	[420] = "Enhance Your Calm", -- you know how...
	[421] = "Misdirected Request",
	[422] = "Unprocessable Content",
	[423] = "Locked",
	[424] = "Failed Dependency",
	[425] = "Too Early",
	[426] = "Upgrade Required",
	[428] = "Precondition Required",
	[429] = "Too Many Requests",
	[430] = "Request Header Fields Too Large", -- somebody got impatient...
	[431] = "Request Header Fields Too Large",
	[451] = "Unavailable For Legal Reasons", -- literally 1984

	[500] = "Internal Server Error",
	[501] = "Not Implemented",
	[502] = "Bad Gateway",
	[503] = "Service Unavailable",
	[504] = "Gateway Timeout",
	[505] = "HTTP Version Not Supported",
	[506] = "Variant Also Negotiates",
	[507] = "Insufficient Storage",
	[508] = "Loop Detected",
	[510] = "Not Extended",
	[511] = "Network Authentication Required",
};

--- @class std.http.req
--- @field method string
--- @field path string
--- @field headers std.http.headers
--- @field body? std.bstr

--- @class std.http.res
--- @field code integer
--- @field headers std.http.headers
--- @field body? std.bstr

local http = {};


-- TODO: export this to a separate module
--- @param str std.bstr
--- @param buff? string.buffer
local function _readline(str, buff)
	buff = buff or buffer.new();

	repeat
		local ptr, ptr_n = buff:reserve(str.chunksize);
		local n, has_c = str:readline(ptr, ptr_n, 0x0A);
		buff:commit(n);
	until n == 0 or has_c;

	if #buff == 0 then return nil end

	local res = buff:tostring();
	buff:reset();
	return res;
end

--- @param conn std.bstr
function http.read_headers(conn)
	local res = headers.new();

	while true do
		local line = _readline(conn);
		if not line then return nil end

		if line == "\r\n" or line == "\n" then return res end

		local key, val = line:match "^(.-): ?(.-)\r?\n$";
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
--- @param conn std.bstr
--- @param hdr std.http.headers
--- @return std.bstr?
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
		local self = setmetatable({ str = conn, done = false, _rstack = {} }, str.chunked);

		function self:readchunk()
			if not self.str then ierror "closed" end
			if self.done then return 0 end

			local buff = buffer.new();

			local line = _readline(self.str, buff);
			if not line then ierror "pipe broken" end

			local slen = line:match "^([%da-zA-Z]+)\r?\n$";
			if not slen then ierror "malformed chunked encoding" end

			local len = tonumber(slen, 16);
			if len == 0 then
				self.done = true;
				return 0;
			end

			local ptr = ffi.new("char[?]", len);
			self.str:fullread(ptr, len);

			local line = _readline(self.str, buff);
			if not line then ierror "pipe broken" end
			if not line:find "^\r?\n$" then ierror "malformed chunked encoding" end

			return len, ptr;
		end
		function self:close()
			if self.str then
				self.str:close();
				self.str = nil;
			end
		end

		return self:to_buff();
	elseif len then
		local self = setmetatable({ str = conn, done = false, n = len }, str);

		function self:read(ptr, n)
			if not self.str then ierror "closed" end
			if n > self.n then n = self.n end
			if self.n == 0 then return 0 end

			local n = self.str:read(ptr, n);
			self.n = self.n - n;
			return n;
		end
		function self:close()
			if self.str then
				self.str:close();
				self.str = nil;
			end
		end

		return self:to_buff();
	else
		return nil;
	end
end
--- @param conn std.bstr
--- @return std.http.req? head
function http.read_req(conn)
	local line = _readline(conn);
	if not line then return nil end

	local type, path, version = line:match "^(%S-) (%S-) HTTP/(%S-)\r?\n$";
	if not type then error "bad HTTP request" end
	if version ~= "1.1" and version ~= "1.0" then error("bad HTTP version " .. version) end

	local hdr = assert(http.read_headers(conn), "bad HTTP headers");
	local body = http.read_body(conn, hdr);

	return { method = type, path = path, headers = hdr, body = body };
end
--- @param conn std.bstr
--- @return std.http.res? code
function http.read_res(conn)
	local line = _readline(conn);
	if not line then return nil end

	local version, code = line:match "^HTTP/(%S-) (%S-) (.-)\r?\n$";
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

--- @param conn std.bstr
--- @param hdr std.http.headers
function http.write_headers(conn, hdr)
	for key in hdr:keys() do
		for _, val in ipairs { hdr:get(key) } do
			conn:write(ffi.toptr(("%s: %s\r\n"):format(key, val)));
		end
	end

	conn:write(ffi.toptr "\r\n");
end
--- @param conn std.bstr
--- @param hdr std.http.headers
--- @param body? false
--- @return std.bstr?
--- @overload fun(conn: std.bstr, hdr: std.http.headers, body: true): std.bstr
function http.write_body(conn, hdr, body)
	if not body then return nil end

	local len = hdr:get "content-length";
	if len and tonumber(len) then
		local self = setmetatable({ str = conn, n = assert(tonumber(len)) }, str);

		function self:write(ptr, n)
			if not self.str then ierror "closed" end
			if n > self.n then n = self.n end
			if n == 0 then return 0 end

			local n = self.str:write(ptr, n);
			self.n = self.n - n;
			return n;
		end
		function self:flush()
			if not self.str then ierror "closed" end
			self.str:flush();
			return self;
		end
		function self:close()
			self.str = nil;
			return true;
		end

		return self:to_buff():setwbuff(nil, str.chunksize);
	end

	hdr:set("transfer-encoding", "chunked");

	local self = setmetatable({ str = conn }, str);

	function self:write(ptr, n)
		if self.str == nil then ierror "closed" end
		if n == 0 then return 0 end

		self.str:write(ffi.toptr(("%x\r\n"):format(n)));
		self.str:fullwrite(ptr, n);
		self.str:write(ffi.toptr "\r\n");
		return n;
	end
	function self:flush()
		self.str:flush();
		return self;
	end
	function self:close()
		if not self.str then return true end
		local str = self.str;
		self.str = nil;

		-- The finalizer of the underlying stream might've been called before us, so we silence the error
		pcall(str.write, str, ffi.toptr "0\r\n\r\n");
		return true;
	end

	return self:to_buff():setwbuff(nil, str.chunksize);
end
--- @param conn std.bstr
--- @param req std.http.req
--- @param body? boolean
--- @return std.bstr?
--- @overload fun(conn: std.bstr, req: std.http.req, body: true): std.bstr
function http.write_req(conn, req, body)
	req.body = http.write_body(conn, req.headers, body);

	conn:write(ffi.toptr(("%s %s HTTP/1.1\r\n"):format(req.method, req.path)));
	http.write_headers(conn, req.headers);

	return req.body;
end
--- @param conn std.bstr
--- @param res std.http.res
--- @param body? boolean
--- @return std.bstr?
--- @overload fun(conn: std.bstr, res: std.http.res, body: true): std.bstr
function http.write_res(conn, res, body)
	res.body = http.write_body(conn, res.headers, body);

	conn:write(ffi.toptr(("HTTP/1.1 %d %s\r\n"):format(res.code, codes_msgs[res.code] or "Unknown")));
	http.write_headers(conn, res.headers);

	return res.body;
end

return http;

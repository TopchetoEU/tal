local headers = require "std.http.headers";
local stream = require "std.io.stream";
local buffer = require "string.buffer";
local ffi    = require "ffi"
local mutex  = require "std.sync.mutex"

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

--- @alias http_body (fun(): string?, string?) | std.io.stream | string | nil

local parse = {};
--- @param str std.io.stream
function parse.read_headers(str)
	local res = headers.new();

	while true do
		local line, err = str:read "L";
		if not line then return nil, err or "EOF" end

		if line == "\r\n" then return res end

		local key, val = line:match "^(.-): ?(.*)\r\n$";
		if not key then return nil, "unexpected header format" end
		key = key:lower();

		if val:find ", " then
			local i = 1;
			repeat
				local l = val:find(", ", i);
				res:add(key, val:sub(i, l and (l - 1) or -1));
				if l then i = l + 1; end
			until not l;
		else
			res:add(key, val);
		end
	end
end
--- @param str std.io.stream
--- @param headers http_headers
--- @return std.io.stream?, string?
function parse.read_body(str, headers)
	local len = tonumber((headers:get "content-length"));
	local chunked = false;

	local encoding = { headers:get "transfer-encoding" };
	for i = 1, #encoding do
		if encoding[i] == "chunked" then
			chunked = true;
		else
			return nil, "unknown transfer encoding '" .. encoding[i] .. "'";
		end
	end

	if chunked then
		local self = { str = str, done = false, buff = buffer.new() };

		function self:read(ptr, n)
			if not self.str then return "closed" end
			if self.done then return nil end

			if #self.buff == 0 then
				-- TODO: make async
				local line, err = self.str:read "L";
				if not line then return err or "broken pipe" end

				local slen = line:match "^([%da-zA-Z]+)\r\n$";
				if not slen then return "malformed chunked encoding" end
				local len = tonumber(slen, 16);

				if len == 0 then
					self.done = true;
					return nil;
				end

				local line, err = self.str:read(len);
				if not line then return err or "broken pipe" end

				self.buff:put(line);

				local term, err = self.str:read(2);
				if not term then return err or "broken pipe" end
				if term ~= "\r\n" then return "malformed chunked encoding" end
			end

			if n > #self.buff then
				n = #self.buff;
			end
			ffi.copy(ptr, self.buff:ref(), n);
			self.buff:skip(n);

			return n;
		end
		function self:write()
			return nil, "readonly";
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
			str = str,
			n = len,
		};

		function self:read(ptr, n)
			if not self.str then return nil, "closed" end
			if self.n == 0 then return nil end

			n = n or 8192;
			if n > self.n then
				n = self.n;
			end

			local n, err = self.str:ptrread(false, ptr, n);
			if err then return nil, err end
			if n then self.n = self.n - n end
			return n;
		end
		function self:write(n, ptr)
			return nil, "readonly";
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

--- @return { method: string, path: string, headers: http_headers }? head
--- @return string? err
function parse.read_req(stream)
	local line, err = stream:read "L";
	if not line then
		if err then return nil, err end
		return nil;
	end

	local type, path, version = line:match "^(%S-) (%S-) HTTP/(%S-)\r\n$";
	if not type then return nil, "unexpected format" end
	if version ~= "1.1" and version ~= "1.0" then return nil, "only HTTP 1.1/1.0 supported, got " .. version end

	local headers, err = parse.read_headers(stream);
	if not headers then return nil, err end

	return { method = type, path = path, headers = headers };
end
--- @return { code: integer, headers: http_headers }? code
--- @return string? err
function parse.read_res(stream)
	local line, err = stream:read "L";
	if not line then
		if err then return nil, err end
		return nil;
	end

	local version, code = line:match "^HTTP/(%S-) (%S-) (.-)\r\n$";
	if not version then return nil, "unexpected format" end
	if version ~= "1.1" and version ~= "1.0" then return nil, "only HTTP 1.1/1.0 supported, got " .. version end

	local headers, err = parse.read_headers(stream);
	if not headers then return nil, err end

	return { code = tonumber(code), headers = headers };
end

--- @param stream std.io.stream
--- @param key? string
--- @param ... string
function parse.write_header(stream, key, ...)
	if not key then
		return stream:write "\r\n";
	else
		for i = 1, select("#", ...) do
			local res, err = stream:write(("%s: %s\r\n"):format(key, (select(i, ...))));
			if not res then return nil, err end
		end

		return true;
	end
end
--- @param stream std.io.stream
--- @param headers http_headers
function parse.write_headers(stream, headers)
	for key in headers:keys() do
		local _, err = parse.write_header(stream, key, headers:get(key));
		if not _ then return nil, err end
	end

	return parse.write_header(stream);
end

--- @param str std.io.stream
local function http_setup_body(str, body)
	if not body then return true end

	local _, err = str:write("transfer-encoding: chunked\r\n");
	if not _ then return nil, err end

	return stream.new({
		str = str,
		read = function ()
			return nil, "writeonly";
		end,
		write = function (self, ptr, n)
			if self.str == nil then return nil, "closed" end
			if n > 0 then
				local _, err = self.str:write(("%x\r\n"):format(n));
				if err then return nil, err end

				local _, err = self.str:ptrwrite(true, ptr, n);
				if err then return nil, err end

				local _, err = self.str:write("\r\n");
				if err then return nil, err end

				return n;
			else
				return 0;
			end
		end,
		close = function (self)
			if self.str then
				self.str:write("0\r\n\r\n");
			end
			self.str = nil;
		end
	});
end

--- @param stream std.io.stream
--- @param method string
--- @param path string
--- @param headers http_headers
--- @param body? false
--- @return true?, string?
--- @overload fun(stream: std.io.stream, method: string, path: string, headers: http_headers, body: true): std.io.stream?, string?
function parse.write_req(stream, method, path, headers, body)
	local _, err = stream:write(("%s %s HTTP/1.1\r\n"):format(method, path));
	if not _ then return nil, err end

	local body_str, err = http_setup_body(stream, body);
	if not body_str then return nil, err end

	local _, err = parse.write_headers(stream, headers);
	if not _ then return nil, err end

	return body_str;
end
--- @param stream std.io.stream
--- @param code integer
--- @param headers http_headers
--- @param body? false
--- @return true?, string?
--- @overload fun(stream: std.io.stream, code: integer, headers: http_headers, body: true): std.io.stream?, string?
function parse.write_res(stream, code, headers, body)
	local _, err = stream:write(("HTTP/1.1 %d %s\r\n"):format(code, codes_msgs[code] or "Unknown"));
	if not _ then return nil, err end

	local body_str, err = http_setup_body(stream, body);
	if not body_str then return nil, err end

	local _, err = parse.write_headers(stream, headers);
	if not _ then return nil, err end

	return body_str;
end

--- @param stream std.io.stream
function parse.write_body(stream, body)
	if type(body) == "function" then
		while true do
			local data, err = body();
			if err then return nil, err end
			if not data then break end

			local _, err = stream:write(data);
			if err then return nil, err end
		end
	elseif type(body) == "string" then
		stream:write(body);
	elseif body then
		local buff = buffer.new();

		--- @cast body std.io.stream
		while true do
			local n, err = body:ptrread(false, buff:reserve(4096));
			if err then return nil, err end
			if n == 0 or not n then break end

			buff:commit(n);

			local n, err = stream:ptrwrite(true, buff:ref());
			if not n then return nil, err end
			buff:skip(n);
		end
	end

	stream:close();
	return true;
end

return parse;

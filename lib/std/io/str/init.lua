local ffi = require "nat.ffi"
local libc= require "nat.libc";

--- @class std.str
local str = {};
str.__index = str;
str.__metatable = "std.io.str";

--- The default chunk size for read operations. Instances/subclasses may modify this to a finer-tuned value
str.chunksize = 8192;

--- Parses a list of chmod directives into an integer mode
--- Allowed arguments are:
--- - integer - overrides the current accumulated mode
--- - octal string - same as integer
--- - +octal - adds the permission to the accumulated permissions
--- - -octal - removes the permission from the accumulated perms
--- Note that you must provide the initial mode from a stat, if you wish to add/subtact from the file's initial mode
--- @param ... string | integer
function str.parsechmod(...)
	local res = 0;

	for i = 1, select("#", ...) do
		local arg = select(i, ...);
		if type(arg) == "number" then
			res = arg;
		elseif type(arg) == "string" then
			local function op(a, b) return b end
			if arg:find "^%+" then
				arg = arg:sub(2);
				function op(a, b) return a | b end
			elseif arg:find "^^-" then
				arg = arg:sub(2);
				function op(a, b) return a & ~b end
			end

			res = op(res, assert(tonumber(arg, 8), "invalid mode number"));
		end
	end

	return res;
end

--- @param ptr ffi.cdata*
--- @param n integer
--- @return integer? n If nil, indicates an EOF
function str:read(ptr, n) ierror "not supported" end
--- @param ptr ffi.cdata*
--- @param n integer
--- @return integer n
function str:write(ptr, n) ierror "not supported" end

--- @return true
function str:flush() return true end
--- @return std.io.stat
function str:stat() ierror "not supported" end

--- Performs consequtive reads until either an EOF is reached or the provided buffer is filled
function str:fullread(ptr, n)
	local res = 0;

	while true do
		local curr_n = self:read(ptr, n);
		if curr_n == 0 then break end

		res = res + curr_n;
		ptr = ptr + curr_n;
		n = n - curr_n;
		if n <= 0 then break end
	end

	return res;
end
--- Performs consequtive writes until the whole buffer is written
--- Usually, this isn't necessary
function str:fullwrite(ptr, n)
	local res = 0;

	while true do
		local curr_n = self:write(ptr, n);
		if curr_n == 0 then break end

		res = res + curr_n;
		ptr = ptr + curr_n;
		n = n - curr_n;
		if n <= 0 then break end
	end

	return res;
end

function str:to_buff() return str.buff.new(self) end
function str:to_unbuff() return self end

--- @class std.file: std.str
str.file = setmetatable({}, str);
str.file.__index = str.file;
str.file.__metatable = "std.file";

--- @param whence "set" | "cur" | "end"
--- @param pos integer
--- @return integer
function str.file:seek(whence, pos) ierror "not supported" end

--- @param ... string | integer
function str.file:chmod(...) ierror "not supported" end
--- @param uid integer
--- @param gid integer
function str.file:chown(uid, gid) ierror "not supported" end

--- @param no_seek boolean = false
function str.file:to_buff(no_seek) return str.file.buff.new(self, no_seek) end
function str.file:to_unbuff() return self end

--- @return true
function str:close() return true end

--- @class std.buffstr.range
--- @field data ffi.cdata*
--- @field f integer
--- @field l integer

--- @class std.bstr: std.str
--- @field _backend std.str
--- @field _rstack std.buffstr.range[]
--- @field _wbuff std.buffstr.range
str.buff = setmetatable({}, str);
str.buff.__index = str.buff;
str.buff.__metatable = "std.bstr";

--- @param ptr ffi.cdata*
--- @param n integer
function str.buff:read(ptr, n)
	local res_n = 0;

	while #self._rstack > 0 do
		if n <= 0 then break end

		local part = table.remove(self._rstack) --[[@as std.buffstr.range]];
		local part_n = part.l - part.f;

		if part_n > n then
			ffi.copy(ptr, part.data + part.f, n);
			res_n = res_n + n;

			part.f = part.f + n;
			table.insert(self._rstack, part);

			return res_n;
		else
			ffi.copy(ptr, part.data, part_n);
			res_n = res_n + part_n;
			ptr = ptr + part_n;
			n = n - part_n;
		end
	end

	if res_n ~= 0 then return res_n end

	return res_n + self._backend:read(ptr, n);
end
--- Reverts `n` amount of bytes from the last read
--- `ptr` is a hint for the data, if the underlying stream can't seek. It must mirror the last `n` read bytes
--- @param ptr ffi.cdata*
--- @param n integer
function str.buff:unread(ptr, n)
	local new_ptr = ffi.new("char[?]", n);
	ffi.copy(new_ptr, ptr, n);
	ptr = new_ptr;

	table.insert(self._rstack, { data = ptr, f = 0, l = n });
end
--- Reads until `char` is encountered, the buffer is filled or EOF is reached
--- If read has stopped at `char`, it is included in the output. `ptr` will contain at most one `char`
---@param ptr ffi.cdata*
---@param n integer
---@param char integer
function str.buff:readline(ptr, n, char)
	n = self:read(ptr, n);

	local c_ptr = libc.strnchr(ptr, char, n);
	if c_ptr then
		local c_i = c_ptr - ptr;
		self:unread(c_ptr + 1, n - c_i - 1);
		return c_i + 1;
	end

	return n;
end

function str.buff:flush()
	if self._wbuff.f > 0 then
		self._backend:fullwrite(self._wbuff.data, self._wbuff.f);
		self._wbuff.f = 0;
	end

	return self._backend:flush();
end

function str.buff:write(ptr, n)
	-- We will either be overfilling the buffer or raw-writting
	-- Either way, we need to flush
	if self._wbuff.f + n > self._wbuff.l then
		self:flush();
	end

	-- We can't fit this in the buffer, so we will raw-write it
	if n > self._wbuff.l then
		return self._backend:write(ptr, n);
	end

	ffi.copy(self._wbuff.data + self._wbuff.f, ptr, n);
	self._wbuff.f = self._wbuff.f + n;

	return n;
end

function str.buff:to_buff() return self end
function str.buff:to_unbuff() return self._backend end

--- @param backend std.str
function str.buff.new(backend)
	return setmetatable({
		_backend = backend:to_unbuff(),
		_rstack = {},
		_wbuff = { data = ffi.new("char[?]", str.chunksize), f = 0, l = str.chunksize },
	}, str.buff);
end

--- @class std.bfile: std.file, std.bstr
--- @field _noseek boolean
--- @field _bstr std.bstr
--- @field _backend std.file
--- @field _rstack std.buffstr.range[]
--- @field _wbuff std.buffstr.range
str.file.buff = setmetatable({}, str.buff);
str.file.buff.__index = str.file.buff;
str.file.buff.__metatable = "std.bfile";

--- @param ptr ffi.cdata*
--- @param n integer
function str.file.buff:read(ptr, n)
	if self._noseek then
		return self._bstr:read(ptr, n);
	else
		return self._backend:read(ptr, n);
	end
end
function str.file.buff:unread(ptr, n)
	if self._noseek then
		return self._bstr:unread(ptr, n);
	else
		self._backend:seek("cur", -n);
	end
end
function str.file.buff:write(ptr, n)
	return self._bstr:write(ptr, n);
end
function str.file.buff:flush()
	if self._noseek then
		return self._bstr:flush();
	else
		return self._backend:flush();
	end
end

function str.file.buff:seek(whence, pos)
	return self._backend:seek(whence, pos);
end
function str.file.buff:stat()
	return self._backend:stat();
end
function str.file.buff:chmod(...)
	return self._backend:chmod(...);
end
function str.file.buff:chown(uid, gid)
	return self._backend:chown(uid, gid);
end

function str.file.buff:to_buff() return self end
function str.file.buff:to_unbuff() return self._backend end

--- @param backend std.str
--- @param noseek boolean
function str.file.buff.new(backend, noseek)
	return setmetatable({
		_backend = backend:to_unbuff(),
		_bstr = str.buff.new(backend),
		_noseek = noseek,
	}, str.file.buff);
end

return str;

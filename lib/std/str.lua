local ffi = require "nat.ffi"
local libc = require "nat.libc";
local buffer = require "string.buffer";
local sig = require "std.sig";

--- @class std.io.stat
--- @field type "file" | "dir" | "link" | "sock" | "fifo" | "char" | "blk"
--- @field mode integer
--- @field gid integer
--- @field uid integer
--- @field atime number
--- @field mtime number
--- @field ctime number
--- @field size integer
--- @field blksize integer
--- @field inode integer
--- @field links integer

--- @class std.str.buffrange
--- @field data ffi.cdata*
--- @field f integer
--- @field l integer

--- @class std.str.backend
--- @field _read? fun(self, ptr: ffi.cdata*, n: integer): integer
--- @field _readchunk? fun(self): integer, ffi.cdata*
--- @field _readtext? fun(self): string?
---
--- @field _write? fun(self, ptr: ffi.cdata*, n: integer): integer
--- @field _writetext? fun(self, data: string)
---
--- @field _close? fun(self)
---
--- @field _flush? fun(self)
--- @field _stat? fun(self): std.io.stat
--- @field _seek? fun(self, whence: seekwhence, pos: integer): integer
--- @field _chmod? fun(self, mode: integer)
--- @field _chown? fun(self, uid: integer, gid: integer)

--- @class std.str: std.str.backend
--- @field _closed boolean
--- @field _rstack std.str.buffrange[]
--- @field _wbuff? std.str.buffrange
--- @field _wbuffc? integer
local str = {};
str.__index = str;
str.__metatable = "std.str";

str.chunksize = 8192;

--- @param ptr ffi.cdata*
--- @param n integer
function str:read(ptr, n)
	local res_n = 0;

	while #self._rstack > 0 do
		if n <= 0 then break end

		local part = table.remove(self._rstack) --[[@as std.str.buffrange]];
		local part_n = part.l - part.f;

		if part_n > n then
			ffi.copy(ptr, part.data + part.f, n);
			res_n = res_n + n;

			part.f = part.f + n;
			table.insert(self._rstack, part);

			return res_n;
		else
			ffi.copy(ptr, part.data + part.f, part_n);
			res_n = res_n + part_n;
			ptr = ptr + part_n;
			n = n - part_n;
		end
	end

	if res_n ~= 0 then return res_n end

	if self._read then
		return self:_read(ptr, n);
	elseif self._readchunk then
		local chunk_n, chunk_ptr = self:_readchunk();
		if chunk_n > n then
			table.insert(self._rstack, { f = n, l = chunk_n, data = chunk_ptr });
			ffi.copy(ptr, chunk_ptr, n);
			return n;
		else
			ffi.copy(ptr, chunk_ptr, chunk_n);
			return chunk_n;
		end
	elseif self._readtext then
		local chunk = self:_readtext();
		if not chunk then return 0 end

		if #chunk > n then
			table.insert(self._rstack, { f = 0, l = #chunk - n, data = ffi.new("char[?]", #chunk - n, chunk:sub(n)) });
			ffi.copy(ptr, chunk, n);
			return n;
		else
			ffi.copy(ptr, chunk, #chunk);
			return #chunk;
		end
	else
		ierror "not supported";
	end
end
--- Reverts `n` amount of bytes from the last read
--- `ptr`, if specified provides the unread data, if seeking is not available
--- @param ptr? ffi.cdata*
--- @param n integer
function str:unread(ptr, n)
	if self._seek then
		self:_seek("cur", -n);
		return self;
	end

	if not ptr then ierror "seeking not supported" end

	local new_ptr = ffi.new("char[?]", n);
	ffi.copy(new_ptr, ptr, n);
	ptr = new_ptr;

	table.insert(self._rstack, { data = ptr, f = 0, l = n });
	return self;
end
function str:write(ptr, n)
	if not self._write then ierror "not supported" end

	if not self._wbuff then return self:_write(ptr, n) end

	-- We will either be overfilling the buffer or raw-writting
	-- Either way, we need to flush
	if self._wbuff.f + n > self._wbuff.l then self:flush() end

	-- We can't fit this in the buffer, so we will raw-write it
	-- TODO: handle flush chars better
	if n > self._wbuff.l then return self:_write(ptr, n) end

	local c_i = self._wbuff_char and libc.strnrchr(ptr, self._wbuff_char, n);

	if c_i then
		c_i = c_i + 1;
		ffi.copy(self._wbuff.data + self._wbuff.f, ptr, c_i);
		self._wbuff.f = self._wbuff.f + c_i;
		self:flush();

		ffi.copy(self._wbuff.data + self._wbuff.f, ptr + c_i, n - c_i);
		self._wbuff.f = self._wbuff.f + n - c_i;

		return n;
	else
		ffi.copy(self._wbuff.data + self._wbuff.f, ptr, n);
		self._wbuff.f = self._wbuff.f + n;

		return n;
	end
end
function str:flush()
	if self._wbuff and self._wbuff.f > 0 then
		if not self._write then ierror "not supported" end
		self:_write(self._wbuff.data, self._wbuff.f);
		self._wbuff.f = 0;
	end

	if self._flush then self:_flush() end
	return self;
end

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
--- Reads until `char` is encountered, the buffer is filled or EOF is reached
--- If read has stopped at `char`, it is included in the output. `ptr` will contain at most one `char`
---@param ptr ffi.cdata*
---@param n integer
---@param char integer
function str:readline(ptr, n, char)
	n = self:read(ptr, n);

	local c_i = libc.strnchr(ptr, char, n);
	if c_i then
		self:unread(ptr + c_i + 1, n - c_i - 1);
		return c_i + 1, true;
	end

	return n, false;
end
--- Writes the given stream, string or string generator to the stream
--- @param src std.str
function str:pipe(src)
	local buff = ffi.new("char[?]", str.chunksize);

	while true do
		local read_n = src:read(buff, str.chunksize);
		if read_n == 0 then break end
		self:fullwrite(buff, read_n);
	end

	return self;
end
--- @param buff? ffi.cdata* The buffer to be used. If nil, allocated dynamically
--- @param n? integer The size of the buffer. If nil, write side remains unbuffered
--- @param char? integer The flush char. If nil, no char will flush the write buffer
function str:setwbuff(buff, n, char)
	if n then
		if not buff then buff = ffi.new("char[?]", n) end
		self._wbuff = { data = buff, f = 0, l = n };
	else
		self._wbuff = nil;
	end

	self._wbuff_char = char;

	return self;
end

--- @return std.io.stat
function str:stat()
	if not self._stat then ierror "not supported" end
	return self:_stat();
end
--- @param ... string | integer
function str:chmod(...)
	if not self._chmod then ierror "not supported" end

	local mode = 0;

	for i = 1, select("#", ...) do
		local arg = select(i, ...);
		if type(arg) == "number" then
			mode = arg;
		elseif type(arg) == "string" then
			local function op(a, b) return b end
			if arg:find "^%+" then
				arg = arg:sub(2);
				function op(a, b) return a | b end
			elseif arg:find "^^-" then
				arg = arg:sub(2);
				function op(a, b) return a & ~b end
			end

			mode = op(mode, assert(tonumber(arg, 8), "invalid mode number"));
		end
	end

	self:_chmod(mode);
	return self;
end
--- @param uid integer
--- @param gid integer
function str:chown(uid, gid)
	if not self._stat then ierror "not supported" end
	self:_chown(uid, gid);
	return self
end

function str:close()
	if not self._closed then
		self:flush();
		if self._close then self:_close() end
	end

	self._closed = true;
	return true;
end

function str:to_text() return str.text.from_stream(self) end

--- @class std.textstr
str.text = {};
--- @class std.textstr.compat
local textstr_compat;
--- @class std.str.compat
local str_compat;
do
	str.text.__index = str.text;
	str.text.__metatable = "std.textstr";

	--- @param fmt std.io.readmode
	--- @return string?
	function str.text:read(fmt) ierror "not supported" end
	--- @param ... any
	--- @return integer
	function str.text:write(...) ierror "not supported" end
	--- @param whence? seekwhence
	--- @param pos? integer
	--- @return integer
	function str.text:seek(whence, pos) ierror "not supported" end
	--- @param mode vbuf
	--- @param size? integer
	function str.text:setvbuff(mode, size) ierror "not supported" end
	--- @return std.io.stat
	function str.text:stat() ierror "not supported" end
	--- @return std.textstr
	function str.text:flush() return self end
	function str.text:close() return true end

	--- @param dst std.textstr
	--- @param close? boolean = false
	--- @param close_dst? boolean = close
	function str.text:pipe(dst, close, close_dst)
		if close_dst == nil then close_dst = close end

		for line in self:lines(4096) do
			dst:write(line);
		end

		if close then self:close() end
		if close_dst then dst:close() end

		return true;
	end

	--- @param fmt std.io.readmode
	--- @param close? boolean = false
	--- @return fun(): string?
	function str.text:lines(fmt, close)
		if close then
			return function ()
				local res = self:read(fmt);
				if not res then self:close() end
				return res;
			end
		else
			return function ()
				return self:read(fmt);
			end
		end
	end

	--- @class std.textstr.compat: std.str
	--- @field _backend std.textstr
	textstr_compat = setmetatable({}, str);
	textstr_compat.__index = textstr_compat;
	textstr_compat.__metatable = "std.textstr.compat";

	function textstr_compat:read(ptr, n)
		local res = self._backend:read(n);
		if not res then return 0 end

		ffi.copy(ptr, res);
		return #res;
	end
	function textstr_compat:write(ptr, n)
		return self._backend:write(ffi.string(ptr, n));
	end
	function textstr_compat:stat()
		return self._backend:stat();
	end
	function textstr_compat:flush()
		return self._backend:flush();
	end
	function textstr_compat:close()
		return self._backend:close();
	end

	--- @class std.str.compat: std.textstr
	--- @field _backend std.str
	str_compat = setmetatable({}, str.text);
	str_compat.__index = str_compat;
	str_compat.__metatable = "std.textstr.compat";

	function str_compat:read(mode)
		if mode == "l" or mode == "L" then
			local buff = buffer.new(1024);
			while true do
				local ptr, n = buff:reserve(1024);
				local n, has_char = self._backend:readline(ptr, n, 0x0A --[['\n']]);

				if n == 0 then break end
				if has_char then
					if mode == "l" then
						buff:commit(n - 1);
					else
						buff:commit(n);
					end

					break;
				end

				buff:commit(n);
			end

			if #buff == 0 then return nil end
			return buff:tostring();
		elseif mode == "a" then
			local buff = buffer.new(1024);
			while true do
				local n = self._backend:read(buff:reserve(1024));
				if n == 0 then break end

				buff:commit(n);
			end

			if #buff == 0 then return nil end
			return buff:tostring();
		elseif mode == "c" then
			local buff = buffer.new();
			buff:commit(self._backend:read(buff:reserve(1024)));

			if #buff == 0 then return nil end
			return buff:tostring();
		elseif type(mode) == "number" then
			local buff = buffer.new();
			buff:commit(self._backend:read(buff:reserve(mode), mode));

			if #buff == 0 then return nil end
			return buff:tostring();
		else
			sig.error("mode", "must be an integer, 'l', 'L', 'c' or 'a'");
		end
	end
	function str_compat:write(...)
		for i = 1, select("#", ...) do
			-- TODO: OPTIMIZE!!!!
			local str = tostring((select(i, ...)));
			local buff = ffi.new("char[?]", #str);
			ffi.copy(buff, str);
			self._backend:fullwrite(buff, #str)
		end
	end
	function str_compat:stat()
		return self._backend:stat();
	end
	function str_compat:flush()
		return self._backend:flush();
	end
	function str_compat:close()
		return self._backend:close();
	end

	function str_compat:to_str()
		return self._backend;
	end

	--- @return std.str
	function str.text:to_str()
		return setmetatable({ _backend = self }, textstr_compat);
	end

	--- @param str std.str
	function str.text.from_stream(str)
		return setmetatable({ _backend = str:to_buff() }, str_compat);
	end
end


return str;

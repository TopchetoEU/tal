local ffi = require "nat.ffi"
local libc = require "nat.libc";
local text --[[ = require "std.str.text"]];

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

--- @class std.str: std.str.backend
--- @field _closed boolean
--- @field _rstack std.str.buffrange[]
--- @field _wbuff? std.str.buffrange
--- @field _wbuffc? integer
local str = {};
str.__index = str;
str.__metatable = "std.str";

str.chunksize = 8192;

--- @param ... string | integer
--- @return integer
function str.parsechmod(...)
	local mode = 0;

	for i = 1, select("#", ...) do
		local arg = select(i, ...);
		if type(arg) == "number" then
			mode = arg;
		elseif type(arg) == "string" then
			local op, arg = arg:match "^([+-]?)(.-)$";
			local iarg = assert(tonumber(arg, 8), arg);

			if op == "+" then
				mode = mode | iarg;
			elseif op == "-" then
				mode = mode & ~iarg;
			else
				mode = iarg;
			end
		end
	end

	return mode;
end

--- @param ptr ffi.cdata*
--- @param n integer
function str:read(ptr, n)
	if self._closed then ierror "closed" end

	local res_n = 0;

	while self._rstack and #self._rstack > 0 do
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
			self._rstack = self._rstack or {};
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
			self._rstack = self._rstack or {};
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
	if self._closed then ierror "closed" end

	if self._seek then
		self:_seek("cur", -n);
		return self;
	end

	if not ptr then ierror "seeking not supported" end

	local new_ptr = ffi.new("char[?]", n);
	ffi.copy(new_ptr, ptr, n);
	ptr = new_ptr;

	self._rstack = self._rstack or {};
	table.insert(self._rstack, { data = ptr, f = 0, l = n });
	return self;
end
function str:write(ptr, n)
	if self._closed then ierror "closed" end
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
	if self._closed then ierror "closed" end

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
---@return integer n
---@return boolean has_c If true, the output was trimmed to the newline char
function str:readline(ptr, n, char)
	n = self:read(ptr, n);

	local c_i = libc.strnchr(ptr, char, n);
	if c_i then
		self:unread(ptr + c_i + 1, n - c_i - 1);
		return c_i + 1, true;
	end

	return n, false;
end

--- Same as `readline`, but uses a `string.buffer` as a backend
---@param buff string.buffer
---@param char? integer = 0x0A
function str:readlineto(buff, char)
	repeat
		local ptr, ptr_n = buff:reserve(str.chunksize);
		local n, has_c = self:readline(ptr, ptr_n, char or 0x0A);
		buff:commit(n);
	until n == 0 or has_c;

	return buff;
end
--- Same as `read`, but reads to a `string.buffer`
---@param buff string.buffer
---@param n? integer = str.chunksize
function str:readto(buff, n)
	local res_n = self:read(buff:reserve(str.chunksize or n));
	buff:commit(res_n);
	return res_n;
end

--- Writes the given stream, string or string generator to the stream
--- @param src std.str
function str:pipe(src)
	if self._closed then ierror "closed" end

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
	if self._closed then ierror "closed" end

	if n then
		if not buff then buff = ffi.new("char[?]", n) end
		self._wbuff = { data = buff, f = 0, l = n };
	else
		self._wbuff = nil;
	end

	self._wbuff_char = char;

	return self;
end

--- @param whence? seekwhence
--- @param pos? integer
function str:seek(whence, pos)
	if self._closed then ierror "closed" end
	if not self._seek then ierror "not supported" end
	return self:_seek(whence or "cur", pos or 0);
end
--- @return std.io.stat
function str:stat()
	if self._closed then ierror "closed" end
	if not self._stat then ierror "not supported" end
	return self:_stat();
end
--- @param ... string | integer
function str:chmod(...)
	if self._closed then ierror "closed" end
	if not self._chmod then ierror "not supported" end

	self:_chmod(str.parsechmod(...));
	return self;
end
--- @param uid integer
--- @param gid integer
function str:chown(uid, gid)
	if self._closed then ierror "closed" end
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
	self._rstack = nil;
	self._wbuff = nil;
	return true;
end

function str:to_text()
	text = text or require "std.str.text";
	return text.new(self);
end

return str;

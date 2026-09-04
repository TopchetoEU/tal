local ffi = require "nat.ffi"
local libc = require "nat.libc";
local buffer = require "string.buffer";
local sig = require "std.sig";

--- @class std.str
local str = {};
do
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

	--- @return std.str
	function str:flush() return self end
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
	function str:to_text() return str.text.from_stream(self) end
end
--- @class std.file: std.str
str.file = setmetatable({}, str);
do
	str.file.__index = str.file;
	str.file.__metatable = "std.file";

	--- @param whence "set" | "cur" | "end"
	--- @param pos integer
	--- @return integer
	function str.file:seek(whence, pos) ierror "not supported" end

	--- @param ... string | integer
	--- @return std.file
	function str.file:chmod(...) ierror "not supported" end
	--- @param uid integer
	--- @param gid integer
	--- @return std.file
	function str.file:chown(uid, gid) ierror "not supported" end

	--- @param no_seek? boolean = false
	function str.file:to_buff(no_seek) return str.file.buff.new(self, no_seek) end
	function str.file:to_unbuff() return self end
	function str.file:to_text() return str.file.text.from_stream(self) end

	--- @return true
	function str:close() return true end

end

--- @class std.bstr: std.str
--- @field _closed boolean
--- @field _backend std.str
--- @field _rstack std.bstr.range[]
--- @field _wbuff? std.bstr.range
--- @field _wbuff_char? integer
str.buff = setmetatable({}, str);
do
	str.buff.__index = str.buff;
	str.buff.__metatable = "std.bstr";

	--- @class std.bstr.range
	--- @field data ffi.cdata*
	--- @field f integer
	--- @field l integer

	--- @param ptr ffi.cdata*
	--- @param n integer
	function str.buff:_rawread(ptr, n)
		return self._backend:read(ptr, n);
	end
	--- @param ptr ffi.cdata*
	--- @param n integer
	function str.buff:_rawwrite(ptr, n)
		self._backend:fullwrite(ptr, n);
	end

	--- @param ptr ffi.cdata*
	--- @param n integer
	function str.buff:read(ptr, n)
		local res_n = 0;

		while #self._rstack > 0 do
			if n <= 0 then break end

			local part = table.remove(self._rstack) --[[@as std.bstr.range]];
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

		return res_n + self:_rawread(ptr, n);
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

		local c_i = libc.strnchr(ptr, char, n);
		if c_i then
			self:unread(ptr + c_i + 1, n - c_i - 1);
			return c_i + 1, true;
		end

		return n, false;
	end

	function str.buff:flush()
		if self._wbuff and self._wbuff.f > 0 then
			self:_rawwrite(self._wbuff.data, self._wbuff.f);
			self._wbuff.f = 0;
		end

		return self._backend:flush();
	end

	function str.buff:write(ptr, n)
		if not self._wbuff then
			return self:_rawwrite(ptr, n);
		end

		-- We will either be overfilling the buffer or raw-writting
		-- Either way, we need to flush
		if self._wbuff.f + n > self._wbuff.l then
			self:flush();
		end

		-- We can't fit this in the buffer, so we will raw-write it
		-- TODO: handle flush chars better
		if n > self._wbuff.l then
			return self:_rawwrite(ptr, n);
		end

		local c_i = self._wbuff_char and libc.strnchr(ptr, self._wbuff_char, n);

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

	--- @param buff? ffi.cdata* The buffer to be used. If nil, allocated dynamically
	--- @param n? integer The size of the buffer. If nil, write side remains unbuffered
	--- @param char? integer The flush char. If nil, no char will flush the write buffer
	function str.buff:setwbuff(buff, n, char)
		if n then
			if not buff then buff = ffi.new("char[?]", n) end
			self._wbuff = { data = buff, f = 0, l = n };
		else
			self._wbuff = nil;
		end

		self._wbuff_char = char;

		return self;
	end

	function str.buff:close()
		if not self._closed then
			self:flush();
			self._backend:close();
			self._closed = true;
		end

		return true;
	end

	function str.buff:to_buff() return self end
	function str.buff:to_unbuff() return self._backend end

	--- @param backend std.str
	function str.buff.new(backend)
		return setmetatable({
			_backend = backend:to_unbuff(),
			_rstack = {},
			_wbuff = nil,
			_wbuff_char = nil,
		}, str.buff);
	end
end
--- @class std.bfile: std.file, std.bstr
--- @field _noseek boolean
--- @field _bstr std.bstr
--- @field _backend std.file
--- @field _rstack std.bstr.range[]
--- @field _wbuff std.bstr.range
str.file.buff = setmetatable({}, str.buff);
do
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
	--- @return std.file
	function str.file.buff:flush()
		if self._noseek then
			self._bstr:flush();
		else
			self._backend:flush();
		end

		return self;
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
	--- @param noseek? boolean
	function str.file.buff.new(backend, noseek)
		return setmetatable({
			_backend = backend:to_unbuff(),
			_bstr = str.buff.new(backend),
			_noseek = noseek or false,
		}, str.file.buff);
	end
end

--- @class std.bstr.chunked: std.str
--- @field _rstack std.bstr.range[]
str.chunked = setmetatable({}, str);
do
	str.chunked.__index = str;
	str.chunked.__metatable = "std.str.chunked";

	--- @return integer
	--- @return ffi.cdata*?
	function str.chunked:readchunk() ierror "not supported" end
	--- @param ptr ffi.cdata*
	--- @param n integer
	--- @return integer
	function str.chunked:writechunk(ptr, n) ierror "not supported" end

	function str.chunked:_rawread(ptr, n)
		local res_n = 0;

		while true do
			local data_n, data = self:readchunk();
			if data_n == 0 then return res_n end

			if data_n >= n then
				ffi.copy(ptr, data, n);

				if data_n > n then
					table.insert(self._rstack, { f = n, l = data_n, data = data });
				end

				return res_n + n;
			else
				ffi.copy(ptr, data, data_n);
				res_n = res_n + data_n;
				ptr = ptr + data_n
				n = n - data_n;
			end
		end
	end
	function str.chunked:read(ptr, n)
		-- A bit hacky, but I don't feel like writting this logic twice...
		return str.buff.read(self --[[@as any]], ptr, n);
	end
end

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
	--- @field _backend std.bstr
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

--- @class std.textfile: std.textstr
str.file.text = setmetatable({}, str.text);
--- @class std.textfile.compat
local textfile_compat;
--- @class std.file.compat
local file_compat;
do
	str.file.text.__index = str.file.text;
	str.file.text.__metatable = "std.textfile";

	--- @param ... string | integer
	--- @return std.textfile
	function str.file.text:chmod(...) ierror "not supported" end
	--- @param uid integer
	--- @param gid integer
	--- @return std.textfile
	function str.file.text:chown(uid, gid) ierror "not supported" end
	--- @param whence? seekwhence
	--- @param offset? integer
	--- @return std.textfile
	function str.file.text:seek(whence, offset) ierror "not supported" end

	--- @class std.textfile.compat: std.file
	--- @field _backend std.textfile
	textfile_compat = setmetatable({}, str.file);
	textfile_compat.__index = textfile_compat;
	textfile_compat.__metatable = "std.textfile.compat";

	textfile_compat.read = textstr_compat.read;
	textfile_compat.write = textstr_compat.write;
	textfile_compat.stat = textstr_compat.stat;
	textfile_compat.flush = textstr_compat.flush;
	textfile_compat.close = textstr_compat.close;

	function textfile_compat:seek(seek)
		return self._backend:seek(seek);
	end
	function textfile_compat:chmod(...)
		return self._backend:chmod(...);
	end
	function textfile_compat:chown(uid, gid)
		return self._backend:chown(uid, gid);
	end

	--- @class std.file.compat: std.str.compat, std.textfile
	--- @field _backend std.bfile
	file_compat = setmetatable({}, str_compat);
	file_compat.__index = file_compat;
	file_compat.__metatable = "std.textfile.compat";

	function file_compat:seek(whence, pos)
		return self._backend:seek(whence, pos);
	end
	function file_compat:chmod(...)
		return self._backend:chmod(...);
	end
	function file_compat:chown(uid, gid)
		return self._backend:chown(uid, gid);
	end

	--- @return std.str
	function str.file.text:to_str()
		return setmetatable({ _backend = self }, textfile_compat);
	end

	--- @param str std.file
	function str.file.text.from_stream(str)
		return setmetatable({ _backend = str:to_buff() }, file_compat);
	end
end

return str;

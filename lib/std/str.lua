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
	function str:to_lua() return str.lua.from_stream(self) end
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
	function str.file:to_lua() return str.file.lua.from_stream(self) end

	--- @return true
	function str:close() return true end

end

--- @class std.bstr: std.str
--- @field _backend std.str
--- @field _rstack std.bstr.range[]
--- @field _wbuff std.bstr.range
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
			return c_i + 1, true;
		end

		return n, false;
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

--- @class std.luastr
str.lua = {};
--- @class std.luastr.compat
local luastr_compat;
--- @class std.str.compat
local str_compat;
do
	str.__index = str;
	str.__metatable = "std.luastr";

	--- @param fmt std.io.readmode
	--- @return string?
	function str.lua:read(fmt) ierror "not supported" end
	--- @param ... any
	--- @return integer
	function str.lua:write(...) ierror "not supported" end
	--- @param whence? seekwhence
	--- @param pos? integer
	--- @return integer
	function str.lua:seek(whence, pos) ierror "not supported" end
	--- @param mode vbuf
	--- @param size? integer
	function str.lua:setvbuff(mode, size) ierror "not supported" end
	--- @return std.io.stat
	function str.lua:stat() ierror "not supported" end
	--- @return std.luastr
	function str.lua:flush() return self end
	function str.lua:close() return true end

	--- @param dst std.luastr
	--- @param close? boolean = false
	--- @param close_dst? boolean = close
	function str.lua:pipe(dst, close, close_dst)
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
	function str.lua:lines(fmt, close)
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

	--- @class std.luastr.compat: std.str
	--- @field _backend std.luastr
	luastr_compat = setmetatable({}, str);
	luastr_compat.__index = luastr_compat;
	luastr_compat.__metatable = "std.luastr.compat";

	function luastr_compat:read(ptr, n)
		local res = self._backend:read(n);
		if not res then return 0 end

		ffi.copy(ptr, res);
		return #res;
	end
	function luastr_compat:write(ptr, n)
		return self._backend:write(ffi.string(ptr, n));
	end
	function luastr_compat:stat()
		return self._backend:stat();
	end
	function luastr_compat:flush()
		return self._backend:flush();
	end
	function luastr_compat:close()
		return self._backend:close();
	end

	--- @class std.str.compat: std.luastr
	--- @field _backend std.bstr
	str_compat = setmetatable({}, str.lua);
	str_compat.__index = str_compat;
	str_compat.__metatable = "std.luastr.compat";

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
			local buff = buffer.new(1024);
			buff:commit(self._backend:read(buff:ref()));

			if #buff == 0 then return nil end
			return buff:tostring();
		elseif type(mode) == "number" then
			local buff = buffer.new(mode);
			buff:commit(self._backend:read(buff:ref()));

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
	function str.lua:to_str()
		return setmetatable({ _backend = self }, luastr_compat);
	end

	--- @param str std.str
	function str.lua.from_stream(str)
		return setmetatable({ _backend = str:to_buff() }, str_compat);
	end
end

--- @class std.luafile
str.file.lua = setmetatable({}, str.lua);
--- @class std.luafile.compat
local luafile_compat;
--- @class std.file.compat
local file_compat;
do
	str.__index = str;
	str.__metatable = "std.luafile";

	--- @param ... string | integer
	--- @return std.luafile
	function str.file.lua:chmod(...) ierror "not supported" end
	--- @param uid integer
	--- @param gid integer
	--- @return std.luafile
	function str.file.lua:chown(uid, gid) ierror "not supported" end

	--- @class std.luafile.compat: std.file
	--- @field _backend std.luafile
	luafile_compat = setmetatable({}, str.file);
	luafile_compat.__index = luafile_compat;
	luafile_compat.__metatable = "std.luafile.compat";

	function luafile_compat:chmod(...)
		return self._backend:chmod(...);
	end
	function luafile_compat:chown(uid, gid)
		return self._backend:chown(uid, gid);
	end

	--- @class std.file.compat: std.str.compat, std.luafile
	--- @field _backend std.bfile
	file_compat = setmetatable({}, str_compat);
	file_compat.__index = luafile_compat;
	file_compat.__metatable = "std.luafile.compat";

	function file_compat:chmod(...)
		return self._backend:chmod(...);
	end
	function file_compat:chown(uid, gid)
		return self._backend:chown(uid, gid);
	end

	--- @return std.str
	function str.file.lua:to_str()
		return setmetatable({ _backend = self }, luafile_compat);
	end

	--- @param str std.file
	function str.file.lua.from_stream(str)
		return setmetatable({ _backend = str:to_buff() }, str_compat);
	end
end

return str;

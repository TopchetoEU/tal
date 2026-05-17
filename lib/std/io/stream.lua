local collected = require "std.collected";
local loop = require "std.loop";
local sig = require "std.sig";

local buffer = require "string.buffer";

local ffi = require "ffi";
local libc = require "nat.libc";

--- @class std.io.stream.backend
--- @field read? fun(self, ptr: ffi.cdata*, n: integer): integer
--- @field write? fun(self, ptr: ffi.cdata*, n: integer): integer
--- @field seek? fun(self, offset: integer, whence: "set" | "cur" | "end"): integer
--- @field flush? fun(self)
--- @field close? fun(self)
---
--- @field stat? fun(self): std.io.stat
--- @field chmod? fun(self, mod: integer)
--- @field chown? fun(self, uid: integer, gid: integer)

--- @class std.io.stream
--- @field _backend std.io.stream.backend
--- @field buffr string.buffer
--- @field buffw string.buffer
--- @field _mngd boolean | string? If managed (aka not closed by the owner), this is set to true or a stack trace
local stream_index = {};

--- Reads raw data into the given buffers. Reads no more than buff_n
--- @param full boolean If true, fills the buffer, even if that requires multiple reads. If false, performs at most one read
--- @param buff ffi.cdata*
--- @param buff_n integer
function stream_index:ptrread(full, buff, buff_n)
	local acc_n = 0;

	if #self.buffr > buff_n then
		ffi.copy(buff, self.buffr:ref(), buff_n);
		self.buffr:skip(buff_n);
		return buff_n;
	elseif #self.buffr > 0 then
		local n = #self.buffr;

		ffi.copy(buff, self.buffr:ref());
		self.buffr:reset();

		if not full then return n end

		acc_n = acc_n + n;
	end

	while acc_n < buff_n do
		local read_n = self._backend:read(buff + acc_n, buff_n - acc_n);
		acc_n = acc_n + read_n;
		if not full then break end
	end

	return acc_n;
end
--- Writes buff_n bytes of buff to the stream
--- @param full boolean If true, calls write until all bytes are written. Else, calls just once. On almost all cases, you want 'true' here
--- @param buff ffi.cdata*
--- @param buff_n integer
function stream_index:ptrwrite(full, buff, buff_n)
	if not full then
		return self._backend:write(buff, buff_n);
	else
		local n = 0;

		while buff_n > 0 do
			local write_n = self._backend:write(buff, buff_n);
			if write_n == 0 then break end

			buff_n = buff_n - write_n;
			buff = buff + write_n;
			n = n + write_n;
		end

		return n;
	end
end

--- @param fmt std.io.readmode | string | integer?
--- @return string? data
function stream_index:read(fmt)
	fmt = fmt or "l";

	local function seek_remainder(res)
		if #self.buffr == 0 then return res end

		if self._backend.seek then
			self._backend:seek(-#self.buffr, "cur");
			self.buffr:reset();
		end

		return res;
	end
	--- @param n? integer
	local function copy_res(n)
		return self.buffr:get(n);
	end

	--- @type fun(buff: ffi.cdata*, n: integer): string?, string?
	local process;

	--- @param n? integer
	local function read_next(n)
		local ptr, ptr_n = self.buffr:reserve(n or 8192);
		local read_n = self._backend:read(ptr, ptr_n);
		if read_n == 0 then
			if #self.buffr == 0 and fmt ~= "a" then
				return nil;
			else
				return seek_remainder(copy_res());
			end
		end
		self.buffr:commit(read_n);
		return process(ptr, read_n);
	end
	--- @param n? integer
	local function read_first(n)
		if #self.buffr > 0 then
			return process(self.buffr:ref());
		else
			return read_next(n);
		end
	end

	if type(fmt) == "number" then
		function process()
			if #self.buffr >= fmt then
				return seek_remainder(copy_res(fmt));
			end

			return read_next(fmt --[[@as number]] - #self.buffr);
		end

		return read_first(fmt);
	elseif fmt == "c" then
		function process()
			return seek_remainder(copy_res());
		end
	elseif fmt == "a" then
		function process()
			return read_next();
		end
	elseif fmt:find "^[lL]" then
		local bigl = fmt:find "^L";
		local eol = fmt:byte(2) or ("\n"):byte();

		function process(ptr, n)
			local nl_ptr = libc.strnchr(ptr, eol, n);
			if nl_ptr then
				local nl_i = nl_ptr + 1;

				if bigl then
					return seek_remainder(copy_res(#self.buffr - n + nl_i));
				else
					local res = copy_res(#self.buffr - n + nl_i - 1);
					self.buffr:skip(1);
					return seek_remainder(res);
				end
			end

			return read_next();
		end
	else
		return sig.error("fmt", "invalid format");
	end

	return read_first();
end
--- @param ... string | integer | string.buffer
function stream_index:write(...)
	local function flush_buff()
		if #self.buffw > 0 then
			self:ptrwrite(true, self.buffw:ref());
			self.buffw:reset();
		end
	end

	for i = 1, select("#", ...) do
		local arg = select(i, ...);

		if getmetatable(arg) == "buffer" then
			flush_buff();
			self:ptrwrite(true, arg:ref());
		else
			self.buffw:put(arg);
		end
	end

	flush_buff();
	return self;
end

--- Writes the given stream, string or string generator to the stream
--- @param other std.io.stream | string | (fun(): string)
function stream_index:pipe(other)
	if type(other) == "string" then
		self:write(other);
	elseif type(other) == "function" then
		for part in other do
			self:write(part);
		end
	else
		local buff = buffer.new();

		while true do
			local read_n = other:ptrread(false, buff:reserve(4096));
			buff:commit(read_n);

			local write_n = self:ptrwrite(true, buff:ref());
			buff:skip(write_n);

			if read_n == 0 then break end
		end
	end

	return self;
end

--- @param whence "set" | "cur" | "end"
--- @param pos integer
function stream_index:seek(whence, pos)
	if not self._backend.seek then
		return nil, "seeking not supported";
	end

	return self._backend:seek(pos, whence);
end
function stream_index:flush()
	if self._backend.flush then
		self._backend:flush();
	end
end

--- @return std.io.stat
function stream_index:stat()
	if not self._backend.stat then ierror "not supported" end
	return iassert(self._backend:stat());
end
--- @param mode integer | string
function stream_index:chmod(mode)
	if type(mode) == "string" then mode = assert(tonumber(mode, 8), "bad mode") end
	if not self._backend.chmod then ierror "not supported" end
	iassert(self._backend:chmod(mode));
	return self;
end
--- @param uid integer
--- @param gid integer
function stream_index:chown(uid, gid)
	if not self._backend.chown then ierror "not supported" end
	iassert(self._backend:chown(uid, gid));
	return self;
end

--- @param fmt? std.io.readmode
--- @param close? boolean
function stream_index:lines(fmt, close)
	return function ()
		local res = self:read(fmt);
		if close and not res then self:close() end

		return res;
	end
end

function stream_index:close()
	if self._mngd then
		self._mngd = nil;
		self._backend:close();
	end

	-- Let standard lua code assert close()
	return true;
end

local stream_meta = {
	__index = stream_index,
	__close = stream_index.close,
};

--- @param self std.io.stream
function stream_meta:__gc()
	if self._mngd then
		self:close();
	end
end

--- @param backend? std.io.stream.backend
--- @param mngd? string | true
--- @return std.io.stream
local function new(backend, mngd)
	return collected(setmetatable({
		buffr = buffer.new(),
		buffw = buffer.new(),
		_backend = backend,
		_mngd = mngd or true,
	}, stream_meta));
end
--- NOTE: doesn't support seeking
--- @param read std.io.stream
--- @param write std.io.stream
local function combine(read, write)
	local mngd = read._mngd or write._mngd;
	if mngd == true and write._mngd then
		mngd = write._mngd;
	end

	return new({
		read_str = read,
		write_str = write,

		read = function (self, ptr, n)
			if not self.read_str then ierror "closed" end
			return self.read_str:rawread(ptr, n);
		end,
		write = function (self, ptr, n)
			if not self.write_str then ierror "closed" end
			return self.write_str:rawwrite(true, ptr, n);
		end,
		sync = function (self, ctx, cb)
			if not self.read_str then ierror "closed" end
			if not self.write_str then ierror "closed" end

			self.read_str:flush();
			self.write_str:flush();
		end,
		close = function (self)
			if self.read_str then
				self.read_str:close();
				self.read_str = nil;
			end
			if self.write_str then
				self.write_str:close();
				self.write_str = nil;
			end
		end,
	}, mngd);
end

--- @param file _impl.file
local function from_file(file)
	local self = {
		fd = file,
		ptr = 0,
	};

	function self:read(ptr, n)
		if not self.fd then ierror "closed" end

		local read_n = iassert(loop.sync_ret(self.fd:read(coroutine.running(), self.ptr, ptr, n)));
		self.ptr = self.ptr + read_n;
		return read_n;
	end
	function self:write(ptr, n)
		if not self.fd then ierror "closed" end

		local write_n = iassert(loop.sync_ret(self.fd:write(coroutine.running(), self.ptr, ptr, n)));
		self.ptr = self.ptr + write_n;
		return write_n;
	end
	function self:seek(offset, whence)
		if not self.fd then ierror "closed" end

		if whence == "set" then
			self.ptr = offset;
		elseif whence == "cur" then
			self.ptr = self.ptr + offset;
		elseif whence == "end" then
			local stat = iassert(loop.sync_ret(self.fd:stat(coroutine.running())));
			self.ptr = self.ptr + stat.size;
		end

		if self.ptr < 0 then self.ptr = 0 end

		return self.ptr;
	end
	function self:flush()
		if not self.fd then ierror "closed" end
		iassert(loop.sync_ret(self.fd:flush((coroutine.running()))));
	end
	function self:stat()
		if not self.fd then ierror "closed" end
		return iassert(loop.sync_ret(self.fd:stat((coroutine.running()))));
	end
	function self:chmod(mode)
		if not self.fd then ierror "closed" end
		iassert(loop.sync_ret(self.fd:chmod((coroutine.running()), mode)));
	end
	function self:chown(uid, gid)
		if not self.fd then ierror "closed" end
		iassert(loop.sync_ret(self.fd:chown((coroutine.running()), uid, gid)));
	end
	function self:close()
		if self.fd then
			self.fd:close();
			self.fd = nil;
		end

		return true;
	end

	return new(self, true);
end

--- @param str _impl.stream
local function from_stream(str, mngd)
	local self = { fd = str };

	function self:read(ptr, n)
		if not self.fd then ierror "closed" end
		return iassert(loop.sync_ret(self.fd:read(coroutine.running(), ptr, n)));
	end
	function self:write(ptr, n)
		if not self.fd then ierror "closed" end
		return iassert(loop.sync_ret(self.fd:write(coroutine.running(), ptr, n)));
	end
	function self:flush()
		if not self.fd then ierror "closed" end
		iassert(loop.sync_ret(self.fd:flush((coroutine.running()))));
	end
	function self:stat()
		if not self.fd then ierror "closed" end
		return iassert(loop.sync_ret(self.fd:stat((coroutine.running()))));
	end
	function self:close()
		if self.fd then
			self.fd:close();
			self.fd = nil;
		end

		return true;
	end

	return new(self, mngd);
end

return {
	new = new,
	combine = combine,
	from_file = from_file,
	from_stream = from_stream
};

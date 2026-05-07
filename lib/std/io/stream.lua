local collected = require "std.collected";
local buffer = require "string.buffer";
local loop = require "std.loop";
local ffi = require "ffi";
local sig = require "std.sig";

--- @class std.io.stream.backend
--- @field read? fun(self, ptr: ffi.cdata*, n: integer): integer?, string?
--- @field write? fun(self, ptr: ffi.cdata*, n: integer): integer?, string?
--- @field seek? fun(self, offset: integer, whence: "set" | "cur" | "end"): integer?, string?
--- @field stat? fun(self): std.io.stat?, string?
--- @field flush? fun(self): true?, string?
--- @field close? fun(self): true?, string?

--- @class std.io.stream
--- @field _backend std.io.stream.backend
--- @field buffr string.buffer
--- @field buffw string.buffer
--- @field _mngd boolean | string? If managed (aka not closed by the owner), this is set to true or a stack trace
local stream_index = {};

local libc = ffi.C;
ffi.cdef [[
	void *memchr(const void *stack, int needle, size_t len);
]];

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
			local write_n, err = self._backend:write(buff, buff_n);
			if err then return nil, err end
			if not write_n or write_n == 0 then break end

			buff_n = buff_n - write_n;
			buff = buff + write_n;
			n = n + write_n;
		end

		return n;
	end
end
--- Reads raw data into the given buffers. Reads no more than buff_n
--- @param full boolean If true, fills the buffer, even if that requires multiple reads. If false, performs at most one read
--- @param buff ffi.cdata*
--- @param buff_n integer
--- @return integer? n
--- @return string? err
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
		local read_n, err = self._backend:read(buff + acc_n, buff_n - acc_n);
		if err then return nil, err end

		acc_n = acc_n + read_n;
		if not full then break end
	end

	return acc_n;
end

--- @param fmt std.io.readmode | string | integer?
--- @return string? data
--- @return string? err
function stream_index:read(fmt)
	fmt = fmt or "l";

	local function seek_remainder(res)
		if #self.buffr == 0 then return res end

		if self._backend.seek then
			local _, err = self._backend:seek(-#self.buffr, "cur");
			if err then return nil, err end
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
		local read_n, err = self._backend:read(ptr, ptr_n);
		if err then return nil, err end
		if read_n == 0 or not read_n then
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
			local nl_ptr = libc.memchr(ptr, eol, n);
			if nl_ptr ~= ffi.cast("void*", 0) then
				local nl_i = ffi.cast("char*", nl_ptr) - ffi.cast("char*", ptr) + 1;

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
		if #self.buffw == 0 then return true end

		local _, err = self:ptrwrite(true, self.buffw:ref());
		if err then return nil, err end

		self.buffw:reset();

		return true;
	end

	for i = 1, select("#", ...) do
		local arg = select(i, ...);

		if getmetatable(arg) == "buffer" then
			local _, err = flush_buff();
			if err then return nil, err end

			local _, err = self:ptrwrite(true, arg:ref());
			if err then return nil, err end
		else
			self.buffw:put(arg);
		end
	end

	local _, err = flush_buff();
	if err then return nil, err end

	return self;
end

--- @param pos integer
--- @param whence "set" | "cur" | "end"
function stream_index:seek(pos, whence)
	if not self._backend.seek then
		return nil, "seeking not supported";
	end

	return self._backend:seek(pos, whence);
end
function stream_index:flush()
	if not self._backend.flush then return true end
	return self._backend:flush();
end
function stream_index:stat()
	if not self._backend.stat then return nil, "not supported" end
	return self._backend:stat();
end

--- @param fmt? std.io.readmode
--- @param close? boolean
function stream_index:lines(fmt, close)
	return function ()
		local res, err = self:read(fmt);
		if close and not res then self:close() end
		if err then error(err, 2) end

		return res;
	end
end

--- @return true?, string?
function stream_index:close()
	self._mngd = nil;
	return self._backend:close();
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
		_mngd = mngd,
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
			if not self.read_str then return nil, "closed" end
			return self.read_str:rawread(ptr, n);
		end,
		write = function (self, ptr, n)
			if not self.write_str then return nil, "closed" end
			return self.write_str:rawwrite(true, ptr, n);
		end,
		sync = function (self, ctx, cb)
			if not self.read_str then return nil, "closed" end
			if not self.write_str then return nil, "closed" end

			local _, err = self.read_str:flush();
			if err then return nil, err end

			local _, err = self.write_str:flush();
			if err then return nil, err end

			return true;
		end,
		close = function (self)
			if self.read_str then
				local ok, err = self.read_str:close();
				if not ok then return nil, err end
				self.read_str = nil;
			end
			if self.write_str then
				local ok, err = self.write_str:close();
				if not ok then return nil, err end
				self.write_str = nil;
			end

			return true;
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
		if not self.fd then return nil, "closed" end

		local read_n, err = loop.sync_ret(self.fd:read(coroutine.running(), self.ptr, ptr, n));
		if read_n then self.ptr = self.ptr + read_n end
		return read_n, err;
	end
	function self:write(ptr, n)
		if not self.fd then return nil, "closed" end

		local write_n, err = loop.sync_ret(self.fd:write(coroutine.running(), self.ptr, ptr, n));
		if write_n then self.ptr = self.ptr + write_n end
		return write_n, err;
	end
	function self:seek(offset, whence)
		if not self.fd then return nil, "closed" end

		if whence == "set" then
			self.ptr = offset;
		elseif whence == "cur" then
			self.ptr = self.ptr + offset;
		elseif whence == "end" then
			local stat, err = loop.sync_ret(self.fd:stat(coroutine.running()));
			if not stat then return nil, err end
			self.ptr = self.ptr + stat.size;
		end

		if self.ptr < 0 then self.ptr = 0 end

		return self.ptr;
	end
	function self:flush()
		if not self.fd then return nil, "closed" end
		return loop.sync_ret(self.fd:flush((coroutine.running())));
	end
	function self:stat()
		if not self.fd then return nil, "closed" end
		return loop.sync_ret(self.fd:stat((coroutine.running())));
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
	local self = {
		fd = str,
	};

	function self:read(ptr, n)
		if not self.fd then return nil, "closed" end
		return loop.sync_ret(self.fd:read(coroutine.running(), ptr, n));
	end
	function self:write(ptr, n)
		if not self.fd then return nil, "closed" end
		return loop.sync_ret(self.fd:write(coroutine.running(), ptr, n));
	end
	function self:flush()
		if not self.fd then return nil, "closed" end
		return loop.sync_ret(self.fd:flush((coroutine.running())));
	end
	function self:stat()
		if not self.fd then return nil, "closed" end
		return loop.sync_ret(self.fd:stat((coroutine.running())));
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

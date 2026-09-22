local str = require "std.str";
local ffi = require "ffi";
local libz = require "nat.libz";
local buffer = require "string.buffer";
local libc = require "nat.libc";
local cross = require "std.str.cross";

local zlib = {};

--- @class std.proto.zlib.inflate_opts: nat.libz.inflate_opts
--- @field backend std.str
--- @field owned boolean

--- @class std.proto.zlib.deflate_opts: nat.libz.deflate_opts
--- @field backend std.str
--- @field owned boolean

--- @class std.proto.zlib.conn_opts: std.proto.zlib.deflate_opts, std.proto.zlib.inflate_opts

--- @class std.proto.zlib.reader: std.str
--- @field _backend std.str
--- @field _owned boolean
--- @field _ptr nat.libz.stream
--- @field _kind "inflate" | "deflate"
zlib.reader = setmetatable({}, str);
zlib.reader.__index = zlib.reader;
zlib.reader.__metatable = "std.proto.zlib.reader";

function zlib.reader:_readto(dst)
	local src = buffer.new();
	local read_n, write_n = 0, 0;

	local dst_ptr, dst_n = dst:reserve(str.chunksize);

	repeat
		if read_n == 0 then self._backend:readto(src, str.chunksize) end

		local src_ptr, src_n = ffi.toptr_unsafe(src);
		write_n, read_n = self._ptr:next(self._kind, dst_ptr, dst_n, src_ptr, src_n, #src == 0);

		src:skip(read_n);
	until write_n ~= 0 or read_n == 0;

	while write_n ~= 0 do
		dst:commit(write_n);

		local dst_ptr, dst_n = dst:reserve(str.chunksize);
		write_n = self._ptr:next(self._kind, dst_ptr, dst_n, libc.NULL, 0, #src == 0);
	end
end
function zlib.reader:_close()
	if self._owned then
		self._backend:close();
	end
end
--- @param backend std.str
--- @param stream nat.libz.stream
--- @param kind string
function zlib.reader.new(backend, stream, kind, owned)
	return setmetatable({ _backend = backend, _ptr = stream, _kind = kind, _owned = owned }, zlib.reader);
end

--- @class std.proto.zlib.writer: std.str
--- @field _backend std.str
--- @field _ptr nat.libz.stream
--- @field _kind "inflate" | "deflate"
--- @field _owned boolean
zlib.writer = setmetatable({}, str);
zlib.writer.__index = zlib.writer;
zlib.writer.__metatable = "std.proto.zlib.writer";

function zlib.writer:_write(ptr, n)
	local res_n = n;
	local dst_buff = ffi.new("char[?]", str.chunksize);

	while true do
		local write_n, read_n = self._ptr:next(self._kind, dst_buff, str.chunksize, ptr, n);

		ptr = ptr + read_n;
		n = n - read_n;

		if write_n > 0 then self._backend:write(dst_buff, write_n) end
		if n == 0 then break end
	end

	return res_n;
end
function zlib.writer:_close()
	local buff = ffi.new("char[?]", str.chunksize);

	while true do
		local write_n = self._ptr:next(self._kind, buff, str.chunksize, libc.NULL, 0, true);
		if write_n == 0 then break end
		self._backend:write(buff, write_n);
	end

	if self._owned then
		self._backend:close();
	end
end
--- @param backend std.str
--- @param stream nat.libz.stream
--- @param kind string
function zlib.writer.new(backend, stream, kind, owned)
	return setmetatable({ _backend = backend, _ptr = stream, _kind = kind, _owned = owned }, zlib.writer);
end

--- @param opts std.proto.zlib.inflate_opts
function zlib.inflate_reader(opts)
	return zlib.reader.new(opts.backend, libz.new_inflate(opts), "inflate", opts.owned);
end
--- @param opts std.proto.zlib.deflate_opts
function zlib.deflate_reader(opts)
	return zlib.reader.new(opts.backend, libz.new_deflate(opts), "deflate", opts.owned);
end

--- @param opts std.proto.zlib.inflate_opts
function zlib.inflate_writer(opts)
	return zlib.writer.new(opts.backend, libz.new_inflate(opts), "inflate", opts.owned);
end
--- @param opts std.proto.zlib.deflate_opts
function zlib.deflate_writer(opts)
	return zlib.writer.new(opts.backend, libz.new_deflate(opts), "deflate", opts.owned);
end

--- Creates a client that deflates written data and inflates read data
--- @param opts std.proto.zlib.conn_opts
function zlib.conn(opts)
	return cross.new(zlib.deflate_reader(opts), zlib.inflate_writer(opts));
end

return zlib;

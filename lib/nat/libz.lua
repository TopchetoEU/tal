local ffi = require "ffi";
local libc = require "nat.libc";
local errors = require "std.errors";

local libz = ffi.load "z";
ffi.cdef [[
	typedef enum {
		Z_NO_FLUSH,
		Z_PARTIAL_FLUSH,
		Z_SYNC_FLUSH,
		Z_FULL_FLUSH,
		Z_FINISH,
		Z_BLOCK,
		Z_TREES,
	} z_flush_type;
	typedef enum {
		Z_OK = 0,
		Z_STREAM_END = 1,
		Z_NEED_DICT = 2,
		Z_ERRNO = -1,
		Z_STREAM_ERROR = -2,
		Z_DATA_ERROR = -3,
		Z_MEM_ERROR = -4,
		Z_BUF_ERROR = -5,
		Z_VERSION_ERROR = -6,
	} z_errno;
	typedef enum {
		Z_DEFAULT_STRATEGY,
		Z_FILTERED,
		Z_HUFFMAN_ONLY,
		Z_RLE,
		Z_FIXED,
	} z_strategy;
	typedef enum {
		Z_DEFLATED = 8,
	} z_method;
	typedef enum {
		Z_BINARY,
		Z_TEXT,
		Z_UNKNOWN,
	} z_datatype;

	typedef void *(*z_alloc_func)(void *opaque, unsigned items, unsigned size);
	typedef void (*z_free_func)(void *opaque, void *address);

	typedef struct {
		unsigned char *next_in;
		unsigned int avail_in;
		unsigned long total_in;

		unsigned char *next_out;
		unsigned int avail_out;
		unsigned long total_out;

		char *msg;
		void *state;

		z_alloc_func zalloc;
		z_free_func zfree;
		void *opaque;

		int data_type;

		unsigned long adler;
		unsigned long reserved;
	} z_stream, *z_streamp;

	int inflateInit2_(z_streamp strm, int windowBits, const char *version, int stream_size);
	int inflateEnd(z_streamp strm);
	int inflate(z_streamp strm, z_flush_type flush);

	int deflateInit2_(z_streamp strm, int level, int method, int windowBits, int memLevel, int strategy, const char *version, int stream_size);
	int deflateEnd(z_streamp strm);
	int deflate(z_streamp strm, z_flush_type flush);
]];

local zlib = { [require "std.package.strongtag"] = true };

--- @class nat.libz.inflate_opts
--- @field format? "detect" | "zlib" | "gzip" | "raw"
--- @field window? integer

--- @class nat.libz.deflate_opts
--- @field format? "detect" | "zlib" | "gzip" | "raw"
--- @field window? integer
--- @field level? integer
--- @field strategy? "filtered" | "rle" | "huffman" | "fixed"

local function zalloc(opaque, items, size)
	return libc.malloc(items * size);
end
local function zfree(opaque, ptr)
	return libc.free(ptr);
end

local zalloc_cb = ffi.cast("z_alloc_func", zalloc);
local zfree_cb = ffi.cast("z_free_func", zfree);

local function zassert(code)
	if code == libz.Z_ERRNO then return error "syscall error" end
	if code == libz.Z_STREAM_ERROR then return error "invalid parameters or state" end
	if code == libz.Z_DATA_ERROR then return error "invalid data" end
	if code == libz.Z_MEM_ERROR then return error(errors.nomem) end
	if code == libz.Z_BUF_ERROR then return error "out of buffer room" end
	if code == libz.Z_VERSION_ERROR then return error "invalid zlib version" end
	if code < 0 then return error "unknown zlib error" end

	return code;
end

--- @class nat.libz.stream: ffi.cdata*
--- @field next_in ffi.cdata*
--- @field avail_in integer
--- @field total_in integer
---
--- @field next_out ffi.cdata*
--- @field avail_out integer
--- @field total_out integer
---
--- @field msg ffi.cdata*
---
--- @field zalloc ffi.cdata*
--- @field zfree ffi.cdata*
local zlib_stream = {}
zlib_stream.__index = zlib_stream;
zlib_stream.__metatable = "nat.libz.stream";
local zlib_stream_type = ffi.metatype("z_stream", zlib_stream);

function zlib_stream:__gc()
	libz.inflateEnd(self);
end

--- @param kind "inflate" | "deflate"
--- @param dst ffi.cdata*
--- @param dst_n integer
--- @param src ffi.cdata*
--- @param src_n integer
--- @param eof? boolean = false
--- @return integer write_n
--- @return integer read_n
function zlib_stream:next(kind, dst, dst_n, src, src_n, eof)
	self.next_in = src;
	self.avail_in = src_n;

	self.next_out = dst;
	self.avail_out = dst_n;

	local icode;
	if kind == "inflate" then
		icode = libz.inflate(self, eof and libz.Z_FINISH or libz.Z_NO_FLUSH);
	else
		icode = libz.deflate(self, eof and libz.Z_FINISH or libz.Z_NO_FLUSH);
	end

	if icode ~= libz.Z_BUF_ERROR then zassert(icode) end

	return
		number.new(dst_n - self.avail_out),
		number.new(src_n - self.avail_in);
end

--- @param opts? nat.libz.inflate_opts
function zlib_stream.new_inflate(opts)
	local window = opts and opts.window or 15;
	local format = opts and opts.format or "detect";

	if format == "detect" then window = window + 32 end
	if format == "gzip" then window = window + 16 end
	if format == "raw" then window = -window end

	local res = ffi.cast("z_streamp", libc.malloc(ffi.sizeof(zlib_stream_type))) --[[@as nat.libz.stream]];
	res.zalloc = zalloc_cb;
	res.zfree = zfree_cb;

	zassert(libz.inflateInit2_(res, window, "1.3.2", ffi.sizeof(zlib_stream_type)));

	return res;
end
--- @param opts? nat.libz.deflate_opts
function zlib_stream.new_deflate(opts)
	local window = opts and opts.window or 15;
	local format = opts and opts.format or "zlib";
	local strategy = opts and opts.strategy or nil;
	local level = opts and opts.level or 8;

	if format == "gzip" then window = window + 16 end
	if format == "raw" then window = -window end

	local istrategy = libz.Z_DEFAULT_STRATEGY;
	if strategy == "filtered" then istrategy = libz.Z_FILTERED end
	if strategy == "rle" then istrategy = libz.Z_RLE end
	if strategy == "huffman" then istrategy = libz.Z_HUFFMAN_ONLY end
	if strategy == "fixed" then istrategy = libz.Z_FIXED end

	local res = ffi.cast("z_streamp", libc.malloc(ffi.sizeof(zlib_stream_type))) --[[@as nat.libz.stream]];
	res.zalloc = zalloc_cb;
	res.zfree = zfree_cb;

	zassert(libz.deflateInit2_(res, level, libz.Z_DEFLATED, window, 8, istrategy, "1.3.2", ffi.sizeof(zlib_stream_type)));

	return res;
end

return zlib_stream;

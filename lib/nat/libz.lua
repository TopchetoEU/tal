local ffi = require "ffi";
local field = require "std.field";
local objects = require "nat.utils.objects";
local libc    = require "nat.libc"

local libz = ffi.load "z";
ffi.cdef [[
	enum {
		Z_NO_FLUSH,
		Z_PARTIAL_FLUSH,
		Z_SYNC_FLUSH,
		Z_FULL_FLUSH,
		Z_FINISH,
		Z_BLOCK,
		Z_TREES,
	} flush_type;
	enum {
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
	enum {
		Z_DEFAULT_STRATEGY,
		Z_FILTERED,
		Z_HUFFMAN_ONLY,
		Z_RLE,
		Z_FIXED,
	} z_strategy;
	enum {
		Z_DEFLATED = 8,
	} z_method;
	enum {
		Z_BINARY,
		Z_TEXT,
		Z_UNKNOWN,
	} z_datatype;

	typedef void *(*alloc_func)(void *opaque, uInt items, uInt size);
	typedef void (*free_func)(void *opaque, void *address);

	typedef struct {
		unsigned char *next_in;
		unsigned int avail_in;
		unsigned long total_in;

		unsigned char *next_out;
		unsigned int avail_out;
		unsigned long total_out;

		char *msg;
		void *state;

		alloc_func zalloc;
		free_func zfree;
		void *opaque;

		int data_type;

		unsigned long adler;
		unsigned long reserved;
	} z_stream;

	typedef struct { z_stream str; } z_istream, *z_istreamp;
	typedef struct { z_stream str; } z_dstream, *z_dstreamp;

	int inflateInit2_(z_istreamp strm, int windowBits, const char *version, int stream_size);
	int inflateEnd(z_istreamp strm);
	int inflate(z_istreamp strm, flush_type flush);

	int deflateInit2_(z_dstreamp strm, int level, int method, int windowBits, int memLevel, int strategy, const char *version, int stream_size);
	int deflateEnd(z_dstreamp strm);
	int deflate(z_dstreamp strm, flush_type flush);

	// These are very internal and very not safe for usage, but its much better than passing a lua callback
	void *zcalloc(void *opaque, unsigned items, unsigned size);
	void zcfree(void *opaque, void *ptr);
]];

local zlib = {};

--- @class nat.libz.stream: ffi.cdata*
---
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
--- @field zalloc function
--- @field zfree function

local function zassert(code)
	if code == libz.Z_ERRNO then return error "io error" end
	if code == libz.Z_STREAM_ERROR then return error "invalid parameters or state" end
	if code == libz.Z_DATA_ERROR then return error "invalid data" end
	if code == libz.Z_MEM_ERROR then return error "out of memory" end
	if code == libz.Z_BUF_ERROR then return error "out of buffer room" end
	if code == libz.Z_VERSION_ERROR then return error "invalid zlib version" end
	if code ~= libz.Z_OK then return error "unknown zlib error" end

	return code;
end

--- @class nat.libz.istream: ffi.cdata*
--- @field str nat.libz.stream
local zlib_istream = {}
zlib_istream.__index = zlib_istream;
zlib_istream.__metatable = "libz.istream";
local zlib_istream_type = ffi.metatype("z_istream", zlib_istream);

function zlib_istream:__gc()
	libz.inflateEnd(self);
end

--- @param dst ffi.cdata*
--- @param dst_n integer
--- @param src ffi.cdata*
--- @param src_n integer
--- @return integer write_n
--- @return integer read_n
function zlib_istream:next(dst, dst_n, src, src_n)
	self.str.next_in = src;
	self.str.avail_in = src_n;

	self.str.next_out = dst;
	self.str.avail_out = dst_n;

	zassert(libz.inflate(self, src_n == 0 and libz.Z_FINISH or libz.Z_NO_FLUSH));

	return number.new(dst_n - self.str.avail_out), number.new(src_n - self.str.avail_in);
end

--- @param opts? zlib.inflate_opts
function zlib_istream.new(opts)
	local window = opts and opts.window or 15;
	local format = opts and opts.format or "detect";

	if format == "detect" then window = window + 32 end
	if format == "gzip" then window = window + 16 end
	if format == "raw" then window = -window end

	local res = ffi.cast("z_istreamp", libc.malloc(ffi.sizeof(zlib_istream_type))) --[[@as nat.libz.istream]];
	res.str.zalloc = libz.zcalloc;
	res.str.zfree = libz.zfree;

	zassert(libz.inflateInit2_(res, window, "1.3.2", ffi.sizeof(zlib_istream_type)));

	return res;
end

--- @class nat.libz.dstream: ffi.cdata*
--- @field str nat.libz.stream
local zlib_dstream = {}
zlib_dstream.__index = zlib_dstream;
zlib_dstream.__metatable = "libz.dstream";
local zlib_dstream_type = ffi.metatype("z_dstream", zlib_dstream);

function zlib_dstream:__gc()
	libz.deflateEnd(self);
end

--- @param dst ffi.cdata*
--- @param dst_n integer
--- @param src ffi.cdata*
--- @param src_n integer
--- @return integer write_n
--- @return integer read_n
function zlib_dstream:next(dst, dst_n, src, src_n)
	self.str.next_in = src;
	self.str.avail_in = src_n;

	self.str.next_out = dst;
	self.str.avail_out = dst_n;

	zassert(libz.deflate(self, src_n == 0 and libz.Z_FINISH or libz.Z_NO_FLUSH));

	return number.new(dst_n - self.str.avail_out), number.new(src_n - self.str.avail_in);
end


--- @param opts? zlib.deflate_opts
function zlib_dstream.new(opts)
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

	local res = ffi.cast("z_dstreamp", libc.malloc(ffi.sizeof(zlib_dstream_type))) --[[@as nat.libz.dstream]];
	res.str.zalloc = libz.zcalloc;
	res.str.zfree = libz.zfree;

	zassert(libz.deflateInit2_(res, level, libz.Z_DEFLATE, window, 8, istrategy, "1.3.2", ffi.sizeof(zlib_istream_type)));

	return res;
end

zlib.istream = zlib_istream;
zlib.dstream = zlib_dstream;

return zlib;

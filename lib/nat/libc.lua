local ffi = require "nat.ffi";

local libc = ffi.C;
ffi.cdef [[
void *malloc(size_t n);
void free(void *ptr);

size_t strlen(const char *ptr);
size_t strnlen(const char *ptr, size_t max);

int strcmp(const char *a, const char *b);
int strncmp(const char *a, const char *b, size_t n);

const char *strchr(const char *str, char c);
const char *memchr(const char *str, char c, size_t n);

const char *strrchr(const char *str, char c);
const char *memrchr(const char *str, char c, size_t n);
]];

local c = {};

c.NULL = ffi.cast("void*", 0);

--- @param ptr ffi.cdata*
--- @param n? integer
function c.strlen(ptr, n)
	return n and libc.strnlen(ptr, n) or libc.strlen(ptr);
end
function c.malloc(n)
	local res = libc.malloc(n);
	if res == ffi.cast("void*", 0) then error "out of memory" end
	return res;
end
function c.malloc_gc(n)
	return ffi.gc(c.malloc(n), c.free);
end
function c.free(ptr)
	return libc.free(ptr);
end

--- @param str string
function c.strdup(str)
	local res = c.malloc(#str);
	ffi.copy(res, str);
	return res;
end
--- @param str string
function c.strdup_gc(str)
	local res = c.malloc_gc(#str);
	ffi.copy(res, str);
	return res;
end

function c.strcmp(a, b)
	return assert(tonumber(libc.strcmp(a, b)));
end
function c.strncmp(a, b, n)
	return assert(tonumber(libc.strncmp(a, b, n)));
end
function c.strchr(str, char)
	local ptr = libc.strchr(str, char);
	if ptr == ffi.cast("void*", 0) then return nil end
	return assert(tonumber(ptr - str));
end
function c.strnchr(str, char, n)
	local ptr = libc.memchr(str, char, n);
	if ptr == ffi.cast("void*", 0) then return nil end
	return assert(tonumber(ptr - str));
end
function c.strrchr(str, char)
	local ptr = libc.strrchr(str, char);
	if ptr == ffi.cast("void*", 0) then return nil end
	return assert(tonumber(ptr - str));
end
function c.strnrchr(str, char, n)
	local ptr = libc.memrchr(str, char, n);
	if ptr == ffi.cast("void*", 0) then return nil end
	return assert(tonumber(ptr - str));
end

return c;

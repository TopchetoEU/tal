local ffi = require "ffi";

local libc = ffi.load "ev";
ffi.cdef [[
void *malloc(size_t n);
void free(void *ptr);

void strlen(const char *ptr);
void strnlen(const char *ptr, size_t max);
]];

local c = {};

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

return c;

local ffi = require "ffi";

local libc = ffi.load "ev";
ffi.cdef [[
void *malloc(size_t n);
void free(void *ptr);
]];

local c = {};

function c.malloc(n)
	return libc.malloc(n);
end
function c.malloc_gc(n)
	return ffi.gc(c.malloc(n), c.free);
end
function c.free(ptr)
	return libc.free(ptr);
end

return c;

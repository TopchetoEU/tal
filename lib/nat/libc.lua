local ffi = require "ffi";

local libc = ffi.load "ev";
ffi.cdef [[
void *malloc(size_t n);
void free(void *ptr);
]];

local c = {};

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

return c;

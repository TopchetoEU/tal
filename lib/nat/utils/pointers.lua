local ffi = require "ffi";

--- @type table<integer, any>
local map = {};

local pointers = {};

--- @generic T
--- @param ptr ffi.cdata* | integer
--- @param wrapper T
--- @return T
function pointers.reg(ptr, wrapper)
	-- NOTE: this will work on current machines with 48-bit addressing,
	-- but on machines with 61 or higher bit addressing, this will fail
	-- I wouldn't worry about that tho...

	local id = assert(tonumber(ffi.cast("size_t", ptr)));
	map[id] = wrapper;
	return wrapper;
end
--- @return any
function pointers.get(ptr)
	local id = assert(tonumber(ffi.cast("size_t", ptr)));
	return map[id];
end

return pointers;

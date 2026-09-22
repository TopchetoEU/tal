local str = require "std.str";
local buffer = require "string.buffer";
local ffi = require "nat.ffi";

--- @class std.str.mem: std.str
--- @field data string.buffer
local mem = setmetatable({}, str);
mem.__index = mem;
mem.__metatable = "std.str.mem";

function mem:_read(ptr, n)
	if n > #self.data then n = #self.data end
	ffi.copy(ptr, self.data, n);
	self.data:skip(n);
	return n;
end
function mem:_write(ptr, n)
	self.data:putcdata(ptr, n);
	return n;
end

function mem.new()
	return setmetatable({ data = buffer.new() }, mem);
end

return mem;

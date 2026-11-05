local libposix = require "nat.libposix";
local libc = require "nat.libc";
local ffi = require "nat.ffi";

--- @class impl.unix.iterenv: impl.iterenv
--- @field ptr ffi.cdata*
--- @field closed boolean
local unix_iterenv = {};
unix_iterenv.__index = unix_iterenv;
unix_iterenv.__metatable = "impl.unix.iterenv";

function unix_iterenv:next()
	if self.closed then return nil end

	local pair = self.ptr[0];
	if pair ~= libc.NULL then
		self.ptr = self.ptr + 1;
	end

	return ffi.string(pair);
end

return function ()
	return setmetatable({
		ptr = libposix.environ(),
		closed = false,
	}, unix_iterenv);
end

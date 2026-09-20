local ffi = require "ffi";
local libc = require "nat.libc";

if ffi.os == "Windows" then
	return function (prompt)
		if prompt then io.stderr:write(prompt) end
		return io.stdin:read "l";
	end
end

local libreadline = ffi.load "edit";

ffi.cdef [[
	char *readline(const char *prompt);
	void add_history(const char *line);
]];

--- @param prompt? string
return function (prompt)
	local ptr = libreadline.readline(prompt or libc.NULL);
	if ptr == libc.NULL then return nil end

	local res = ffi.string(ptr);
	libreadline.add_history(ptr);
	libc.free(ptr);
	return res;
end

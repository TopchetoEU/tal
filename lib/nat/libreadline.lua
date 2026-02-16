local ffi = require "ffi";

if ffi.os == "Windows" then
	return function (prompt)
		if prompt then io.stderr:write(prompt) end
		return io.stdin:read "l";
	end
end

local readline = ffi.load "edit";
local c = ffi.C;

ffi.cdef [[void free(void *ptr)]];
ffi.cdef [[
	char *readline(const char *prompt);
	void add_history(const char *line);
]];

--- @param prompt? string
return function (prompt)
	local ptr = readline.readline(prompt or 0);
	if ptr == 0 then return nil end

	local res = ffi.string(ptr);
	readline.add_history(ptr);
	c.free(ptr);
	return res;
end

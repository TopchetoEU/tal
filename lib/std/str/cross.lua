local str = require "std.str";

--- @class std.str.cross: std.str
--- @field _r std.str
--- @field _w std.str
local cross = setmetatable({}, str);
cross.__index = cross;
cross.__metatable = "std.str.cross";

function cross:_read(ptr, n)
	return self._r:_read(ptr, n);
end
function cross:_readto(dst)
	return self._r:_readto(dst);
end
function cross:_readtext()
	return self._r:_readtext();
end

function cross:_write(ptr, n)
	return self._r:_write(ptr, n);
end
function cross:_writetext(data)
	return self._r:_writetext(data);
end

function cross:_chmod(...)
	self._r:chmod(...);
	self._w:chmod(...);
end
function cross:_chown(uid, gid)
	self._r:chmod(uid, gid);
	self._w:chmod(uid, gid);
end
function cross:_flush()
	self._r:flush();
	self._w:flush();
end
function cross:_close()
	self._r:close();
	self._w:close();
end

--- @param r std.str
--- @param w std.str
function cross.new(r, w)
	local res = setmetatable({ _r = r, _w = w }, cross);

	-- A bit of a hack, still will work tho
	if not r._read then res._read = false end
	if not r._readtext then res._readtext = false end
	if not r._readto then res._readto = false end
	if not r._write then res._write = false end
	if not r._writetext then res._writetext = false end

	return res;
end

return cross;

local str = require "std.io.str";
local loop= require "std.loop";

--- @class std.io.implstr: std.str
--- @field _backend _impl.fd
--- @field _closed boolean
local implstr = setmetatable({}, str);
implstr.__index = implstr;
implstr.__metatable = "std.io.implstr";

function implstr:read(ptr, n)
	if self._closed then ierror "closed" end
	return loop.sync_ret(self._backend:read(coroutine.running(), ptr, n));
end
function implstr:write(ptr, n)
	if self._closed then ierror "closed" end
	return loop.sync_ret(self._backend:write(coroutine.running(), ptr, n));
end
function implstr:flush()
	if self._closed then ierror "closed" end
	return loop.sync_ret(self._backend:flush((coroutine.running())));
end
function implstr:stat()
	if self._closed then ierror "closed" end
	return loop.sync_ret(self._backend:stat((coroutine.running())));
end
function implstr:close()
	if not self._closed then
		self._backend:close();
		self._closed = true;
	end

	return true;
end

--- @param fd _impl.fd
function implstr.new(fd)
	return setmetatable({ _backend = fd, _closed = false }, implstr);
end

return implstr;

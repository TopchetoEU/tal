local str = require "std.str";
local loop = require "std.loop";

--- @class std.os.fs.impl.str: std.str
--- @field _backend _impl.fd
--- @field _closed boolean
local str_impl = setmetatable({}, str);
str_impl.__index = str_impl;
str_impl.__metatable = "std.os.fs.impl.str";

function str_impl:read(ptr, n)
	if self._closed then ierror "closed" end
	return loop.sync_ret(self._backend:read(coroutine.running(), ptr, n));
end
function str_impl:write(ptr, n)
	if self._closed then ierror "closed" end
	return loop.sync_ret(self._backend:write(coroutine.running(), ptr, n));
end
function str_impl:flush()
	if self._closed then ierror "closed" end
	-- return loop.sync_ret(self._backend:flush((coroutine.running())));
	return self;
end
function str_impl:stat()
	if self._closed then ierror "closed" end
	return loop.sync_ret(self._backend:stat((coroutine.running())));
end
function str_impl:close()
	if not self._closed then
		self._backend:close();
		self._closed = true;
	end

	return true;
end

--- @param fd _impl.fd
function str_impl.new(fd)
	return setmetatable({ _backend = fd, _closed = false }, str_impl);
end

return str_impl;

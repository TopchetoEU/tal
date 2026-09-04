local str = require "std.io.str";
local loop= require "std.loop";

--- @class std.io.implfile: std.file
--- @field _backend _impl.fd
--- @field _closed boolean
--- @field _noseek boolean
--- @field _ptr integer
local implfile = setmetatable({}, str);
implfile.__index = implfile;
implfile.__metatable = "std.io.implfile";

function implfile:read(ptr, n)
	if self._closed then ierror "closed" end

	if self._noseek then
		return loop.sync_ret(self._backend:read(coroutine.running(), ptr, n));
	end

	local read_n = loop.sync_ret(self._backend:pread(coroutine.running(), self._ptr, ptr, n));
	self.ptr = self.ptr + read_n;
	return read_n;
end
function implfile:write(ptr, n)
	if self._closed then ierror "closed" end

	if self._noseek then
		return loop.sync_ret(self._backend:read(coroutine.running(), ptr, n));
	end

	local write_n = loop.sync_ret(self._backend:pwrite(coroutine.running(), self._ptr, ptr, n));
	self.ptr = self.ptr + write_n;
	return write_n;
end

function implfile:flush()
	if self._closed then ierror "closed" end
	return loop.sync_ret(self._backend:flush((coroutine.running())));
end
function implfile:stat()
	if self._closed then ierror "closed" end
	return loop.sync_ret(self._backend:stat((coroutine.running())));
end

function implfile:seek(offset, whence)
	if self._closed then ierror "closed" end
	if self._noseek then ierror "operation not supported" end

	if whence == "set" then
		self.ptr = offset;
	elseif whence == "cur" then
		self.ptr = self.ptr + offset;
	elseif whence == "end" then
		local stat = loop.sync_ret(self._backend:stat(coroutine.running()));
		self.ptr = self.ptr + stat.size;
	end

	if self.ptr < 0 then self.ptr = 0 end

	return self.ptr;
end
function implfile:chmod(...)
	if self._closed then return true, nil, "closed" end
	return loop.sync_ret(self._backend:chmod(coroutine.running(), str.parsechmod(...)));
end
function implfile:chown(uid, gid)
	if self._closed then return true, nil, "closed" end
	return loop.sync_ret(self._backend:chown(coroutine.running(), uid, gid));
end

function implfile:close()
	if not self._closed then
		self._backend:close();
		self._closed = true;
	end

	return true;
end

function implfile:to_buff()
	return str.file.buff.new(self, self._noseek);
end

--- @param fd _impl.fd
--- @param noseek boolean
function implfile.new(fd, noseek)
	return setmetatable({ _backend = fd, _closed = false, _noseek = noseek }, implfile);
end

return implfile;

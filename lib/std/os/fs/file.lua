local str = require "std.str";
local loop = require "std.loop";

--- @class std.os.fs.impl.file: std.file
--- @field _backend _impl.fd
--- @field _closed boolean
--- @field _noseek boolean
--- @field _ptr integer
local file_impl = setmetatable({}, str);
file_impl.__index = file_impl;
file_impl.__metatable = "std.os.fs.impl.file";

function file_impl:read(ptr, n)
	if self._closed then ierror "closed" end

	if self._noseek then
		return loop.sync_ret(self._backend:read(coroutine.running(), ptr, n));
	end

	local read_n = loop.sync_ret(self._backend:pread(coroutine.running(), self._ptr, ptr, n));
	self.ptr = self.ptr + read_n;
	return read_n;
end
function file_impl:write(ptr, n)
	if self._closed then ierror "closed" end

	if self._noseek then
		return loop.sync_ret(self._backend:read(coroutine.running(), ptr, n));
	end

	local write_n = loop.sync_ret(self._backend:pwrite(coroutine.running(), self._ptr, ptr, n));
	self.ptr = self.ptr + write_n;
	return write_n;
end

function file_impl:flush()
	if self._closed then ierror "closed" end
	return loop.sync_ret(self._backend:flush((coroutine.running())));
end
function file_impl:stat()
	if self._closed then ierror "closed" end
	return loop.sync_ret(self._backend:stat((coroutine.running())));
end

function file_impl:seek(offset, whence)
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
function file_impl:chmod(...)
	if self._closed then return true, nil, "closed" end
	return loop.sync_ret(self._backend:chmod(coroutine.running(), str.parsechmod(...)));
end
function file_impl:chown(uid, gid)
	if self._closed then return true, nil, "closed" end
	return loop.sync_ret(self._backend:chown(coroutine.running(), uid, gid));
end

function file_impl:close()
	if not self._closed then
		self._backend:close();
		self._closed = true;
	end

	return true;
end

function file_impl:to_buff()
	return str.file.buff.new(self, self._noseek);
end

--- @param fd _impl.fd
--- @param noseek boolean
function file_impl.new(fd, noseek)
	return setmetatable({ _backend = fd, _closed = false, _noseek = noseek }, file_impl);
end

return file_impl;

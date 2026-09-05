local str = require "std.str";
local loop = require "std.loop";

--- @class std.os.fs.impl.file: std.str
--- @field _backend _impl.fd
--- @field _closed boolean
--- @field _ptr integer
local file_impl = setmetatable({}, str);
file_impl.__index = file_impl;
file_impl.__metatable = "std.os.fs.impl.file";

function file_impl:_read(ptr, n)
	if not self._seek then
		return loop.sync_ret(self._backend:read(coroutine.running(), ptr, n));
	end

	local read_n = loop.sync_ret(self._backend:pread(coroutine.running(), self._ptr, ptr, n));
	self._ptr = self._ptr + read_n;
	return read_n;
end
function file_impl:_write(ptr, n)
	if not self._seek then
		return loop.sync_ret(self._backend:write(coroutine.running(), ptr, n));
	end

	local write_n = loop.sync_ret(self._backend:pwrite(coroutine.running(), self._ptr, ptr, n));
	self._ptr = self._ptr + write_n;
	return write_n;
end

function file_impl:_flush() end
function file_impl:_stat()
	return loop.sync_ret(self._backend:stat((coroutine.running())));
end

function file_impl:_chmod(mode)
	return loop.sync_ret(self._backend:chmod(coroutine.running(), mode));
end
function file_impl:_chown(uid, gid)
	return loop.sync_ret(self._backend:chown(coroutine.running(), uid, gid));
end

function file_impl:_close()
	self._backend:close();
	self._closed = true;
	return true;
end

--- @class std.os.fs.impl.file
local file_seek_impl = setmetatable({}, file_impl);
file_seek_impl.__index = file_seek_impl;
file_seek_impl.__metatable = "std.os.fs.impl.file";

function file_seek_impl:_seek(whence, offset)
	whence = whence or "cur";
	offset = offset or 0;

	if not self._seek then ierror "operation not supported" end

	if whence == "set" then
		self._ptr = offset;
	elseif whence == "cur" then
		self._ptr = self._ptr + offset;
	elseif whence == "end" then
		local stat = loop.sync_ret(self._backend:stat(coroutine.running()));
		self._ptr = self._ptr + stat.size;
	end

	if self._ptr < 0 then self._ptr = 0 end

	return self._ptr;
end

--- @param fd _impl.fd
--- @param noseek boolean
function file_impl.new(fd, noseek)
	return setmetatable({ _backend = fd, _closed = false, _ptr = 0 }, noseek and file_impl or file_seek_impl);
end

return file_impl;

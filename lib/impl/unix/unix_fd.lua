local sig = require "std.sig";
local libyaooi = require "nat.libyaooi";

--- @class impl.unix.fd: impl.fd
--- @field impl impl.unix
--- @field fd integer
--- @field closed boolean
local unix_fd = {};
unix_fd.__index = unix_fd;
unix_fd.__metatable = "impl.unix.fd";

function unix_fd:pread(udata, offset, buff, n)
	n = sig.optnum(n, "n");
	if self.closed then return true, nil, "file is closed" end
	return self.fd:pread(libyaooi.req.new(self.queue, udata), offset, buff, n);
end
function unix_fd:pwrite(udata, offset, buff, n)
	n = sig.optnum(n, "n");
	if self.closed then return true, nil, "file is closed" end
	return self.fd:pwrite(libyaooi.req.new(self.queue, udata), offset, buff, n);
end
function unix_fd:read(udata, buff, n)
	n = sig.optnum(n, "n");
	if self.closed then return true, nil, "handle is closed" end
	return self.fd:read(libyaooi.req.new(self.queue, udata), buff, n);
end
function unix_fd:write(udata, buff, n)
	n = sig.optnum(n, "n");
	if self.closed then return true, nil, "handle is closed" end
	return self.fd:write(libyaooi.req.new(self.queue, udata), buff, n);
end
function unix_fd:flush(udata)
	if self.closed then return true, nil, "handle is closed" end
	return self.fd:sync(libyaooi.req.new(self.queue, udata));
end
function unix_fd:stat(udata)
	if self.closed then return true, nil, "handle is closed" end
	return self.fd:stat(libyaooi.req.new(self.queue, udata));
end
function unix_fd:chmod(udata, mode)
	if self.closed then return true, nil, "handle is closed" end
	return self.fd:chmod(libyaooi.req.new(self.queue, udata), mode);
end
function unix_fd:chown(udata, uid, gid)
	if self.closed then return true, nil, "handle is closed" end
	return self.fd:chown(libyaooi.req.new(self.queue, udata), uid, gid);
end

function unix_fd:close()
	if self.closed then return end
	self.fd:close();
	self.closed = true;
end

--- @param impl impl.unix
--- @param fd integer
return function (impl, fd)
	return setmetatable({
		fd = fd,
		impl = impl,
		closed = false,
	}, unix_fd);
end

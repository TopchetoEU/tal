local sig = require "std.sig";
local libyaooi = require "nat.libyaooi";

--- @class impl.libyaooi.fd: _impl.fd, _impl.fd
--- @field queue libyaooi.queue
--- @field fd libyaooi.fd
--- @field closed boolean
local yo_fd = {};
yo_fd.__index = yo_fd;
yo_fd.__metatable = "impl.libyaooi.fd";

function yo_fd:pread(udata, offset, buff, n)
	n = sig.optnum(n, "n");
	if self.closed then return true, nil, "file is closed" end
	return self.fd:pread(libyaooi.req.new(self.queue, udata), offset, buff, n);
end
function yo_fd:pwrite(udata, offset, buff, n)
	n = sig.optnum(n, "n");
	if self.closed then return true, nil, "file is closed" end
	return self.fd:pwrite(libyaooi.req.new(self.queue, udata), offset, buff, n);
end
function yo_fd:read(udata, buff, n)
	n = sig.optnum(n, "n");
	if self.closed then return true, nil, "handle is closed" end
	return self.fd:read(libyaooi.req.new(self.queue, udata), buff, n);
end
function yo_fd:write(udata, buff, n)
	n = sig.optnum(n, "n");
	if self.closed then return true, nil, "handle is closed" end
	return self.fd:write(libyaooi.req.new(self.queue, udata), buff, n);
end
function yo_fd:flush(udata)
	if self.closed then return true, nil, "handle is closed" end
	return self.fd:sync(libyaooi.req.new(self.queue, udata));
end
function yo_fd:stat(udata)
	if self.closed then return true, nil, "handle is closed" end
	return self.fd:stat(libyaooi.req.new(self.queue, udata));
end
function yo_fd:close()
	if self.closed then return end
	self.fd:close();
	self.closed = true;
end

--- @param queue libyaooi.queue
--- @param fd libyaooi.fd
return function (queue, fd)
	return setmetatable({
		fd = fd,
		queue = queue,
		closed = false,
	}, yo_fd);
end

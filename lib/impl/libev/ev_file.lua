local sig = require "std.sig";

--- @class _impl.ev.file_data
--- @field fd ev.file
--- @field ev ev
--- @field closed boolean

--- @class impl.ev_file: _impl.file
--- @field ev ev
--- @field fd ev.file
--- @field closed boolean
local ev_file = {};
ev_file.__index = ev_file;
ev_file.__metatable = "impl.ev_file";

function ev_file:read(udata, offset, buff, n)
	n = sig.optnum(n, "n");
	if self.closed then return true, nil, "file is closed" end

	return self.ev:file_read(udata, self.fd, offset, n, buff);
end
function ev_file:write(udata, offset, buff, n)
	n = sig.optnum(n, "n");
	if self.closed then return true, nil, "file is closed" end

	return self.ev:file_write(udata, self.fd, offset, n, buff);
end
function ev_file:flush(udata)
	return self.ev:sync(udata, self.fd);
end
function ev_file:stat(udata)
	if self.closed then return true, nil, "file is closed" end
	return self.ev:stat(udata, self.fd);
end
function ev_file:chmod(udata, mode)
	if self.closed then return true, nil, "file is closed" end
	return self.ev:file_chmod(udata, self.fd, mode);
end
function ev_file:chown(udata, uid, gid)
	if self.closed then return true, nil, "file is closed" end
	return self.ev:file_chown(udata, self.fd, uid, gid);
end
function ev_file:close()
	if self.closed then return end
	self.ev:close(self.fd);
	self.closed = true;
end

--- @param ev ev
--- @param fd ev.file
return function (ev, fd)
	return setmetatable({
		ev = ev,
		fd = fd,
		closed = false,
		offset = 0,
	}, ev_file);
end

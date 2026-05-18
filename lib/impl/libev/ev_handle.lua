local sig = require "std.sig";

--- @class _impl.ev.handle_data
--- @field fd ev.handle
--- @field ev ev
--- @field closed boolean

--- @class impl.ev_handle: _impl.stream
--- @field ev ev
--- @field fd ev.file
--- @field closed boolean
local ev_handle = {};
ev_handle.__index = ev_handle;
ev_handle.__metatable = "impl.ev_handle";

function ev_handle:read(udata, buff, n)
	n = sig.optnum(n, "n");
	if self.closed then return true, nil, "handle is closed" end

	return self.ev:read(udata, self.fd, n, buff);
end
function ev_handle:write(udata, buff, n)
	n = sig.optnum(n, "n");
	if self.closed then return true, nil, "handle is closed" end

	return self.ev:write(udata, self.fd, n, buff);
end
function ev_handle:flush(udata)
	return self.ev:sync(udata, self.fd);
end
function ev_handle:stat(udata)
	if self.closed then return true, nil, "handle is closed" end
	return self.ev:stat(udata, self.fd);
end
function ev_handle:close()
	if self.closed then return end
	self.ev:close(self.fd);
	self.closed = true;
end

--- @param ev ev
--- @param fd ev.handle
return function (ev, fd)
	return setmetatable({
		fd = fd,
		ev = ev,
		closed = false,
	}, ev_handle);
end

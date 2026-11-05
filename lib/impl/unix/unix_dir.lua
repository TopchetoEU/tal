local libyaooi = require "nat.libyaooi";

--- @class impl.unix.dir: impl.dir
--- @field impl impl.unix
--- @field closed boolean
--- @field fd ffi.cdata*
local yo_dir = {};
yo_dir.__index = yo_dir;
yo_dir.__metatable = "impl.unix.dir";

function yo_dir:next(udata)
	if self.closed then return "closed" end
	return self.fd:next(libyaooi.req.new(self.queue, udata));
end
function yo_dir:close()
	if self.closed then return end
	self.fd:close();
	self.closed = true;
end

--- @param impl impl.unix
--- @param fd ffi.cdata*
return function (impl, fd)
	return setmetatable({
		impl = impl,
		fd = fd,
		closed = false,
	}, yo_dir);
end

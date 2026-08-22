local libyaooi = require "nat.libyaooi";

--- @class impl.libyaooi.dir: _impl.dir
--- @field queue libyaooi.queue
--- @field closed boolean
--- @field fd libyaooi.dir
local yo_dir = {};
yo_dir.__index = yo_dir;
yo_dir.__metatable = "impl.libyaooi.dir";

function yo_dir:next(udata)
	if self.closed then return "closed" end
	return self.fd:next(libyaooi.req.new(self.queue, udata));
end
function yo_dir:close()
	if self.closed then return end
	self.fd:close();
	self.closed = true;
end

--- @param queue libyaooi.queue
--- @param fd libyaooi.dir
return function (queue, fd)
	return setmetatable({
		queue = queue,
		fd = fd,
		closed = false,
	}, yo_dir);
end

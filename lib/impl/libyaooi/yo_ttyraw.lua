local libyaooi = require "nat.libyaooi";

--- @class impl.libyaooi.ttyraw: impl.ttyraw
--- @field closed boolean
--- @field fd nat.libyaooi.tty_raw
local yo_ttyraw = {};
yo_ttyraw.__index = yo_ttyraw;
yo_ttyraw.__metatable = "impl.libyaooi.ttyraw";

function yo_ttyraw:close()
	if self.closed then return end
	self.fd:close();
	self.closed = true;
end

--- @param queue nat.libyaooi.queue
--- @param fd nat.libyaooi.fd
return function (queue, fd)
	return setmetatable({
		queue = queue,
		fd = libyaooi.tty_raw.new(fd),
		closed = false,
	}, yo_ttyraw);
end

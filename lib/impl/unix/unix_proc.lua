local libyaooi = require "nat.libyaooi";

--- @class impl.libyaooi.proc: impl.process
--- @field queue nat.libyaooi.queue
--- @field fd nat.libyaooi.proc
--- @field closed boolean
local yo_proc = {};
yo_proc.__index = yo_proc;
yo_proc.__metatable = "impl.libyaooi.proc";

function yo_proc:wait(udata)
	if self.closed then return "closed" end
	return (function (...)
		if ... then self.closed = true end
		return ...;
	end)(self.fd:wait(libyaooi.req.new(self.queue, udata)));
end
function yo_proc:disown()
	if self.closed then return "closed" end
	self.fd:disown();
	self.closed = true;
	return true;
end
--- @param queue nat.libyaooi.queue
--- @param fd nat.libyaooi.proc
return function (queue, fd)
	return setmetatable({
		queue = queue,
		fd = fd,
		closed = false,
	}, yo_proc);
end

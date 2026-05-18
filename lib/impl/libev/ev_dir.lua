--- @class _impl.dir_data
--- @field ev ev
--- @field fd ev.dir
--- @field closed boolean

--- @class impl.ev_dir: _impl.dir
--- @field closed boolean
--- @field ev ev
--- @field fd ev.dir
local ev_dir = {};
ev_dir.__index = ev_dir;
ev_dir.__metatable = "impl.ev_dir";

function ev_dir:next(udata)
	if self.closed then return "closed" end
	return self.ev:dir_next(udata, self.fd);
end
function ev_dir:close()
	if self.closed then return end
	self.ev:dir_close(self.fd);
	self.closed = true;
end

--- @param ev ev
--- @param fd ev.dir
return function (ev, fd)
	return setmetatable({
		ev = ev,
		fd = fd,
		closed = false,
	}, ev_dir);
end

--- @class impl.libyaooi.iterenv: _impl.iterenv
--- @field fd impl.libyaooi.iterenv
--- @field closed boolean
local yo_iterenv = {};
yo_iterenv.__index = yo_iterenv;
yo_iterenv.__metatable = "impl.libyaooi.iterenv";

function yo_iterenv:next()
	if self.closed then return nil end
	return self.fd:next();
end
function yo_iterenv:close()
	if self.closed then return end
	self.fd:close();
	self.closed = true;
end

--- @param fd libyaooi.enviter
return function (fd)
	return setmetatable({
		fd = fd,
		closed = false,
	}, yo_iterenv);
end

--- @class impl.libyaooi.iterenv: _impl.iterenv
--- @field fd libyaooi.enviter
--- @field closed boolean
local yo_iterenv = {};
yo_iterenv.__index = yo_iterenv;
yo_iterenv.__metatable = "impl.libyaooi.iterenv";

function yo_iterenv:next()
	if self.closed then return nil end
	return self.fd:next();
end

--- @param fd libyaooi.enviter
return function (fd)
	return setmetatable({
		fd = fd,
		closed = false,
	}, yo_iterenv);
end

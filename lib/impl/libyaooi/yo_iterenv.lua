--- @class impl.libyaooi.iterenv: impl.iterenv
--- @field fd nat.libyaooi.enviter
--- @field closed boolean
local yo_iterenv = {};
yo_iterenv.__index = yo_iterenv;
yo_iterenv.__metatable = "impl.libyaooi.iterenv";

function yo_iterenv:next()
	if self.closed then return nil end
	return self.fd:next();
end

--- @param fd nat.libyaooi.enviter
return function (fd)
	return setmetatable({
		fd = fd,
		closed = false,
	}, yo_iterenv);
end

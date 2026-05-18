local ffi = require "ffi";

--- @class impl.ev_iterenv: _impl.iterenv
--- @field ev ev
--- @field fd ffi.cdata*
--- @field closed boolean
local ev_iterenv = {};
ev_iterenv.__index = ev_iterenv;
ev_iterenv.__metatable = "impl.ev_iterenv";

function ev_iterenv:next()
	if self.closed then return nil end
	return self.ev.nextenv(self.fd);
end
function ev_iterenv:close()
	if self.closed then return end
	-- TODO: add function in libev to close an ongoing env iteration. Currently, it just leaks
	-- self_data.ev:iterenv_close(self_data.fd);
	self.closed = true;
end

return function (ev)
	return setmetatable({
		ev = ev,
		fd = ffi.new("void*[1]"),
		closed = false,
	}, ev_iterenv);
end

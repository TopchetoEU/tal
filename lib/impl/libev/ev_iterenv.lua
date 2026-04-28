local ffi = require "ffi";

--- @class _impl.iterenv_data
--- @field ev ev
--- @field fd ffi.cdata*
--- @field closed boolean

--- @type _impl.iterenv
local iterenv_index = {};
function iterenv_index:next()
	local self_data = debug.getuservalue(self) --[[@as _impl.iterenv_data]];

	if self_data.closed then return nil end
	return self_data.ev.nextenv(self_data.fd);
end
function iterenv_index:close()
	local self_data = debug.getuservalue(self) --[[@as _impl.iterenv_data]];

	if self_data.closed then return end
	-- TODO: add function in libev to close an ongoing env iteration. Currently, it just leaks
	-- self_data.ev:iterenv_close(self_data.fd);
	self_data.closed = true;
end

local iterenv_identity = newproxy(true);
local iterenv_meta = getmetatable(iterenv_identity);
iterenv_meta.__index = iterenv_index;
iterenv_meta.__gc = iterenv_index.close;

return function (ev)
	return debug.setuservalue(newproxy(iterenv_identity), {
		ev = ev,
		fd = ffi.new("void*[1]"),
		closed = false,
	});
end

local sig = require "std.sig";

--- @class _impl.ev.handle_data
--- @field fd ev.handle
--- @field ev ev
--- @field closed boolean

--- @type _impl.stream
--- @diagnostic disable-next-line: missing-fields
local stream_index = {};
function stream_index:read(udata, buff, n)
	n = sig.optnum(n, "n");
	local self_data = debug.getuservalue(self) --[[@as _impl.ev.handle_data]];

	if self_data.closed then return true, nil, "handle is closed" end

	return self_data.ev:read(udata, self_data.fd, n, buff);
end
function stream_index:write(udata, buff, n)
	n = sig.optnum(n, "n");
	local self_data = debug.getuservalue(self) --[[@as _impl.ev.handle_data]];

	if self_data.closed then return true, nil, "handle is closed" end

	return self_data.ev:write(udata, self_data.fd, n, buff);
end
function stream_index:flush(udata)
	local self_data = debug.getuservalue(self) --[[@as _impl.ev.handle_data]];
	return self_data.ev:sync(udata, self_data.fd);
end
function stream_index:stat(udata)
	local self_data = debug.getuservalue(self) --[[@as _impl.ev.handle_data]];
	if self_data.closed then return true, nil, "handle is closed" end

	return self_data.ev:stat(udata, self_data.fd);
end
function stream_index:close()
	local self_data = debug.getuservalue(self) --[[@as _impl.ev.handle_data]];
	if self_data.closed then return end
	self_data.ev:close(self_data.fd);
	self_data.closed = true;
end

local handle_identity = newproxy(true);
local handle_meta = getmetatable(handle_identity);
handle_meta.__index = stream_index;

--- @return _impl.stream
return function (ev, fd)
	return debug.setuservalue(newproxy(handle_identity), {
		fd = fd,
		ev = ev,
		closed = false,
		offset = 0,
	});
end

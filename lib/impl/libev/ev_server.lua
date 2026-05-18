local ev_handle = require "impl.libev.ev_handle";
local process_args = require "impl.libev.process_args";

--- @class _impl.server_data

--- @class impl.ev_server: _impl.server
--- @field ev ev
--- @field fd ev.server
--- @field closed boolean
local ev_server = {};
ev_server.__index = ev_server;
ev_server.__metatable = "impl.ev_server";

function ev_server:next(udata)
	if self.closed then return true, nil, "closed" end

	return self.ev:server_accept(process_args.wrap_udata(udata, function (f, err)
		if f then
			f.client = ev_handle(self.ev, f.client --[[@as ev.handle]]);
			return f;
		end
		return f, err;
	end), self.fd);
end
function ev_server:close()
	if self.closed then return end
	self.ev:server_close(self.fd);
	self.closed = true;
end

--- @param ev ev
--- @param fd ev.server
--- @return _impl.server
return function (ev, fd)
	return setmetatable({
		ev = ev,
		fd = fd,
		closed = false,
	}, ev_server);
end

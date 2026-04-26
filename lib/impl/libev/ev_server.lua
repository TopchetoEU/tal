local ev_handle = require "impl.libev.ev_handle";
local process_args = require "impl.libev.process_args";

--- @class _impl.server_data
--- @field ev ev
--- @field fd ev.server
--- @field closed boolean

--- @type _impl.server
local server_index = {};
function server_index:next(udata)
	local self_data = debug.getuservalue(self) --[[@as _impl.server_data]];

	if self_data.closed then return true, nil, "closed" end

	return self_data.ev:server_accept(process_args.wrap_udata(udata, function (f, err)
		if f then
			f.client = ev_handle(self_data.ev, f.client);
			return f;
		end
		return f, err;
	end), self_data.fd);
end
function server_index:close()
	local self_data = debug.getuservalue(self) --[[@as _impl.server_data]];

	if self_data.closed then return end
	self_data.ev:server_close(self_data.fd);
	self_data.closed = true;
end

local server_identity = newproxy(true);
local server_meta = getmetatable(server_identity);
server_meta.__index = server_index;
server_meta.__gc = server_index.close;

--- @return _impl.server
return function (ev, server)
	return debug.setuservalue(newproxy(server_identity), {
		ev = ev,
		fd = server,
		closed = false,
	});
end

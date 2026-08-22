local process_args = require "impl.process_args";
local libyaooi = require "nat.libyaooi";
local yo_fd = require "impl.libyaooi.yo_fd";

--- @class _impl.server_data

--- @class impl.libyaooi.server: _impl.server
--- @field queue libyaooi.queue
--- @field fd libyaooi.fd
--- @field closed boolean
local yo_server = {};
yo_server.__index = yo_server;
yo_server.__metatable = "impl.libyaooi.server";

function yo_server:next(udata)
	if self.closed then return true, nil, "closed" end

	return libyaooi.socket_accept(libyaooi.req.new(self.queue, process_args.wrap_udata(udata, function (client, ip, port)
		return yo_fd(self.queue, client), ip, port;
	end)), self.fd);
end
function yo_server:close()
	if self.closed then return end
	self.fd:close();
	self.closed = true;
end

--- @param queue libyaooi.queue
--- @param fd libyaooi.fd
return function (queue, fd)
	return setmetatable({
		queue = queue,
		fd = fd,
		closed = false,
	}, yo_server);
end

local prop = require "std.field";
local loop = require "tal.loop";
local net = {};

--- @alias std.net.addrinfo_flags string
--- |+ "4" EV_AI_IPV4
--- |+ "6" EV_AI_IPV6
--- |+ "m" EV_AI_IPV4_MAPPED
--- |+ "b" EV_AI_BIND
--- |+ "n" EV_AI_NODNS

local sock_fd = prop();
local sock_closed = prop();

--- @class std.io.net.socket: userdata
local sock_index = {};
--- @param n integer
function sock_index:read(n)
	if sock_closed:get(self) then return nil, "file is closed" end
	return loop.curr.ev:srecv(sock_fd:get(self), n);
end
--- @param data string
function sock_index:write(data)
	if sock_closed:get(self) then return nil, "file is closed" end
	return loop.curr.ev:ssend(sock_fd:get(self), data);
end
function sock_index:close()
	if sock_closed:get(self) or sock_fd:get(self) == nil then return end
	loop.curr.ev:closesock(sock_fd:get(self));
	sock_closed:set(self, true);
end

local sock_identity = newproxy(true);
local sock_meta = getmetatable(sock_identity);
sock_meta.__index = sock_index;
sock_meta.__gc = sock_index.close;

local server_fd = prop();
local server_closed = prop();

--- @class std.io.net.server: userdata
local server_index = {};
--- @return std.io.net.socket?
--- @return string? err
function server_index:accept()
	if server_closed:get(self) then return nil end

	local sock, err = loop.curr.ev:saccept(server_fd:get(self));
	if not sock then return nil, err end

	local res = newproxy(sock_identity);
	sock_fd:set(res, sock);
	sock_closed:set(res, false);

	return res;
end
function server_index:close()
	if server_closed:get(self) or server_fd:get(self) == nil then return nil end
	loop.curr.ev:closesock(server_fd:get(self));
	server_closed:set(self, true);
end

local server_identity = newproxy(true);
local server_meta = getmetatable(server_identity);
server_meta.__index = server_index;
server_meta.__gc = server_index.close;

--- @param addr string
--- @param port integer
--- @param protocol? "tcp" | "udp"
--- @return std.io.net.socket?
--- @return string? err
function net.connect(addr, port, protocol)
	local sock, err = loop.curr.ev:sconnect(addr, port, protocol);
	if not sock then return nil, err end

	local self = newproxy(sock_identity);
	sock_fd:set(self, sock);
	sock_closed:set(self, false);

	return self;
end
--- @param addr string
--- @param port integer
--- @param protocol? "tcp" | "udp" = "tcp"
--- @param max_n? integer = 32
--- @return std.io.net.server?
--- @return string? err
function net.bind(addr, port, protocol, max_n)
	local sock, err = loop.curr.ev:sbind(addr, port, protocol, max_n);
	if not sock then return nil, err end

	local self = newproxy(server_identity);
	server_fd:set(self, sock);
	server_closed:set(self, false);

	return self;
end
--- @param name string
--- @param flags std.net.addrinfo_flags
function net.getaddrinfo(name, flags)
	return loop.curr.ev:sgetaddrinfo(name, flags);
end

return net;

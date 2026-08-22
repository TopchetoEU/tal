local impl = require "impl";
local collected = require "std.collected";
local stream = require "std.io.stream";
local loop = require "std.loop";
local net = {};

--- @alias std.io.net.addrinfo_flags string
--- |+ "4" EV_AI_IPV4
--- |+ "6" EV_AI_IPV6
--- |+ "m" EV_AI_IPV4_MAPPED
--- |+ "b" EV_AI_BIND
--- |+ "n" EV_AI_NODNS

--- @class std.net.server
--- @field _fd _impl.server
--- @field _mngd string | true?
local server = {};
server.__index = server;
server.__metatable = "std.io.net.server";

--- @return std.io.stream client
--- @return string ip
--- @return integer port
function server:next()
	local res, ip, port = loop.sync_ret(self._fd:next((coroutine.running())));
	return stream.from_stream(res, true), ip, port;
end
function server:iter()
	return self.next, self;
end
function server:close()
	self._mngd = nil;
	return self._fd:close();
end

server.__gc = server.close;

--- @param addr string
--- @param port integer
--- @param protocol? "tcp" | "udp" = "tcp"
--- @param max_n? integer = 32
--- @return std.net.server
function net.bind(addr, port, protocol, max_n)
	local f = loop.sync_ret(impl:bind(coroutine.running(), addr, port, protocol or "tcp", max_n or 32));
	return collected(setmetatable({ _fd = f, _mngd = true }, server));
end
--- @param addr string
--- @param port integer
--- @param protocol? "tcp" | "udp" = "tcp"
--- @return std.io.stream
function net.connect(addr, port, protocol)
	local f = loop.sync_ret(impl:connect(coroutine.running(), addr, port, protocol or "tcp"));
	return stream.from_stream(f, true);
end
--- @param name string
--- @param port integer
--- @param protocol? "tcp" | "udp" = "tcp"
--- @param flags? std.io.net.addrinfo_flags
--- @return std.io.stream
function net.nameconnect(name, port, protocol, flags)
	local ips = net.getaddrinfo(name, flags or "");

	local ok, res, err, trace;
	for _, ip in ipairs(ips) do
		ok, res, err, trace = spcall(net.connect, ip, port, protocol);
		if ok then return res end
	end

	if err then
		serror(err, trace);
	else
		ierror "couldn't resolve host";
	end
end
--- @param name string
--- @param flags std.io.net.addrinfo_flags
--- @return string[]
function net.getaddrinfo(name, flags)
	return loop.sync_ret(impl:getaddrinfo(coroutine.running(), name, flags));
end

return net;

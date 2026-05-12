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
local server_index = {};

--- @return std.io.stream client
--- @return string ip
--- @return integer port
function server_index:next()
	local res = iassert(loop.sync_ret(self._fd:next((coroutine.running()))));
	return stream.from_stream(res.client, true), res.ip, res.port;
end
function server_index:iter()
	return self.next, self;
end
function server_index:close()
	self._mngd = nil;
	return self._fd:close();
end

local server_meta = {
	__index = server_index,
	__gc = server_index.close,
};

--- @param addr string
--- @param port integer
--- @param protocol? "tcp" | "udp" = "tcp"
--- @param max_n? integer = 32
--- @return std.net.server
function net.bind(addr, port, protocol, max_n)
	local f = iassert(loop.sync_ret(impl:bind(coroutine.running(), addr, port, protocol or "tcp", max_n or 32)));
	return collected(setmetatable({ _fd = f, _mngd = true }, server_meta));
end
--- @param addr string
--- @param port integer
--- @param protocol? "tcp" | "udp" = "tcp"
--- @return std.io.stream
function net.connect(addr, port, protocol)
	local f = iassert(loop.sync_ret(impl:connect(coroutine.running(), addr, port, protocol or "tcp")));
	return stream.from_stream(f, true);
end
--- @param name string
--- @param flags std.io.net.addrinfo_flags
--- @return string[]
function net.getaddrinfo(name, flags)
	return iassert(loop.sync_ret(impl:getaddrinfo(coroutine.running(), name, flags)));
end

return net;

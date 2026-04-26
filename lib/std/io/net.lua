local impl  = require "impl";
local collected = require "std.collected";
local stream = require "std.io.stream";
local loop = require "std.loop";
local mutex= require "std.sync.mutex"
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

--- @return { client: std.io.stream, ip: string, port: integer }?
--- @return string? err
function server_index:next()
	local res, err = loop.sync_ret(self._fd:next((coroutine.running())));
	if not res then return nil, err end

	res.client = stream.from_stream(res.client);
	return res;
end
function server_index:close()
	self._mngd = nil;
	return self._fd:close();
end

local server_meta = { __index = server_index };
function server_meta:__gc()
	if self._mngd == true then
		print("Warning: server not closed");
	elseif type(self._mngd == "srting") then
		print("Warning: server not closed: " .. self._mngd);
	end
end

--- @param addr string
--- @param port integer
--- @param protocol? "tcp" | "udp" = "tcp"
--- @param max_n? integer = 32
--- @return std.net.server?
--- @return string? err
function net.bind(addr, port, protocol, max_n)
	local f, err = loop.sync_ret(impl:bind(coroutine.running(), addr, port, protocol or "tcp", max_n or 32));
	if err then return nil, err end

	return collected(setmetatable({ _fd = f, _mngd = true }, server_meta));
end
--- @param addr string
--- @param port integer
--- @param protocol? "tcp" | "udp" = "tcp"
--- @return std.io.stream?
--- @return string? err
function net.connect(addr, port, protocol)
	local f, err = loop.sync_ret(impl:connect(coroutine.running(), addr, port, protocol or "tcp"));
	if not f then return nil, err end

	return stream.from_stream(f, true);
end
--- @param name string
--- @param flags std.io.net.addrinfo_flags
--- @return string[]?
--- @return string? err
function net.getaddrinfo(name, flags)
	return loop.sync_ret(impl:getaddrinfo(coroutine.running(), name, flags));
end

return net;

local loop = require "std.loop"
local time = require "std.os.time"
local net  = require "std.os.net"
local ssl  = require "std.proto.ssl"
--- @class std.os.net_pool
--- @field timeout number
--- @field _conns table<string, { conn: std.str, ssl: boolean, timer: fun() }>
--- @field _conns_rev table<std.str, string>
local net_pool = {};
net_pool.__index = net_pool;
net_pool.__metatable = "std.os.net_pool";

--- @param name string
--- @param port integer
--- @param kind? "tcp" | "udp" = "udp"
function net_pool:nameconnect(name, port, kind)
	local literal = name .. "|" .. port .. "|" .. kind;
	if self._conns[literal] then
		self._conns[literal].timer();
	else
		self._conns[literal] = {
			conn = net.nameconnect(name, port, kind),
		};
		self._conns_rev[self._conns[literal].conn] = literal;
	end

	self._conns[literal].timer = loop.wait_until(time.time "mono" + self.timeout, function ()
		self._conns[literal].conn:close();
		self._conns_rev[self._conns[literal].conn] = nil;
		self._conns[literal] = nil;
	end);
	return self._conns[literal].conn;
end
--- @param ip string
--- @param port integer
--- @param kind? "tcp" | "udp" = "udp"
function net_pool:connect(ip, port, kind)
	local literal = ip .. "|" .. port .. "|" .. kind;
	if self._conns[literal] then
		self._conns[literal].timer();
	else
		self._conns[literal] = {
			conn = net.connect(ip, port, kind),
		};
	end

	self._conns[literal].timer = loop.wait_until(time.time "mono" + self.timeout, function ()
		self._conns[literal] = nil;
	end);
	return self._conns[literal].conn;
end

--- @param conn std.str
--- @param host string
function net_pool:ssl_begin(conn, host)
	assert(self._conns_rev[conn], "connection not pooled");
	local literal = self._conns_rev[conn];

	if self._conns[literal].ssl then return conn end
	local old = self._conns[literal].conn;
	local new = ssl.new { backend = old, owned = true, host = host, role = "client" };
	self._conns[literal].conn = new;
	self._conns[literal].ssl = true;

	self._conns_rev[old] = nil;
	self._conns_rev[new] = literal;

	return new;
end

--- @param str std.str
function net_pool:close_conn(str)
	if self._conns_rev[str] then
		local literal = self._conns_rev[str]
		self._conns[literal].timer();
		self._conns[literal].conn:close();
		self._conns[literal] = nil;
		self._conns_rev[str] = nil;
	end
end

--- @param timeout number
function net_pool.new(timeout)
	return setmetatable({
		timeout = timeout,
		_conns = {},
		_conns_rev = {},
	}, net_pool)
end

net_pool.fetch = net_pool.new(10000);

return net_pool;

--- @class ev
local libev = require "nat.libev";

--- @param func fun(self: ev, udata, ...): string?
local function syncify(func)
	return function (self, ...)
		local err = func(self, coroutine.running(), ...);
		if err then return nil, err end
		return coroutine.yield();
	end
end

--- @type fun(self: ev, path: string, flags: std.fs.open_flags, mode?: string | integer): ev.fd?, string?
libev.sopen = syncify(libev.open);
--- @type fun(self: ev, fd: ev.fd): std.fs.stat?, string?
libev.sstat = syncify(libev.stat);
--- @type fun(self: ev, fd: ev.fd, offset: integer, n: integer): string?, string?
libev.sread = syncify(libev.read);
--- @type fun(self: ev, fd: ev.fd, offset: integer, data: string): integer?, string?
libev.swrite = syncify(libev.write);
--- @type fun(self: ev, fd: ev.fd): true?, string?
libev.ssync = syncify(libev.sync);
--- @type fun(self: ev, fd: ev.fd, offset: integer, n: integer, buff: ffi.cdata*): integer?, ffi.cdata* | string?
libev.srawread = syncify(libev.rawread);
--- @type fun(self: ev, fd: ev.fd, offset: integer, n: integer, buff: ffi.cdata*): integer?, ffi.cdata* | string?
libev.srawwrite = syncify(libev.rawwrite);

--- @type fun(self: ev, path: string, mode?: integer | string): true?, string?
libev.smkdir = syncify(libev.mkdir);
--- @type fun(self: ev, path: string): ev.dir?, string?
libev.sopendir = syncify(libev.opendir);
--- @type fun(self: ev, dir: ev.dir): string?, string?
libev.sreaddir = syncify(libev.readdir);

--- @type fun(self: ev, addr: string, port: integer, prot?: "tcp" | "udp"): ev.socket?, string?
libev.sconnect = syncify(libev.connect);
--- @type fun(self: ev, addr: string, port: integer, prot?: "tcp" | "udp", max_n?: integer): ev.socket?, string?
libev.sbind = syncify(libev.bind);
--- @type fun(self: ev, server: ev.socket): ev.socket?, string?, integer?
libev.saccept = syncify(libev.accept);
--- @type fun(self: ev, fd: ev.socket, n: integer): string?, string?
libev.srecv = syncify(libev.recv);
--- @type fun(self: ev, fd: ev.socket, data: string): integer?, string?
libev.ssend = syncify(libev.send);
--- @type fun(self: ev, fd: ev.socket, n: integer, buff: ffi.cdata*): integer?, ffi.cdata* | string?
libev.srawrecv = syncify(libev.rawrecv);
--- @type fun(self: ev, fd: ev.socket, n: integer, buff: ffi.cdata*): integer?, ffi.cdata* | string?
libev.srawsend = syncify(libev.rawsend);

--- @type fun(self: ev, name: string, flags?: std.net.addrinfo_flags): string[]?, string?
libev.sgetaddrinfo = syncify(libev.getaddrinfo);

--- @type fun(self: ev, type: "home" | "config" | "data" | "cache" | "runtime" | "cwd"): string?, string?
libev.sgetpath = syncify(libev.getpath);

libev.syncify = syncify;

return libev;

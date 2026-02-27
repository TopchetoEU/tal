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

--- @type fun(self: ev, fd: ev.handle, n: integer): string?, string?
libev.sread = syncify(libev.read);
--- @type fun(self: ev, fd: ev.handle, data: string): integer?, string?
libev.swrite = syncify(libev.write);
--- @type fun(self: ev, fd: ev.handle, n: integer, buff: ffi.cdata*): integer?, ffi.cdata* | string?
libev.srawread = syncify(libev.rawread);
--- @type fun(self: ev, fd: ev.handle, n: integer, buff: ffi.cdata*): integer?, ffi.cdata* | string?
libev.srawwrite = syncify(libev.rawwrite);


--- @type fun(self: ev, path: string, flags: std.fs.open_flags, mode?: string | integer): ev.handle?, string?
libev.sfile_open = syncify(libev.file_open);
--- @type fun(self: ev, fd: ev.handle): std.fs.stat?, string?
libev.sfile_stat = syncify(libev.file_stat);
--- @type fun(self: ev, fd: ev.handle, offset: integer, n: integer): string?, string?
libev.sfile_read = syncify(libev.file_read);
--- @type fun(self: ev, fd: ev.handle, offset: integer, data: string): integer?, string?
libev.sfile_write = syncify(libev.file_write);
--- @type fun(self: ev, fd: ev.handle): true?, string?
libev.sfile_sync = syncify(libev.file_sync);
--- @type fun(self: ev, fd: ev.handle, offset: integer, n: integer, buff: ffi.cdata*): integer?, ffi.cdata* | string?
libev.sfile_rawread = syncify(libev.file_rawread);
--- @type fun(self: ev, fd: ev.handle, offset: integer, n: integer, buff: ffi.cdata*): integer?, ffi.cdata* | string?
libev.sfile_rawwrite = syncify(libev.file_rawwrite);

--- @type fun(self: ev, path: string, mode?: integer | string): true?, string?
libev.sdir_new = syncify(libev.dir_new);
--- @type fun(self: ev, path: string): ev.dir?, string?
libev.sdir_open = syncify(libev.dir_open);
--- @type fun(self: ev, dir: ev.dir): string?, string?
libev.sdir_next = syncify(libev.dir_next);

--- @type fun(self: ev, addr: string, port: integer, prot?: "tcp" | "udp"): ev.handle?, string?
libev.ssocket_connect = syncify(libev.socket_connect);
--- @type fun(self: ev, addr: string, port: integer, prot?: "tcp" | "udp", max_n?: integer): ev.server?, string?
libev.sserver_bind = syncify(libev.server_bind);
--- @type fun(self: ev, server: ev.server): ev.server?, string?, integer?
libev.sserver_accept = syncify(libev.server_accept);

--- @type fun(self: ev, argv: string[], env: { [string]: string, [integer]: { [1]: string, [2]: string } }, cwd: any, stdin?: "inherit"|"pipe"|ev.handle, stdout?: "inherit"|"pipe"|ev.handle, stderr?: "inherit"|"pipe"|ev.handle): ev.proc?, string | ev.handle?, ev.handle?, ev.handle?
libev.sproc_spawn = syncify(libev.proc_spawn);
--- @type fun(self: ev, proc: ev.proc): "exit" | "code" | "int"?, string | integer?
libev.sproc_wait = syncify(libev.proc_wait);

--- @type fun(self: ev, name: string, flags?: std.net.addrinfo_flags): string[]?, string?
libev.sgetaddrinfo = syncify(libev.getaddrinfo);
--- @type fun(self: ev, type: "home" | "config" | "data" | "cache" | "runtime" | "cwd"): string?, string?
libev.sgetpath = syncify(libev.getpath);

libev.syncify = syncify;

return libev;

local sig = require "std.sig";
local process_args = require "impl.process_args";
local libposix = require "nat.libposix";
local is = require "std.basic.is";
local unix_fd = require "impl.unix.unix_fd";
local unix_dir = require "impl.unix.unix_dir";
local unix_iterenv = require "impl.unix.unix_iterenv";
local unix_proc = require "impl.unix.unix_proc";
local unix_server = require "impl.unix.unix_server";
local unix_ttyraw = require "impl.unix.unix_ttyraw";

--- @class impl.unix: impl
local unix_impl = {};
unix_impl.__index = unix_impl;
unix_impl.__metatable = "impl.unix";

local sig_table = {
	[0] = "INT",
	[1] = "QUIT",
	[2] = "ABRT",
	[3] = "TERM",
	[4] = "BADMEM",
	[5] = "BADOP",
	[6] = "BADPIPE",
	[7] = "TSIZE",
	[8] = "TLOST",
	[9] = "USR1",
	[10] = "USR2",

	["INT"] = 0,
	["QUIT"] = 1,
	["ABRT"] = 2,
	["TERM"] = 3,
	["BADMEM"] = 4,
	["BADOP"] = 5,
	["BADPIPE"] = 6,
	["TSIZE"] = 7,
	["TLOST"] = 8,
	["USR1"] = 9,
	["USR2"] = 10,
};

--- @param owned boolean
--- @return impl.libyaooi.fd fd
function unix_impl:openfd(fd, owned)
	return unix_fd(self, libyaooi.fd.new(fd, owned));
end
function unix_impl:open(udata, path, flags, mode)
	path = sig.str(path, "path");
	flags = sig.str(flags, "flags");
	if type(mode) == "string" then
		mode = tonumber(mode, 8) or sig.error("mode", "not a valid base-8 number");
	end

	mode = sig.optnum(mode, "mode", 0x1FF);

	return nil, unix_fd(self.queue, libyaooi.file_open(path, flags, mode));
end
function unix_impl:mkdir(udata, path, mode)
	return libyaooi.dir.new(libyaooi.req.new(self.queue, udata), path, mode);
end
function unix_impl:opendir(udata, path)
	return nil, yo_dir(self.queue, libyaooi.dir.open(path));
end

function unix_impl:symlink(udata, path, target)
	return libyaooi.file_symlink(libyaooi.req.new(self.queue, udata), path, target);
end
function unix_impl:hardlink(udata, path, target)
	return libyaooi.file_hardlink(libyaooi.req.new(self.queue, udata), path, target);
end
function unix_impl:readlink(udata, path)
	return libyaooi.file_readlink(libyaooi.req.new(self.queue, udata), path);
end
function unix_impl:remove(udata, path)
	return libyaooi.file_remove(libyaooi.req.new(self.queue, udata), path);
end

function unix_impl:bind(udata, addr, port, protocol, max_n)
	return nil, yo_server(self.queue, libyaooi.socket_bind(addr, port, protocol, max_n));
end
function unix_impl:connect(udata, addr, port, protocol)
	return libyaooi.socket_connect(
		libyaooi.req.new(self.queue, process_args.wrap_udata(udata, function (fd) return unix_fd(self.queue, fd) end)),
		addr, port, protocol
	);
end
function unix_impl:getaddrinfo(udata, name, flags)
	return libyaooi.dns_getaddrinfo(libyaooi.req.new(self.queue, udata), name, flags);
end

--- @param kind? "real" | "mono" | "cpu" = "mono"
function unix_impl:time(kind)
	return libyaooi.time(kind or "mono");
end

function unix_impl:getpath(type)
	return libyaooi.getpath(type);
end

--- @return string?
function unix_impl:env_get(name)
	return libposix.getenv(name);
end
function unix_impl:env_set(name, val)
	if val then
		return libposix.setenv(name, val);
	else
		return libposix.unsetenv(name);
	end
end
function unix_impl:iterenv()
	return unix_iterenv();
end

function unix_impl:spawn(udata, argv, env, cwd, stdin, stdout, stderr, windowssucks)
	local res, stdin, stdout, stderr = libyaooi.proc.spawn(argv, env, cwd, stdin, stdout, stderr, windowssucks);
	return nil,
		yo_proc(self.queue, res),
		stdin and unix_fd(self.queue, stdin),
		stdout and unix_fd(self.queue, stdout),
		stderr and unix_fd(self.queue, stderr);
end

function unix_impl:sig_on(sig)
	return libyaooi.sig_on(sig_table[sig] --[[@as number]]);
end
function unix_impl:sig_off(sig)
	return libyaooi.sig_off(sig_table[sig] --[[@as number]]);
end
--- @return fun()? cancel
--- @return string sig
function unix_impl:sig_wait(udata)
	return libyaooi.sig_wait(libyaooi.req.new(self.queue, process_args.wrap_udata(udata, function (sig) return sig_table[sig] end))) --[[@as any]];
end

local function next_processargs(req, ok, ...)
	if not req then return nil end
	local udata = req:udata();

	if is(udata, process_args.tag) then
		if not ok then return udata.udata, false, ... end
		return udata.udata, true, udata.process_args(...);
	else
		return udata, ok, ...;
	end
end

function unix_impl:next(timeout)
	return next_processargs(self.queue:poll(timeout));
end

function unix_impl:ttyraw(fd)
	local fd = is(fd, "impl.libyaooi.fd");
	assert(fd, "fd must be from libyaooi");

	return yo_ttyraw(self.queue, fd.fd);
end

return function ()
	local queue = libyaooi.queue.new();
	return setmetatable({
		queue = queue,
		stdin = unix_fd(queue, libyaooi.tty_in()),
		stdout = unix_fd(queue, libyaooi.tty_out()),
		stderr = unix_fd(queue, libyaooi.tty_err()),
	}, unix_impl);
end

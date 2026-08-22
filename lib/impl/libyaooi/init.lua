local sig = require "std.sig";
local process_args = require "impl.process_args";
local errors = require "std.errors";
local libyaooi = require "nat.libyaooi";
local yo_fd  = require "impl.libyaooi.yo_fd";
local yo_dir  = require "impl.libyaooi.yo_dir";
local yo_iterenv  = require "impl.libyaooi.yo_iterenv";
local yo_proc  = require "impl.libyaooi.yo_proc";
local yo_server  = require "impl.libyaooi.yo_server";

--- @class impl.libyaooi.impl: _impl
--- @field queue libyaooi.queue
local yo_impl = {};
yo_impl.__index = yo_impl;
yo_impl.__metatable = "impl.ev_impl";

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
--- @return impl.libyaooi.fd? fd
--- @return string? err
function yo_impl:openfd(fd, owned)
	return yo_fd(self.queue, libyaooi.fd.new(fd, owned)), nil;
end
function yo_impl:open(udata, path, flags, mode)
	path = sig.str(path, "path");
	flags = sig.str(flags, "flags");
	if type(mode) == "string" then
		mode = tonumber(mode, 8) or sig.error("mode", "not a valid base-8 number");
	end

	mode = sig.optnum(mode, "mode", 0x1FF);

	return nil, yo_fd(self.queue, libyaooi.file_open(path, flags, mode));
end
function yo_impl:mkdir(udata, path, mode)
	return libyaooi.dir.new(libyaooi.req.new(self.queue, udata), path, mode);
end
function yo_impl:opendir(udata, path)
	return nil, yo_dir(self.queue, libyaooi.dir.open(path));
end

function yo_impl:symlink(udata, path, target)
	return libyaooi.file_symlink(libyaooi.req.new(self.queue, udata), path, target);
end
function yo_impl:hardlink(udata, path, target)
	return libyaooi.file_hardlink(libyaooi.req.new(self.queue, udata), path, target);
end
function yo_impl:readlink(udata, path)
	return libyaooi.file_readlink(libyaooi.req.new(self.queue, udata), path);
end
function yo_impl:remove(udata, path)
	return libyaooi.file_remove(libyaooi.req.new(self.queue, udata), path);
end

function yo_impl:bind(udata, addr, port, protocol, max_n)
	return nil, yo_server(self.queue, libyaooi.socket_bind(addr, port, protocol, max_n));
end
function yo_impl:connect(udata, addr, port, protocol)
	return libyaooi.socket_connect(
		libyaooi.req.new(self.queue, process_args.wrap_udata(udata, function (fd) return yo_fd(self.queue, fd) end)),
		addr, port, protocol
	);
end
function yo_impl:getaddrinfo(udata, name, flags)
	return libyaooi.dns_getaddrinfo(libyaooi.req.new(self.queue, udata), name, flags);
end

--- @param kind? "real" | "mono" | "cpu" = "mono"
function yo_impl:time(kind)
	return libyaooi.time(kind or "mono");
end

function yo_impl:getpath(type)
	return libyaooi.getpath(type);
end
--- @return string?
function yo_impl:env_get(name)
	return libyaooi.env_get(name);
end
function yo_impl:env_set(name, val)
	return libyaooi.env_set(name, val);
end
function yo_impl:iterenv()
	return yo_iterenv(libyaooi.enviter.new());
end

function yo_impl:spawn(udata, argv, env, cwd, stdin, stdout, stderr, windowssucks)
	local res, stdin, stdout, stderr = libyaooi.proc.spawn(argv, env, cwd, stdin, stdout, stderr, windowssucks);
	return nil,
		yo_proc(self.queue, res),
		stdin and yo_fd(self.queue, stdin),
		stdout and yo_fd(self.queue, stdout),
		stderr and yo_fd(self.queue, stderr);
end

function yo_impl:sig_on(sig)
	return libyaooi.sig_on(sig_table[sig] --[[@as number]]);
end
function yo_impl:sig_off(sig)
	return libyaooi.sig_off(sig_table[sig] --[[@as number]]);
end
--- @return fun()? cancel
--- @return string sig
function yo_impl:sig_wait(udata)
	return libyaooi.sig_wait(libyaooi.req.new(self.queue, process_args.wrap_udata(udata, function (sig) return sig_table[sig] end))) --[[@as any]];
end

local function next_processargs(req, ok, ...)
	if not req then return nil end
	local udata = req:udata();


	if getmetatable(udata) == process_args.tag then
		if not ok then return udata.udata, false, ... end
		return udata.udata, true, udata.process_args(...);
	else
		return udata, ok, ...;
	end
end

function yo_impl:next(timeout)
	return next_processargs(self.queue:poll(timeout));
end

return function ()
	local queue = libyaooi.queue.new();
	return setmetatable({
		queue = queue,
		stdin = yo_fd(queue, libyaooi.tty_in()),
		stdout = yo_fd(queue, libyaooi.tty_out()),
		stderr = yo_fd(queue, libyaooi.tty_err()),
	}, yo_impl);
end

local sig = require "std.sig";
local libev = require "nat.libev";
local ev_file = require "impl.libev.ev_file";
local ev_dir = require "impl.libev.ev_dir";
local ev_server = require "impl.libev.ev_server";
local ev_handle = require "impl.libev.ev_handle";
local ev_iterenv = require "impl.libev.ev_iterenv";
local process_args = require "impl.libev.process_args"
local ev_proc = require "impl.libev.ev_proc"

--- @class impl.ev_impl: _impl
--- @field ev ev
local ev_impl = {};
ev_impl.__index = ev_impl;
ev_impl.__metatable = "impl.ev_impl";


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

function ev_impl:openfd(fd)
	return ev_handle(self.ev, self.ev:handle_new(fd));
end
function ev_impl:open(udata, path, flags, mode)
	path = sig.str(path, "path");
	flags = sig.str(flags, "flags");
	if type(mode) == "string" then
		mode = tonumber(mode, 8) or sig.error("mode", "not a valid base-8 number");
	end

	mode = sig.optnum(mode, "mode", 0x1FF);

	return self.ev:file_open(process_args.wrap_udata(udata, function (file, err)
		if file then return ev_file(self.ev, file), err end
		return file, err;
	end), path, flags, mode);
end
function ev_impl:mkdir(udata, path, mode)
	return self.ev:dir_new(udata, path, mode);
end
function ev_impl:opendir(udata, path)
	return self.ev:dir_open(process_args.wrap_udata(udata, function (dir, err)
		if dir then return ev_dir(self.ev, dir), err end
		return dir, err;
	end), path);
end

function ev_impl:symlink(udata, path, target)
	return self.ev:file_symlink(udata, path, target);
end
function ev_impl:hardlink(udata, path, target)
	return self.ev:file_hardlink(udata, path, target);
end
function ev_impl:readlink(udata, path)
	return self.ev:file_readlink(udata, path);
end
function ev_impl:delete(udata, path)
	return self.ev:file_delete(udata, path);
end

function ev_impl:bind(udata, addr, port, protocol, max_n)
	return self.ev:server_bind(process_args.wrap_udata(udata, function (fd, err)
		if fd then return ev_server(self.ev, fd) end
		return fd, err;
	end), addr, port, protocol, max_n);
end
function ev_impl:connect(udata, addr, port, protocol)
	return self.ev:socket_connect(process_args.wrap_udata(udata, function (fd, err)
		if fd then return ev_handle(self.ev, fd) end
		return fd, err;
	end), addr, port, protocol);
end
function ev_impl:getaddrinfo(udata, name, flags)
	return self.ev:getaddrinfo(udata, name, flags);
end

function ev_impl:realtime()
	return self.ev:realtime();
end
function ev_impl:monotime()
	return self.ev:monotime();
end

function ev_impl:getpath(type)
	return assert(self.ev.getpath(type));
end
function ev_impl:getenv(name)
	return assert(self.ev.getenv(name));
end
function ev_impl:setenv(name, val)
	return assert(self.ev.setenv(name, val));
end
function ev_impl:iterenv()
	return ev_iterenv(self.ev);
end

function ev_impl:spawn(udata, argv, env, cwd, stdin, stdout, stderr)
	return self.ev:proc_spawn(process_args.wrap_udata(udata, function (res, err)
		if res then
			res.proc = ev_proc(self.ev, res.proc --[[@as ev.proc]]);
			res.stdin = res.stdin and ev_handle(self.ev, res.stdin --[[@as ev.handle]]);
			res.stdout = res.stdout and ev_handle(self.ev, res.stdout --[[@as ev.handle]]);
			res.stderr = res.stderr and ev_handle(self.ev, res.stderr --[[@as ev.handle]]);
		end

		return res, err;
	end), argv, env, cwd, stdin, stdout, stderr);
end

function ev_impl:sig_on(sig)
	return self.ev:sig_on(sig_table[sig] --[[@as number]]);
end
function ev_impl:sig_off(sig)
	return self.ev:sig_off(sig_table[sig] --[[@as number]]);
end
function ev_impl:sig_wait(udata)
	return self.ev:sig_wait(process_args.wrap_udata(udata, function (sig, err)
		if not sig then return nil, err end
		return sig_table[sig];
	end));
end

local function next_processargs(udata, ...)
	if type(udata) == "table" and udata.tag == process_args.wrap_tag then
		return udata.udata, udata.process_args(...);
	else
		return udata, ...;
	end
end

function ev_impl:next(timeout)
	if not self.ev:busy() and not timeout then
		return nil;
	end

	return next_processargs(self.ev:next(timeout));
end

return function ()
	local ev = libev.new();
	return setmetatable({
		ev = ev,
		stdin = ev_handle(ev, ev:stdin()),
		stdout = ev_handle(ev, ev:stdout()),
		stderr = ev_handle(ev, ev:stderr()),
	}, ev_impl);
end

local sig = require "std.sig";
local libev = require "nat.libev";
local ev_file = require "impl.libev.ev_file";
local ev_dir = require "impl.libev.ev_dir";
local ev_server = require "impl.libev.ev_server";
local ev_handle = require "impl.libev.ev_handle";
local ev_iterenv = require "impl.libev.ev_iterenv";
local process_args = require "impl.libev.process_args"

--- @type _impl | { ev: ev }
local ev_impl_index = {};
local ev_impl_meta = { __index = ev_impl_index };

function ev_impl_index:open(udata, path, flags, mode)
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
function ev_impl_index:mkdir(udata, path, mode)
	return self.ev:dir_new(udata, path, mode);
end
function ev_impl_index:opendir(udata, path)
	return self.ev:dir_open(process_args.wrap_udata(udata, function (dir, err)
		if dir then return ev_dir(self.ev, dir), err end
		return dir, err;
	end), path);
end

function ev_impl_index:delete(udata, path)
	return true, nil, "not supported";
end
function ev_impl_index:chmod(udata, path)
	return true, nil, "not supported";
end
function ev_impl_index:chown(udata, path)
	return true, nil, "not supported";
end

function ev_impl_index:bind(udata, addr, port, protocol, max_n)
	return self.ev:server_bind(process_args.wrap_udata(udata, function (fd, err)
		if fd then return ev_server(self.ev, fd) end
		return fd, err;
	end), addr, port, protocol, max_n);
end
function ev_impl_index:connect(udata, addr, port, protocol)
	return self.ev:socket_connect(process_args.wrap_udata(udata, function (fd, err)
		if fd then return ev_handle(self.ev, fd) end
		return fd, err;
	end), addr, port, protocol);
end
function ev_impl_index:getaddrinfo(udata, name, flags)
	return self.ev:getaddrinfo(udata, name, flags);
end

function ev_impl_index:realtime()
	return self.ev:realtime();
end
function ev_impl_index:monotime()
	return self.ev:monotime();
end

function ev_impl_index:getpath(type)
	return assert(self.ev.getpath(type));
end
function ev_impl_index:getenv(name)
	return assert(self.ev.getenv(name));
end
function ev_impl_index:setenv(name, val)
	return assert(self.ev.setenv(name, val));
end
function ev_impl_index:iterenv()
	return ev_iterenv(self.ev);
end

local function next_processargs(udata, ...)
	if type(udata) == "table" and udata.tag == process_args.wrap_tag then
		return udata.udata, udata.process_args(...);
	else
		return udata, ...;
	end
end

function ev_impl_index:next(timeout)
	if not self.ev:busy() and not timeout then
		print "EMPTY EV";
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
	}, ev_impl_meta);
end

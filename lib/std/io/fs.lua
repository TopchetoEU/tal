local impl = require "impl";

local sig = require "std.sig";
local loop = require "std.loop";
local p = require "std.path";
local collected = require "std.collected";

local fs = {};

--- @alias std.fs.path
--- | "home"
--- | "config"
--- | "data"
--- | "cache"
--- | "runtime"
--- | "cwd"

--- @class std.fs.dir
--- @field hnd _impl.dir
--- @field closed boolean
local dir = {};
dir.__index = dir;
dir.__metatable = "std.io.fs.dir";

--- @return string?
function dir:read()
	if self.closed then return nil end
	return iassert(loop.sync_ret(self.hnd:next(coroutine.running())));
end
function dir:iter()
	return function (self)
		local res = self:read();
		if not res then self:close() end
		return res;
	end, self;
end
function dir:close()
	if self.closed or self.hnd == nil then return end
	self.hnd:close();
	self.closed = true;
end

dir.__gc = dir.close;

--- @param path string
--- @param mode string | integer
function fs.chmod(path, mode)
	iassert(io.xopen(path, "s"))
		:chmod(mode)
		:close();
end
--- @param path string
--- @param uid integer
--- @param gid integer
function fs.chown(path, uid, gid)
	iassert(io.xopen(path, "s"))
		:chown(uid, gid)
		:close();
end
--- @param path string
function fs.stat(path)
	path = sig.str(path, "path");

	local fd, err = io.xopen(path, "ls");
	if not fd then return nil, err end

	local res = fd:stat();
	iassert(fd:close());
	return res;
end
--- @param path string
function fs.astat(path)
	return iassert(fs.stat(path));
end

--- @param path string
--- @param mode? integer | string
function fs.mkdir(path, mode)
	path = sig.str(path, "path");
	if type(mode) == "string" then
		mode = tonumber(mode, 8);
		if not mode then sig.error("mode", "must be a valid octal number") end
	else
		mode = sig.num(mode, "mode");
	end

	iassert(loop.sync_ret(impl:mkdir(coroutine.running(), path, mode)));
end
--- @param path string
--- @param mode? integer | string
function fs.mkdirs(path, mode)
	path = sig.str(path, "path");
	local segs, root = p.split(p.cwd(fs.path "cwd", path));

	local res = {};

	for i = 1, #segs do
		table.insert(res, segs[i]);
		pcall(fs.mkdir, p.stringify(res, root, false), mode or "777");
	end
end
--- @param path string
function fs.opendir(path)
	path = sig.str(path, "path");

	local fd = iassert(loop.sync_ret(impl:opendir(coroutine.running(), path)));
	return collected(setmetatable({ hnd = fd, closed = false }, dir));
end
function fs.readdir(path)
	path = sig.str(path, "path");
	return iassert(fs.opendir(path)):iter();
end

--- @param src string
--- @param dst string
--- @return true?, string?
function fs.symlink(src, dst)
	iassert(loop.sync_ret(impl:symlink((coroutine.running()), src, dst)));
end
--- @param src string
--- @param dst string
function fs.hardlink(src, dst)
	iassert(loop.sync_ret(impl:hardlink((coroutine.running()), src, dst)));
end
--- @param path string
function fs.readlink(path)
	return iassert(loop.sync_ret(impl:readlink((coroutine.running()), path)));
end
--- @param path string
function fs.delete(path)
	iassert(loop.sync_ret(impl:delete((coroutine.running()), path)));
end

--- @param type? std.fs.path = "cwd"
function fs.path(type)
	type = sig.str(type, "type");
	return iassert(impl:getpath(type or "cwd"));
end


return fs;

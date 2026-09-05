local impl = require "impl";
local impl_str = require "std.os.fs.str";
local impl_file = require "std.os.fs.file";
local str  = require "std.str";

local sig = require "std.sig";
local loop = require "std.loop";
local p = require "std.path";

local dir = require "std.os.fs.dir";

local fs = {};

-- We make std streams buffered, as most people will use them as buffered

fs.stdin = impl_str.new(impl.stdin);
fs.stdout = impl_str.new(impl.stdout);
fs.stderr = impl_str.new(impl.stderr);

fs.stdout:setwbuff(nil, str.chunksize, 0x0A);

--- @alias std.os.fs.path
--- | "home"
--- | "config"
--- | "data"
--- | "cache"
--- | "runtime"
--- | "cwd"

--- @alias std.os.fs.open_flags string
--- |+ "r" Read
--- |+ "w" Write
--- |+ "a" Append
--- |+ "c" Create
--- |+ "t" Truncate
--- |+ "d" Direct
--- |+ "l" No follow
--- |+ "s" Stat

--- @param path string
--- @param flags std.os.fs.open_flags
--- @param ... integer | string
--- @return std.str
function fs.open(path, flags, ...)
	local fd = loop.sync_ret(impl:open(coroutine.running(), path, flags, str.parsechmod(...)));
	local append = flags:find "a";
	return impl_file.new(fd, append and true or false); -- TODO: detect seekability of files
end
--- @param path string
--- @param ... string | integer
function fs.chmod(path, ...)
	fs.open(path, "s"):chmod(...):close();
end
--- @param path string
--- @param uid integer
--- @param gid integer
function fs.chown(path, uid, gid)
	fs.open(path, "s"):chown(uid, gid):close();
end
--- @param path string
function fs.stat(path)
	path = sig.str(path, "path");

	local ok, fd = pcall(fs.open, path, "ls");
	if not ok then return nil, fd --[[@as string]] end

	local res = fd:stat();
	fd:close();

	return res;
end
--- @param path string
function fs.astat(path)
	return iassert(fs.stat(path));
end

--- @param path string
--- @param ... integer | string mode
function fs.mkdir(path, ...)
	path = sig.str(path, "path");
	loop.sync_ret(impl:mkdir(coroutine.running(), path, str.parsechmod(...)));
end
--- @param path string
--- @param ... integer | string mode
function fs.mkdirs(path, ...)
	path = sig.str(path, "path");
	local mode = ... and str.parsechmod(...) or 511;

	local segs, root = p.split(p.cwd(fs.path "cwd", path));
	local res = {};

	for i = 1, #segs do
		table.insert(res, segs[i]);
		pcall(fs.mkdir, p.stringify(res, root, false), mode);
	end
end
--- @param path string
function fs.opendir(path)
	path = sig.str(path, "path");

	local fd = loop.sync_ret(impl:opendir(coroutine.running(), path));
	return dir.new(fd);
end
function fs.readdir(path)
	path = sig.str(path, "path");
	return iassert(fs.opendir(path)):iter();
end

--- @param src string
--- @param dst string
--- @return true?, string?
function fs.symlink(src, dst)
	loop.sync_ret(impl:symlink((coroutine.running()), src, dst));
end
--- @param src string
--- @param dst string
function fs.hardlink(src, dst)
	loop.sync_ret(impl:hardlink((coroutine.running()), src, dst));
end
--- @param path string
function fs.readlink(path)
	return loop.sync_ret(impl:readlink((coroutine.running()), path));
end
--- @param path string
function fs.remove(path)
	loop.sync_ret(impl:remove((coroutine.running()), path));
end

--- @param type? std.os.fs.path = "cwd"
function fs.path(type)
	type = sig.str(type, "type");
	return iassert(impl:getpath(type or "cwd"));
end

return fs;

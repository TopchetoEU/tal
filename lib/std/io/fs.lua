local impl = require "impl";
local sig = require "std.sig";
local loop = require "std.loop";
local collected = require "std.collected"

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
local dir_index = {};

--- @return string?
--- @return string? err
function dir_index:read()
	if self.closed then return nil end
	return loop.sync_ret(self.hnd:next(coroutine.running()));
end
function dir_index:close()
	if self.closed or self.hnd == nil then return end
	self.hnd:close();
	self.closed = true;
end

local dir_meta = {
	__index = dir_index,
	__gc = dir_index.close,
};

--- @param path string
function fs.stat(path)
	path = sig.str(path, "path");

	local fd, err = io.xopen(path, "");
	if not fd then return nil, err end

	local res, err = fd:stat();
	fd:close();
	if not res then return nil, err end
	return res;
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

	return loop.sync_ret(impl:mkdir(coroutine.running(), path, mode));
end
--- @param path string
--- @return std.fs.dir?
--- @return string? err
function fs.opendir(path)
	path = sig.str(path, "path");

	local fd, err = loop.sync_ret(impl:opendir(coroutine.running(), path));
	if not fd then return nil, err end

	return collected(setmetatable({
		hnd = fd,
		closed = false,
	}, dir_meta));
end
function fs.readdir(path)
	path = sig.str(path, "path");

	local dir, err = fs.opendir(path);
	if not dir then return nil, err end

	return function ()
		if not dir then return nil, "closed" end

		local next, err = dir:read();
		if not next then
			dir:close();
			dir = nil;
		end

		if err then return nil, err end
		return next;
	end
end

--- @param path string
function fs.delete(path)
	path = sig.str(path, "path");

	-- TODO: TO BE DONE
	return os.remove(path);
end
--- @param path string
--- @param mod integer
function fs.chmod(path, mod)
	path = sig.str(path, "path");
	mod = sig.num(mod, "mod");

	-- TODO: TO BE DONE
	return nil, "not implemented";
end
--- @param path string
--- @param uid integer
--- @param gid integer
function fs.chown(path, uid, gid)
	path = sig.str(path, "path");
	uid = sig.num(uid, "uid");
	gid = sig.num(gid, "gid");

	-- TODO: TO BE DONE
	return nil, "not implemented";
end

--- @param type? std.fs.path = "cwd"
function fs.path(type)
	type = sig.str(type, "type");

	return assert(impl:getpath(type or "cwd"));
end

return fs;

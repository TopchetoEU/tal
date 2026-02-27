local prop = require "std.field";
local loop = require "tal.loop";
local collected = require "std.collected";
local fs = {};

--- @class std.fs.stat
--- @field type "file" | "dir" | "link" | "sock" | "fifo" | "char" | "blk"
--- @field mode integer
--- @field gid integer
--- @field uid integer
--- @field atime number
--- @field mtime number
--- @field ctime number
--- @field size integer
--- @field blksize integer
--- @field inode integer
--- @field links integer

--- @alias std.fs.open_flags string
--- |+ "r" EV_OPEN_READ
--- |+ "w" EV_OPEN_WRITE
--- |+ "a" EV_OPEN_APPEND
--- |+ "c" EV_OPEN_CREATE
--- |+ "t" EV_OPEN_TRUNC
--- |+ "d" EV_OPEN_DIRECT

--- @alias std.fs.path
--- | "home"
--- | "config"
--- | "data"
--- | "cache"
--- | "runtime"
--- | "cwd"

local file_fd = prop();
local file_closed = prop();
local file_offset = prop();

--- @class std.io.fs.file: userdata
local file_index = {};
--- @param n integer
function file_index:read(n)
	local closed = file_closed:get(self);
	if closed then return nil, "file is closed" end

	local offset = file_offset:get(self);
	local fd = file_fd:get(self);

	local data, err = loop.curr.ev:sfile_read(fd, offset, n);
	if err then return nil, err end

	file_offset:set(self, offset + #data);
	return data;
end
--- @param data string
function file_index:write(data)
	local closed = file_closed:get(self);
	if closed then return nil, "file is closed" end

	local offset = file_offset:get(self);
	local fd = file_fd:get(self);

	local n, err = loop.curr.ev:sfile_write(fd, offset, data);
	if err then return nil, err end

	file_offset:set(self, offset + n);
	return n;
end
function file_index:flush()
	if file_closed:get(self) then return nil, "file is closed" end
	return loop.curr.ev:sfile_sync(file_fd:get(self));
end
--- @param offset? integer
--- @param whence? "set" | "cur" | "end"
function file_index:seek(offset, whence)
	if file_closed:get(self) then return nil, "file closed" end
	local new_offset = file_offset:get(self);

	offset = offset or 0;
	whence = whence or "cur";

	if whence == "set" then
		new_offset = offset;
	elseif whence == "cur" then
		new_offset = new_offset + offset;
	elseif whence == "end" then
		local stat, err = loop.curr.ev:sfile_stat(file_fd:get(self));
		if not stat then return nil, err end

		new_offset = stat.size + offset;
	else
		error("invalid argument #2 (must be 'set', 'cur' or 'end')", 2);
	end

	file_offset:set(self, new_offset);
	return new_offset;
end
function file_index:stat()
	if file_closed:get(self) then return nil, "file closed" end

	local stat, err = loop.curr.ev:sfile_stat(file_fd:get(self));
	if not stat then return nil, err end

	return stat;
end
function file_index:close()
	if file_closed:get(self) then return end
	loop.curr.ev:close(file_fd:get(self));
	file_closed:set(self, true);
end

local file_identity = newproxy(true);
local file_meta = getmetatable(file_identity);
file_meta.__index = file_index;

--- @return std.io.fs.file
local function mkfile(fd)
	local self = newproxy(file_identity);
	file_fd:set(self, fd);
	file_closed:set(self, false);
	file_offset:set(self, 0);
	return self;
end

local dir_fd = prop();
local dir_closed = prop();

--- @class std.io.dir: userdata
local dir_index = {};
function dir_index:read()
	if dir_closed:get(self) then return nil end
	return loop.curr.ev:sdir_next(dir_fd:get(self));
end
function dir_index:close()
	if dir_closed:get(self) or dir_fd:get(self) == nil then return end
	loop.curr.ev:dir_close(dir_fd:get(self));
	dir_closed:set(self, true);
end

local dir_identity = newproxy(true);
local dir_meta = getmetatable(dir_identity);
dir_meta.__index = dir_index;
dir_meta.__gc = dir_index.close;

--- @param path string
--- @param flags std.fs.open_flags
--- @param mode? integer | string
--- @return std.io.fs.file?
--- @return string? err
function fs.open(path, flags, mode)
	local fd, err = loop.curr.ev:sfile_open(path, flags, mode);
	if not fd then return nil, err end
	return mkfile(fd);
end
--- @param path string
function fs.stat(path)
	local fd, err = fs.open(path, "");
	if not fd then return nil, err end

	local res, err = fd:stat();
	fd:close();
	if not res then return nil, err end
	return res;
end

--- @param path string
--- @param mode? integer | string
function fs.mkdir(path, mode)
	return loop.curr.ev:sdir_new(path, mode);
end
--- @param path string
--- @return std.io.dir?
--- @return string? err
function fs.opendir(path)
	local fd, err = loop.curr.ev:sdir_open(path);
	if not fd then return nil, err end

	local self = newproxy(dir_identity);
	dir_fd:set(self, fd);
	dir_closed:set(self, false);

	return self;
end
function fs.readdir(path)
	local dir, err = fs.opendir(path);
	if not dir then return nil, err end

	collected(dir, dir.close);

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
	-- TODO: TO BE DONE
	return os.remove(path);
end
--- @param path string
--- @param mod integer
function fs.chmod(path, mod)
	-- TODO: TO BE DONE
	return nil, "not implemented";
end
--- @param path string
--- @param uid integer
--- @param gid integer
function fs.chown(path, uid, gid)
	-- TODO: TO BE DONE
	return nil, "not implemented";
end

--- @param type? std.fs.path = "cwd"
function fs.path(type)
	return loop.curr.ev:sgetpath(type or "cwd");
end

fs.stdin = mkfile(loop.curr.ev:stdin());
fs.stdout = mkfile(loop.curr.ev:stdout());
fs.stderr = mkfile(loop.curr.ev:stderr());

return fs;

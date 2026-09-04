local sig  = require "std.sig";
local proc = require "std.os.proc";
local fs = require "std.os.fs";

-- A wrapper around my libraries to mirror lua's "io" global library

--- @class std.io.stat
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

--- @alias std.io.readmode
--- | integer Reads n amount of chars
--- | nil Same as "l"
--- |>"l" Reads a line (without the terminating \n)
--- | "L" Reads a line (with the terminating \n)
--- | "a" Reads the remainder of the stream
--- | "c" Reads a chunk of data, the size of which is determined by the underlying stream. Useful in network streams

--- @alias std.io.open_flags string
--- |+ "r" Read
--- |+ "w" Write
--- |+ "a" Append
--- |+ "c" Create
--- |+ "t" Truncate
--- |+ "d" Direct
--- |+ "l" No follow
--- |+ "s" Stat

local io = {};

io.stdin = fs.stdin:to_lua();
io.stdout = fs.stdout:to_lua();
io.stderr = fs.stderr:to_lua();

--- @param path string
--- @param mode? openmode
--- @return std.luastr?
--- @return string? err
function io.open(path, mode)
	--- @type std.io.open_flags
	local flags;
	mode = mode or "r";

	if mode:find "r" then
		if mode:find "+" then
			flags = "rw";
		else
			flags = "r";
		end
	elseif mode:find "w" then
		if mode:find "+" then
			flags = "rwct";
		else
			flags = "wct";
		end
	elseif mode:find "a" then
		if mode:find "+" then
			flags = "crwa";
		else
			flags = "cwa";
		end
	else
		sig.error("mode", "invalid mode specified");
	end

	local ok, res = pcall(fs.open, path, flags, 777);
	if not ok then return nil, res --[[@as string]] end
	return (res:to_lua());
end

--- @param prog string
---@param mode? string
function io.popen(prog, mode)
	mode = mode or "r";
	local r = mode:find "r" and true or false;
	local w = mode:find "w" and true or false;
	local p, err;

	if jit.os == "Windows" then
		p, err = proc { argv = { "cmd", "/C", prog }, stdout = r, stdin = w, path = true };
		if not p then return nil, err end
	else
		p, err = proc { argv = { "sh", "-c", prog }, stdout = r, stdin = w, path = true };
		if not p then return nil, err end
	end

	return p:to_stream();
end

--- @param fmt std.io.readmode
function io.read(fmt)
	return io.stdin:read(fmt);
end
function io.write(...)
	return io.stdout:write(...);
end
function io.flush()
	pcall(io.stdout.flush, io.stdout);
	pcall(io.stderr.flush, io.stderr);
	return true;
end
--- @param file? std.io.stream
function io.close(file)
	if file then
		file:close();
	else
		io.stdin:close();
		io.stdout:close();
		io.stderr:close();
	end
end

--- @param filename? string
--- @param fmt std.io.readmode
function io.lines(filename, fmt)
	if filename then
		return assert(io.open(filename, "r")):lines(fmt, true);
	else
		return io.stdin:lines(fmt);
	end
end

return io;

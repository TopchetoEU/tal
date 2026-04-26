local impl = require "impl";
local loop = require "std.loop";
local sig  = require "std.sig";
local stream = require "std.io.stream";

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
--- |+ "r"
--- |+ "w"
--- |+ "a"
--- |+ "c"
--- |+ "t"
--- |+ "d"

local io = {};

io.stdin = stream.from_stream(impl.stdin);
io.stdout = stream.from_stream(impl.stdout);
io.stderr = stream.from_stream(impl.stderr);

--- @param path string
--- @param flags std.io.open_flags
--- @param mode? integer | string
function io.xopen(path, flags, mode)
	mode = mode or "666";
	if type(mode) == "string" then mode = assert(tonumber(mode, 8)) end

	local f, err = loop.sync_ret(impl:open(coroutine.running(), path, flags, mode));
	if not f then return nil, err  end

	return stream.from_file(f);
end
--- @param path string
--- @param mode? openmode
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
			flags = "rwa";
		else
			flags = "wa";
		end
	else
		sig.error("mode", "invalid mode specified");
	end

	return io.xopen(path, flags);
end

--- @param fmt std.io.readmode
function io.read(fmt)
	return io.stdin:read(fmt);
end
function io.write(...)
	return io.stdout:write(...);
end
function io.flush()
	local _, err = io.stdin:flush();
	if err then return nil, err end

	local _, err = io.stdout:flush();
	if err then return nil, err end

	local _, err = io.stderr:flush();
	if err then return nil, err end

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

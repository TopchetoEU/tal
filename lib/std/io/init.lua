local impl = require "impl";
local loop = require "std.loop";
local sig  = require "std.sig";
local stream = require "std.io.stream";
local proc = require "std.proc";

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

io.stdin = stream.from_stream(impl.stdin, false);
io.stdout = stream.from_stream(impl.stdout, false);
io.stderr = stream.from_stream(impl.stderr, false);

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
			flags = "crwa";
		else
			flags = "cwa";
		end
	else
		sig.error("mode", "invalid mode specified");
	end

	return io.xopen(path, flags);
end

--- @param prog string
---@param mode? string
function io.popen(prog, mode)
	mode = mode or "r";
	local r = mode:find "r" and "pipe" or "inherit";
	local w = mode:find "w" and "pipe" or "inherit";
	local p, err;

	if jit.os == "Windows" then
		p, err = proc { argv = { "cmd", "/C", prog }, stdout = r, stdin = w, path = true };
		if not p then return nil, err end
	else
		p, err = proc { argv = { "sh", "-c", prog }, stdout = r, stdin = w, path = true };
		if not p then return nil, err end
	end

	print(p.stdin, p.stdout);

	local self = { p = p };
	function self:read(ptr, n)
		if not self.p.stdout then return nil, "writeonly" end
		return self.p.stdout:ptrread(false, ptr, n);
	end
	function self:write(ptr, n)
		if not self.p.stdin then return nil, "readonly" end
		return self.p.stdin:ptrwrite(false, ptr, n);
	end
	function self:flush(ptr, n)
		if self.p.stdin then
			local _, err = self.p.stdin:flush();
			if err then return nil, err end
		end
		if self.p.stdout then
			local _, err = self.p.stdout:flush();
			if err then return nil, err end
		end
		return true;
	end
	function self:close()
		if self.p.stdin then
			self.p.stdin:close();
		end
		if self.p.stdout then
			self.p.stdout:close();
		end
		self.p:wait();
	end

	return stream.new(self, true);
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

local fs = require "std.io.fs";
local lines = require "std.io.lines";
local collected = require "std.collected";
local stream = require "std.io.stream";
local net    = require "std.io.net"

-- A wrapper around my libraries to mirror lua's "io" global library

local io = {};

io.stdin = stream.new(fs.stdin);
io.stdout = stream.new(fs.stdout);
io.stderr = stream.new(fs.stderr);

--- @param path string
--- @param mode? openmode
function io.open(path, mode)
	--- @type std.fs.open_flags
	local flags = "";
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
		error("invalid open path specified", 2);
	end

	local fd, err = fs.open(path, flags, 777);
	if not fd then return nil, err end

	return stream.new(fd, nil, true);
end
--- @param file? std.io.stream
function io.close(file)
	if file then
		file:close();
	else
		io.stdout:close();
	end
end
function io.flush()
	io.stdout:sync();
end
function io.lines(filename, n)
	local f;
	if filename then
		f = assert(io.open(filename, "r"));

		n = n or "l";
		return function ()
			local res, err = f:read(n);
			if err then error(err, 2) end
			if not res then f:close() end
			return res;
		end
	else
		return function ()
			local res, err = io.stdin:read(n);
			if err then error(err, 2) end
			return res;
		end
	end
end

--- @class std.io.server
--- @field _fd std.io.net.server
--- @field _mngd string | true?
local server_index = {};

function server_index:accept()
	local res, err = self._fd:accept();
	if not res then return nil, err end

	return stream.new(res, nil, true);
end
function server_index:close()
	self._mngd = nil;
	return self._fd:close();
end

local server_meta = { __index = server_index };
function server_meta:__gc()
	if self._mngd == true then
		print("Warning: server not closed");
	elseif type(self._mngd == "srting") then
		print("Warning: server not closed: " .. self._mngd);
	end
end

--- @param addr string
--- @param port integer
--- @param protocol? "tcp" | "udp" = "tcp"
--- @return std.io.stream?
--- @return string? err
function io.connect(addr, port, protocol)
	local res, err = net.connect(addr, port, protocol);
	if not res then return nil, err end

	return stream.new(res, nil, true);
end
--- @param addr string
--- @param port integer
--- @param protocol? "tcp" | "udp" = "tcp"
--- @param max_n? integer = 32
--- @return std.io.server?
--- @return string? err
function io.bind(addr, port, protocol, max_n)
	local res, err = net.bind(addr, port, protocol, max_n);
	if not res then return nil, err end

	return collected(setmetatable({ _fd = res, _mngd = true }, server_meta));
end

return io;

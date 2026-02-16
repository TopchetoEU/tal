local lines = require "std.io.lines";
local collected = require "std.collected";

--- @class std.io.stream_funcs
--- @field read fun(self, n: integer): string?, string?
--- @field write fun(self, data: string): true?, string?
--- @field seek? fun(self, pos: integer, whence: "set" | "cur" | "end"): integer?, string?
--- @field sync? fun(self): true?, string?
--- @field close fun(self)

--- @class std.io.stream
--- @field _fd any
--- @field _funcs std.io.stream_funcs
--- @field _buff string[]
--- @field _mngd boolean | string? If managed (aka not closed by the owner), this is set to true or a stack trace
local stream_index = {};

--- @param fmt "a" | "l" | "L" | integer
function stream_index:read(fmt)
	if self._funcs.seek then
		return lines.seekable(self._fd, self._funcs.read, self._funcs.seek, fmt);
	else
		return lines.chunked(self._fd, self._funcs.read, self._buff, fmt);
	end
end
--- @param fmt "a" | "l" | "L" | integer
function stream_index:lines(fmt)
	return function ()
		local res, err = self:read(fmt);
		if err then error(err, 2) end

		return res;
	end
end
--- @param ... string | integer
function stream_index:write(...)
	return self._funcs.write(self._fd, table.concat { ... });
end
--- @param pos integer
--- @param whence "set" | "cur" | "end"
function stream_index:seek(pos, whence)
	if not self._funcs.seek then
		return nil, "seeking not supported";
	end

	return self._funcs.seek(self._fd, pos, whence);
end
function stream_index:sync()
	if not self._funcs.sync then return true end
	return self._funcs.sync(self._fd);
end
stream_index.flush = stream_index.sync;
function stream_index:close()
	self._mngd = nil;
	return self._funcs.close(self._fd);
end

local stream_meta = {
	__index = stream_index,
	__close = stream_index.close,
};

function stream_meta:__gc()
	if self._mngd then
		-- TODO: store a trace stack in debug mode
		if type(self._mngd) == "string" then
			print("warning: Stream not freed: " .. self._mngd);
		else
			print("warning: Stream not freed");
		end
	end
end

--- @param hnd any
--- @param funcs? std.io.stream_funcs
--- @param mngd? string | true
--- @return std.io.stream
local function new(hnd, funcs, mngd)
	return collected(setmetatable({
		_fd = hnd,
		_funcs = funcs or hnd;
		_buff = {},
		_mngd = mngd,
	}, stream_meta));
end
--- NOTE: doesn't support seeking
--- @param read std.io.stream
--- @param write std.io.stream
local function combine(read, write)
	local funcs = {};
	function funcs:read(n)
		return self[1]:read(n);
	end
	function funcs:write(data)
		return self[2]:write(data);
	end
	function funcs:sync()
		local ok, err = self[1]:sync();
		if not ok then return nil, err end

		local ok, err = self[2]:sync();
		if not ok then return nil, err end

		return true;
	end
	function funcs:close()
		self[1]:close();
		self[2]:close();
	end

	local mngd = read._mngd or write._mngd;
	if mngd == true and write._mngd then
		mngd = write._mngd;
	end

	return new({ read, write }, funcs, read._mngd and write._mngd);
end

return { new = new, combine = combine };

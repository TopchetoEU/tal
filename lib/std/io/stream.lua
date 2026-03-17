local lines = require "std.io.lines";
local collected = require "std.collected";

--- @class std.io.stream_backend
--- @field read fun(self, n?: integer): string?, string?
--- @field write fun(self, data: string): true?, string?
--- @field seek? fun(self, pos: integer, whence: "set" | "cur" | "end"): integer?, string?
--- @field sync? fun(self): true?, string?
--- @field close fun(self)

--- @class std.io.stream
--- @field _backend std.io.stream_backend
--- @field _buff string[]
--- @field _mngd boolean | string? If managed (aka not closed by the owner), this is set to true or a stack trace
local stream_index = {};

--- @param fmt? "a" | "c" | "l" | "L" | integer
function stream_index:read(fmt)
	if self._backend.seek then
		return lines.seekable(self._backend, fmt);
	else
		return lines.chunked(self._backend, self._buff, fmt);
	end
end
--- @param fmt? "a" | "c"  | "l" | "L" | integer
function stream_index:lines(fmt)
	return function ()
		local res, err = self:read(fmt);
		if err then error(err, 2) end

		return res;
	end
end
--- @param ... string | integer
function stream_index:write(...)
	return self._backend:write(table.concat { ... });
end
--- @param pos integer
--- @param whence "set" | "cur" | "end"
function stream_index:seek(pos, whence)
	if not self._backend.seek then
		return nil, "seeking not supported";
	end

	return self._backend:seek(pos, whence);
end
function stream_index:sync()
	if not self._backend.sync then return true end
	return self._backend:sync();
end
stream_index.flush = stream_index.sync;
function stream_index:close()
	self._mngd = nil;
	return self._backend:close();
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

--- @param backend? std.io.stream_backend
--- @param mngd? string | true
--- @return std.io.stream
local function new(backend, mngd)
	return collected(setmetatable({
		_backend = backend,
		_buff = {},
		_mngd = mngd,
	}, stream_meta));
end
--- NOTE: doesn't support seeking
--- @param read std.io.stream
--- @param write std.io.stream
local function combine(read, write)
	local funcs = {
		read_str = read,
		write_str = write,
	};
	function funcs:read()
		if not self.read_str then return nil, "closed" end
		return self.read_str:read();
	end
	function funcs:write(data)
		if not self.write_str then return nil, "closed" end
		return self.write_str:write(data);
	end
	function funcs:sync()
		if not self.read_str then return nil, "closed" end
		local ok, err = self.read_str:sync();
		if not ok then return nil, err end

		if not self.write_str then return nil, "closed" end
		local ok, err = self.write_str:sync();
		if not ok then return nil, err end

		return true;
	end
	function funcs:close()
		if self.read_str then
			self.read_str:close();
			self.read_str = nil;
		end
		if self.write_str then
			self.write_str:close();
			self.write_str = nil;
		end
	end

	local mngd = read._mngd or write._mngd;
	if mngd == true and write._mngd then
		mngd = write._mngd;
	end

	return new(funcs, mngd);
end

return { new = new, combine = combine };

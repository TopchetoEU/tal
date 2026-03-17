local loop = require "tal.loop";

--- @class std.sync.cond
--- @field _readers thread[]
--- @field _writers thread[]
--- @field _data? table
--- @field _closed? boolean
local pipe_index = {};

--- @param cb function | thread
function pipe_index:async_read(cb)
	local writer = table.remove(self._writers, 1);
	if writer then loop.push(writer) end
	table.insert(self._readers, cb);
end
--- @param cb function | thread
function pipe_index:async_write(cb, ...)
	local function next_iter(cb, ...)
		local reader = table.remove(self._readers, 1);
		if reader then
			loop.push(reader, ...);
			loop.push(cb);
		else
			table.insert(self._writers, next_iter);
		end
	end

	next_iter(cb, ...);
end

function pipe_index:read()
	self:async_read(coroutine.running());
	return coroutine.yield();
end
function pipe_index:write(...)
	self:async_write(coroutine.running(), ...);
	return coroutine.yield();
end

local pipe_meta = { __index = pipe_index };

return function ()
	return setmetatable({ _readers = {}, _writers = {} }, pipe_meta);
end

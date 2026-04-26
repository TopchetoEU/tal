local loop = require "std.loop";

--- @class std.sync.pipe
--- @field _readers thread[]
--- @field _writers thread[]
--- @field _data? table
--- @field _closed? boolean
local pipe_index = {};

function pipe_index:read()
	local writer = table.remove(self._writers, 1);
	if writer then loop.push(writer) end

	table.insert(self._readers, (coroutine.running()));
	return loop.await();
end
function pipe_index:write(...)
	while true do
		local reader = table.remove(self._readers, 1);
		if reader then
			loop.push(reader, ...);
			loop.rest();
		else
			table.insert(self._writers, (coroutine.running()));
			loop.await();
		end
	end
end

local pipe_meta = { __index = pipe_index };

return function ()
	return setmetatable({ _readers = {}, _writers = {} }, pipe_meta);
end

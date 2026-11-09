local loop = require "std.loop";
local errors = require "std.errors";

--- @class std.sync.pipe
--- @field _readers thread[]
--- @field _writers thread[]
--- @field _data? table
--- @field _closed? boolean
local pipe = {};
pipe.__index = pipe;
pipe.__metatable = "std.sync.pipe";

function pipe:read()
	local writer = table.remove(self._writers, 1);
	if writer then loop.resolve(writer) end

	local th = coroutine.running();
	table.insert(self._readers, th);
	return loop.await(function ()
		table.delete(self._readers, th);
		loop.reject(th, errors.cancelled);
	end);
end
function pipe:write(...)
	while true do
		local reader = table.remove(self._readers, 1);
		if reader then
			loop.resolve(reader, ...);
			return loop.rest();
		else
			local th = coroutine.running();
			table.insert(self._writers, th);
			loop.await(function ()
				table.delete(self._writers);
				loop.reject(th, errors.cancelled);
			end);
		end
	end
end

function pipe.new()
	return setmetatable({ _readers = {}, _writers = {} }, pipe);
end

return pipe;

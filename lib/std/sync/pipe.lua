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

function pipe:iter()
	return self.read, self;
end
--- @generic T
--- @param iter fun(self, i): any, T?
--- @param iself? any
--- @param init? any
--- @return T[]
function pipe:ifrom(iter, iself, init)
	local res = {};

	for _, el in iter, iself, init do
		self:write(el);
	end

	return res;
end
--- @generic T
--- @param iter fun(iself, i): T?
--- @param iself? any
--- @param init? any
--- @return T[]
function pipe:from(iter, iself, init)
	local res = {};

	for el in iter, iself, init do
		self:write(el);
	end

	return res;
end

function pipe.new()
	return setmetatable({ _readers = {}, _writers = {} }, pipe);
end

return pipe;

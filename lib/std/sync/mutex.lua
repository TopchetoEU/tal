local loop = require "std.loop";
local errors = require "std.errors";

--- @class std.sync.mutex
--- @field _locked boolean
--- @field _waiters thread[]
local mutex = {};
mutex.__index = mutex;
mutex.__metatable = "std.sync.mutex";

function mutex:trylock()
	if self._locked then return false end
	self._locked = true;
	return true;
end
function mutex:lock()
	while self._locked do
		local th = coroutine.running();
		table.insert(self._waiters, th);
		loop.await(function ()
			table.delete(self._waiters, th);
			loop.reject(th, errors.cancelled);
		end);
	end

	self._locked = true;
end
function mutex:unlock()
	assert(self._locked, "mutex not locked, cannot be unlocked");

	self._locked = false;
	local next = table.remove(self._waiters, 1);
	if next then loop.resolve(next) end
end

function mutex.new()
	return setmetatable({ _locked = false, _waiters = {} }, mutex);
end

return mutex;

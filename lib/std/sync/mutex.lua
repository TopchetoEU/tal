local loop = require "std.loop";

--- @class std.sync.mutex
--- @field _locked boolean
--- @field _waiters thread[]
local mutex = {};
mutex.__index = mutex;
mutex.__metatable = "std.sync.mutex";

function mutex:lock()
	while self._locked do
		table.insert(self._waiters, (coroutine.running()));
		loop.await();
	end

	self._locked = true;
end
function mutex:unlock()
	assert(self._locked, "mutex not locked, cannot be unlocked");

	self._locked = false;
	local next = table.remove(self._waiters, 1);
	if next then loop.push(next) end
end

return function ()
	return setmetatable({ _locked = false, _waiters = {} }, mutex);
end

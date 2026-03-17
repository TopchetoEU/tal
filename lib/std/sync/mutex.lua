local loop = require "tal.loop";

--- @class std.sync.mutex
--- @field _locked boolean
--- @field _waiters thread[]
local mutex_index = {};

--- @param cb function | thread
function mutex_index:async_lock(cb)
	if cb == coroutine.running() and not self._locked then
		self._locked = true;
		return;
	end

	local function next_iter()
		if self._locked then
			table.insert(self._waiters, next_iter);
		else
			self._locked = true;
			loop.push(cb);
		end
	end

	next_iter();
end
function mutex_index:lock()
	mutex_index:async_lock(coroutine.running());
	return coroutine.yield();
end
function mutex_index:unlock()
	self._n = self._n - 1;
	if self._n == 0 then
		self._owner = nil;
		local next = table.remove(self._waiters, 1);
		if next then loop.push(next) end
	end
end

local mutex_meta = { __index = mutex_index };

return function ()
	return setmetatable({ _owner = nil, _n = 0 }, mutex_meta);
end

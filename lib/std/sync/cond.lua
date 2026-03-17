local loop = require "tal.loop";

--- @class std.sync.cond
--- @field _waiters thread[]
--- @field _pending boolean
local cond_index = {};

--- @param cb function | thread
function cond_index:async_wait(cb)
	if self._pending then
		self._pending = false;
		loop.push(cb);
	else
		table.insert(self._waiters, cb);
	end
end
function cond_index:wait()
	cond_index:async_wait(coroutine.running());
	return coroutine.yield();
end
--- @param all boolean
function cond_index:signal(all)
	if #self._waiters == 0 then
		self._pending = true;
		return;
	end

	if all then
		for i = 1, #self._waiters do
			loop.push(self._waiters[i]);
		end
		table.clear(self._waiters);
	else
		local next = table.remove(self._waiters, 1);
		if next then loop.push(next) end
	end
end

local mutex_meta = { __index = cond_index };

return function ()
	return setmetatable({ _waiters = {}, _pending = true, _owner = nil, _n = 0 }, mutex_meta);
end

local loop = require "std.loop";

--- @class std.sync.cond
--- @field _waiters thread[]
--- @field _pending boolean
local cond_index = {};

function cond_index:wait()
	if not self._pending then
		table.insert(self._waiters, (coroutine.running()));
		loop.await();
		self._pending = false;
	end
end
--- @param all? boolean
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
	return setmetatable({ _waiters = {}, _pending = false, _owner = nil, _n = 0 }, mutex_meta);
end

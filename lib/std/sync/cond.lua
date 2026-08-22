local loop = require "std.loop";

--- @class std.sync.cond
--- @field _waiters thread[]
--- @field _pending boolean
local cond = {};
cond.__index = cond;
cond.__metatable = "std.sync.cond";

function cond:wait()
	-- if self._pending then
	-- 	self._pending = false;
	-- else
		table.insert(self._waiters, (coroutine.running()));
		loop.await();
	-- end
end
--- @param all? boolean
function cond:signal(all)
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

function cond.new()
	return setmetatable({ _waiters = {}, _pending = false, _owner = nil, _n = 0 }, cond);

end

return cond;

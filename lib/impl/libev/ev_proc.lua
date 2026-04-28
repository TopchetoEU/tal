--- @class _impl.proc_data
--- @field ev ev
--- @field fd ev.proc
--- @field closed boolean

--- @type _impl.process
local proc_index = {};
function proc_index:wait(udata)
	local self_data = debug.getuservalue(self) --[[@as _impl.proc_data]];

	if self_data.closed then return "closed" end
	return self_data.ev:proc_wait(udata, self_data.fd);
end
-- function proc_index:close()
-- 	local self_data = debug.getuservalue(self) --[[@as _impl.proc_data]];

-- 	if self_data.closed then return end
-- 	self_data.ev:proc_close(self_data.fd);
-- 	self_data.closed = true;
-- end

local proc_identity = newproxy(true);
local proc_meta = getmetatable(proc_identity);
proc_meta.__index = proc_index;

--- @return _impl.process
return function (ev, proc)
	return debug.setuservalue(newproxy(proc_identity), {
		ev = ev,
		fd = proc,
		closed = false,
	});
end

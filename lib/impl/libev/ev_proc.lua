--- @class _impl.proc_data
--- @field ev ev
--- @field fd ev.proc
--- @field closed boolean

--- @class impl.process: _impl.process
--- @field ev ev
--- @field fd ev.proc
--- @field closed boolean
local ev_proc = {};
ev_proc.__index = ev_proc;
ev_proc.__metatable = "impl.ev_proc";

function ev_proc:wait(udata)
	if self.closed then return "closed" end
	return self.ev:proc_wait(udata, self.fd);
end
-- function proc_index:close()
-- 	local self_data = debug.getuservalue(self) --[[@as _impl.proc_data]];

-- 	if self_data.closed then return end
-- 	self_data.ev:proc_close(self_data.fd);
-- 	self_data.closed = true;
-- end
--- @param ev ev
--- @param fd ev.proc
--- @return _impl.process
return function (ev, fd)
	return setmetatable({
		ev = ev,
		fd = fd,
		closed = false,
	}, ev_proc);
end

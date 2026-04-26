--- @class _impl.dir_data
--- @field ev ev
--- @field fd ev.dir
--- @field closed boolean

--- @type _impl.dir
local dir_index = {};
function dir_index:next(udata)
	local self_data = debug.getuservalue(self) --[[@as _impl.dir_data]];

	if self_data.closed then return "closed" end
	return self_data.ev:dir_next(udata, self_data.fd);
end
function dir_index:close()
	local self_data = debug.getuservalue(self) --[[@as _impl.dir_data]];

	if self_data.closed then return end
	self_data.ev:dir_close(self_data.fd);
	self_data.closed = true;
end

local dir_identity = newproxy(true);
local dir_meta = getmetatable(dir_identity);
dir_meta.__index = dir_index;
dir_meta.__gc = dir_index.close;

--- @return _impl.dir
return function (ev, dir)
	return debug.setuservalue(newproxy(dir_identity), {
		ev = ev,
		fd = dir,
		closed = false,
	});
end

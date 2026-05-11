local sig = require "std.sig";

--- @class _impl.ev.file_data
--- @field fd ev.file
--- @field ev ev
--- @field closed boolean

--- @type _impl.file
local file_index = {};
function file_index:read(udata, offset, buff, n)
	n = sig.optnum(n, "n");
	local self_data = debug.getuservalue(self) --[[@as _impl.ev.file_data]];

	if self_data.closed then return true, nil, "file is closed" end

	return self_data.ev:file_read(udata, self_data.fd, offset, n, buff);
end
function file_index:write(udata, offset, buff, n)
	n = sig.optnum(n, "n");
	local self_data = debug.getuservalue(self) --[[@as _impl.ev.file_data]];

	if self_data.closed then return true, nil, "file is closed" end

	return self_data.ev:file_write(udata, self_data.fd, offset, n, buff);
end
function file_index:flush(udata)
	local self_data = debug.getuservalue(self) --[[@as _impl.ev.file_data]];
	return self_data.ev:sync(udata, self_data.fd);
end
function file_index:stat(udata)
	local self_data = debug.getuservalue(self) --[[@as _impl.ev.file_data]];
	if self_data.closed then return true, nil, "file is closed" end

	return self_data.ev:stat(udata, self_data.fd);
end
function file_index:chmod(udata, mode)
	local self_data = debug.getuservalue(self) --[[@as _impl.ev.file_data]];
	if self_data.closed then return true, nil, "file is closed" end

	return self_data.ev:file_chmod(udata, self_data.fd, mode);
end
function file_index:chown(udata, uid, gid)
	local self_data = debug.getuservalue(self) --[[@as _impl.ev.file_data]];
	if self_data.closed then return true, nil, "file is closed" end

	return self_data.ev:file_chown(udata, self_data.fd, uid, gid);
end
function file_index:close()
	local self_data = debug.getuservalue(self) --[[@as _impl.ev.file_data]];
	if self_data.closed then return end
	self_data.ev:close(self_data.fd);
	self_data.closed = true;
end

local file_identity = newproxy(true);
local file_meta = getmetatable(file_identity);
file_meta.__index = file_index;

--- @return _impl.file
return function (ev, fd)
	return debug.setuservalue(newproxy(file_identity), {
		fd = fd,
		ev = ev,
		closed = false,
		offset = 0,
	});
end

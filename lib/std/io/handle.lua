local field = require "std.field";
local loop = require "tal.loop";

local handle_fd = field();
local handle_closed = field();

--- @class std.io.handle: userdata
local handle_index = {};
--- @param n integer
function handle_index:read(n)
	if handle_closed:get(self) then return nil, "file is closed" end
	return loop.curr.ev:sread(handle_fd:get(self), n);
end
--- @param data string
function handle_index:write(data)
	if handle_closed:get(self) then return nil, "file is closed" end
	return loop.curr.ev:swrite(handle_fd:get(self), data);
end
function handle_index:close()
	if handle_closed:get(self) or handle_fd:get(self) == nil then return end
	loop.curr.ev:close(handle_fd:get(self));
	handle_closed:set(self, true);
end

local handle_identity = newproxy(true);
local handle_meta = getmetatable(handle_identity);
handle_meta.__index = handle_index;
handle_meta.__gc = handle_index.close;

--- @return std.io.handle
return function (handle)
	local res = newproxy(handle_identity);
	handle_fd:set(res, handle);
	handle_closed:set(res, false);
	return res;
end

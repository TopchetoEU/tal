local loop = require "std.loop";
local collected = require "std.basic.table.collected";

--- @class std.fs.dir
--- @field hnd _impl.dir
--- @field closed boolean
local dir = {};
dir.__index = dir;
dir.__metatable = "std.os.fs.dir";

--- @return string?
function dir:read()
	if self.closed then return nil end
	return loop.sync_ret(self.hnd:next(coroutine.running()));
end
function dir:iter()
	return function (self)
		local res = self:read();
		if not res then self:close() end
		return res;
	end, self;
end
function dir:close()
	if self.closed or self.hnd == nil then return end
	self.hnd:close();
	self.closed = true;
end
function dir.new(backend)
	return collected(setmetatable({ hnd = backend, closed = false }, dir))
end

dir.__gc = dir.close;

return dir;

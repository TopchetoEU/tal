local loop = require "std.loop";
local collected = require "std.collected";
local errors = require "std.errors";

--- @class std.os.fs.dir
--- @field hnd impl.dir
--- @field closed boolean
local dir = {};
dir.__index = dir;
dir.__metatable = "std.os.fs.dir";

--- @return string?
function dir:read()
	if self.closed then error(errors.closed) end
	return loop.await(self.hnd:next(coroutine.running()));
end
function dir:iter()
	return function (self)
		local ok, res = errors.spcall(self.read, self);
		if not ok then
			if errors.is(res, errors.eof) then
				self:close();
				return nil;
			else
				error(res);
			end
		end

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

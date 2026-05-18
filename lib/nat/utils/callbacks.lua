local ffi = require "ffi";
local objects = require "nat.utils.objects";

--- @class nat.callbacks
--- @field get_key fun(...): any
--- @field fix_args? fun(...): ...
--- @field ctype ffi.ctype*
--- @field ptr ffi.cb*
local callbacks_index = {};
local callbacks_meta = {
	__index = callbacks_index,
	__metatable = "callbacks",
};

--- @param cb function
function callbacks_index:add(cb)
	return objects.add(cb);
end
--- @param id integer
--- @return function
function callbacks_index:del(id)
	return objects.del(id);
end

function callbacks_index:fire(...)
	local cb = objects.get(self.get_key(...));
	if not cb then return end

	if self.fix_args then
		return cb(self.fix_args(...));
	else
		return cb(...);
	end
end

--- @param ctype ffi.ct*
--- @param get_key fun(...): integer
--- @param fix_args? fun(...): ...
function callbacks_index.new(ctype, get_key, fix_args)
	local self = setmetatable({}, callbacks_meta);

	self.get_key = get_key;
	self.fix_args = fix_args;
	self.ptr = ffi.gc(
		ffi.new(ctype, function (...)
			return self:fire(...);
		end),
		function ()
			self.ptr:free();
		end
	) --[[@as ffi.cb*]];

	return self;
end

return callbacks_index;

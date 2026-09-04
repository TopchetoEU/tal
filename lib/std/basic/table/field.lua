--- @class std.field
local field = {};
field.__index = field;
field.__metatable = "std.field";
field.__mode = "k";

function field:get(obj)
	return self[obj];
end
function field:set(obj, val)
	self[obj] = val;
end

--- A utility function for creating "private" properties, based on ephemeral (weak) tables
return function ()
	return setmetatable({}, field);
end

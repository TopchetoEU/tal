--- @class prop
local prop = {};
prop.__index = prop;
prop.__mode = "k";

function prop:get(obj)
	return self[obj];
end
function prop:set(obj, val)
	self[obj] = val;
end

--- A utility function for creating "private" properties, based on ephemeral (weak) tables
return function ()
	return setmetatable({}, prop);
end

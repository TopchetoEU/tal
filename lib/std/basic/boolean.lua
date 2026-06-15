--- @class boolean: booleanlib
--- @class booleanlib
local boolean = {};
boolean.__metatable = "boolean";

--- @param val any
function boolean.new(val)
	return not not val;
end

debug.setmetatable(true, boolean);

return boolean;

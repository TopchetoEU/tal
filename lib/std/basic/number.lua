--- @class number: numberlib
--- @class numberlib
local number = {};
number.__index = number;
number.__metatable = "number";

--- @param val any
function number.new(val, base)
	return iassert(tonumber(val, base), "not convertable to number");
end

debug.setmetatable(0, number);
debug.setmetatable(0.1, number);

return number;

--- @class std.tag
--- @field _label string
local tag = {};
tag.__index = tag;
tag.__metatable = "std.tag";

function tag:__tostring()
	return self._label;
end

--- @param label string
function tag.new(label)
	return setmetatable({ _label = label }, tag);
end

return tag;

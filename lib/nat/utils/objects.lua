--- @type table<integer, any>
local map = {};
--- @type integer
local next = 0;

local objects = {};

--- @param obj any
--- @return integer
function objects.add(obj)
	next = next + 1;
	local key = next;

	map[key] = obj;
	return key;
end
--- @param id integer
--- @return any
function objects.get(id)
	return map[id];
end
--- @param key integer
function objects.del(key)
	local res = map[key];
	map[key] = nil;
	return res;
end

return objects;

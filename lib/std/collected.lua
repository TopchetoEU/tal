local field = require "std.field";

-- A field of every collectable table, referring to its token
local token_field = field();

-- TODO: this seems to work by pure magic

local meta_proxy = newproxy(true);
local meta = getmetatable(meta_proxy);
--- @param self userdata
function meta.__gc(self)
	local obj = debug.getuservalue(self);
	if obj == nil then return end

	local obj_meta = getmetatable(obj);
	if obj_meta == meta then
		return obj.func(obj.tab);
	elseif type(obj_meta) == "table" and type(obj_meta.__gc) == "function" then
		return obj_meta.__gc(obj);
	end
end
function meta:__tostring()
	return "<__gc caller token>";
end

--- Because luajit doesn't support __gc metamethods on tables, this is used as a "manual polyfill"
--- This will create a proxy, associate it with the table, and when the proxy is collected, the object will be collected, too
---
--- This function is lightweight, it only creates one userdata object.
--- @generic T
--- @param tab T
--- @param func? fun() If passed, instead of tab's __gc metamethod, this function will be called upon collection
--- @return T
return function (tab, func)
	local token = newproxy(meta_proxy);
	if func then
		debug.setuservalue(token, setmetatable({ func = func, tab = tab }, meta));
	else
		debug.setuservalue(token, tab);
	end
	token_field:set(tab, token);
	return tab;
end

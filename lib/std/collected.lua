local field = require "std.field";

-- If __gc on tables is natively supported to begin with, don't even bother
local native_supported = false;
setmetatable({}, { __gc = function ()
	native_supported = true;
end });

collectgarbage();

if native_supported then
	--- @generic T
	--- @param tab T
	--- @return T
	return function (tab, force_lightweight)
		return tab;
	end
end

-- A field of every collectable table, referring to its token
local token_field = field();

-- TODO: this seems to work by pure magic

local meta_proxy = newproxy(true);
local meta = getmetatable(meta_proxy);
function meta:__gc()
	local obj = debug.getuservalue(self);
	if obj == nil then return end

	local meta = getmetatable(obj);
	if type(meta) == "table" and type(meta.__gc) == "function" then
		return meta.__gc(obj);
	end
end
function meta:__tostring()
	return "<__gc caller token>";
end

--- Because luajit doesn't support __gc metamethods on tables, this is used as a "manual polyfill"
--- This will create a proxy, associate it with the table, and when the proxy is collected, the object will be collected, too
---
--- This function is lightweight, it only creates one userdata object.
---
--- However, it is a real possibility for the underlying implementation to start using another method, if luajit's GC changes its behavior.
--- In such a case, set 'force_lightweight' to true, so that
--- @generic T
--- @param tab T
--- @param force_lightweight? boolean
--- @return T
return function (tab, force_lightweight)
	local token = newproxy(meta_proxy);
	debug.setuservalue(token, tab);
	token_field:set(tab, token);
	return tab;
end

local loop = require "std.loop";
local cond = require "std.sync.cond";

local queue = {};
local queue_cond = cond();
local kys = false;
local th = loop.fork(function ()
	while not kys do
		while #queue > 0 do
			local func, obj = table.unpack(table.remove(queue));
			local ok, err = xpcall(func, debug.traceback, obj);
			if not ok then
				io.stderr:write("error in finalizer: ", err);
			end
		end
		queue_cond:wait();
	end
end);
loop.name(th, "Collector");

-- TODO: this seems to work by pure magic

local meta_proxy = newproxy(true);
local meta = getmetatable(meta_proxy);
--- @param self userdata
function meta.__gc(self)
	local obj = debug.getuservalue(self);
	if obj == nil then return end

	local obj_meta = getmetatable(obj);
	if obj_meta == meta then
		table.insert(queue, { obj.func, obj.tab });
		queue_cond:signal(true);
	elseif type(obj_meta) == "table" and type(obj_meta.__gc) == "function" then
		table.insert(queue, { obj_meta.__gc, obj });
		queue_cond:signal(true);
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
	-- This will break pairs(), oh well...
	tab[meta_proxy] = token;
	return tab;
end

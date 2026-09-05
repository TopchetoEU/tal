--- @class thread: coroutinelib

--- @class coroutinelib
local coroutine = coroutine;
coroutine.__index = coroutine;
coroutine.__metatable = "thread";

--- @type table<thread, string>
local names = setmetatable({}, { __mode = "k" });

--- @param th thread
--- @param name? string
function coroutine.name(th, name)
	if name then
		names[th] = name;
		return th;
	else
		return names[th] or "Unnamed thread";
	end
end

function coroutine.debuglog()
	for th, name in pairs(names) do
		if th:status() ~= "dead" then
			print(name .. ": " .. debug.traceback(th));
		end
	end
end

--- @param th thread
function coroutine.__tostring(th)
	return th:name();
end

if coroutine.running() then
	debug.setmetatable(coroutine.running(), coroutine);
else
	error "luajit not compiled with -DLUAJIT_ENABLE_LUA52COMPAT";
end

return coroutine;

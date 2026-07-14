--- @class thread: coroutinelib

--- @class coroutinelib
local coroutine = coroutine;
coroutine.__index = coroutine;
coroutine.__metatable = "thread";

--- @type table<thread, string>
local names = {};

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

debug.setmetatable(coroutine.running(), coroutine);
debug.setmetatable(coroutine.running(), coroutine);

return coroutine;

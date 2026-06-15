--- @class thread: coroutinelib

--- @class coroutinelib
local coroutine = coroutine;
coroutine.__index = coroutine;
coroutine.__metatable = "thread";

debug.setmetatable(coroutine.running(), coroutine);
debug.setmetatable(coroutine.running(), coroutine);

return coroutine;

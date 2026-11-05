--- @class thread: coroutinelib

--- @class coroutinelib
local coroutine = coroutine;
coroutine.__index = coroutine;
coroutine.__metatable = "thread";

--- @type table<thread, fun()>
local cancels = setmetatable({}, { __mode = "k" });
--- @type table<thread, true>
local cancel_flag = setmetatable({}, { __mode = "k" });
--- @type table<thread, string>
local names = setmetatable({}, { __mode = "k" });
--- @type table<thread, boolean>
local daemons = setmetatable({}, { __mode = "k" });

--- @param self thread
--- @param name? string
function coroutine:name(name)
	if name then
		names[self] = name;
		return self;
	else
		return names[self] or "Unnamed thread";
	end
end

--- @param self thread
--- @param val? boolean
function coroutine:daemon(val)
	daemons[self] = val or nil;
end
--- @param self thread
function coroutine:is_daemon()
	return daemons[self] == true;
end

--- @param self? thread
--- @param cb? function
function coroutine:set_cancel(cb)
	self = self or coroutine.running();

	if cb then
		if cancels[self] then
			error "thread already has a cancel function";
		end

		cancels[self] = cb;
	else
		if not cancels[self] then
			error "thread does not have a cancel function";
		end

		cancels[self] = nil;
	end
end
--- @param self thread
function coroutine:cancel()
	local cancel = cancels[self];
	cancels[self] = nil;

	cancel_flag[self] = true;

	if cancel then cancel() end
end
--- @param self? thread
function coroutine:cancelpt()
	self = self or coroutine.running();

	if cancel_flag[self] then
		cancel_flag[self] = nil;
		error(errors.cancelled);
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

function coroutine.get_cancels()
	return cancels;
end

if coroutine.running() then
	debug.setmetatable(coroutine.running(), coroutine);
else
	error "luajit not compiled with -DLUAJIT_ENABLE_LUA52COMPAT";
end

return coroutine;

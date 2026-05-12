local real_error = error;

--- @param msg unknown
--- @param level? integer
local function error(msg, level)
	level = level or 1;

	if type(msg) ~= "string" or level < 1 then
		return real_error(msg, 0);
	end

	local info = debug.getinfo(level + 1, "Sl");

	if info and info.what == "Lua" then
		if info.currentcol and info.currentcol > 0 then
			return real_error(info.short_src .. ":" .. info.currentline .. ":" .. info.currentcol .. ": " .. msg, 0);
		elseif info.currentline and info.currentline > 0 then
			return real_error(info.short_src .. ":" .. info.currentline .. ": " .. msg, 0);
		else
			return real_error(info.short_src .. ": " .. msg, 0);
		end
	end

	return real_error(msg, 0);
end
--- @generic T
--- @param val T | nil | false
--- @return T, ...
local function assert(val, ...)
	local message = ...;

	if not val then
		return error(message or "assertion failed!", 1);
	else
		return val, ...;
	end
end
local function throw(err)
	return real_error(err, 0);
end

--- An IO alternative for assert (doesn't change the error message)
--- @generic T
--- @param val T | nil
--- @param err string?
--- @return T
local function iassert(val, err)
	if not val and err then return error(err, 0) end
	return val;
end
--- An IO alternative for error (doesn't change the error message)
--- @param err any
local function ierror(err)
	return error(err, 0);
end
local function spcall_catch(err)
	return { err = err, trace = debug.traceback(nil, 2) };
end
local function spcall_fin(ok, ...)
	if ok then return true, ... end
	if type(...) ~= "table" then return false, ... end
	return false, (...).err, (...).trace;
end
--- Calls the given function with xpcall and captures a stack trace on an error. It is returned alongside the unmodified error
--- @param f function
local function spcall(f, ...)
	return spcall_fin(xpcall(f, spcall_catch, ...));
end

return {
	throw = throw,

	error = error,
	assert = assert,

	ierror = ierror,
	iassert = iassert,

	pcall = pcall,
	xpcall = xpcall,
	spcall = spcall,
}

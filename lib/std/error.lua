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

return {
	throw = throw,
	error = error,
	assert = assert,
}

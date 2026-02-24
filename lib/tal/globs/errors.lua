local loading = require "tal.compiler.loading";
local old_error = error;

local _G = _G;

--- @param msg unknown
--- @param level? integer
function _G.error(msg, level)
	level = level or 1;

	if type(msg) ~= "string" or level < 1 then
		old_error(msg, level);
	end

	local info = debug.getinfo(level + 1, "Sl");

	if info and info.what == "Lua" then
		if info.currentcol and info.currentcol > 0 then
			return old_error(info.short_src .. ":" .. info.currentline .. ":" .. info.currentcol .. ": " .. msg, 0);
		elseif info.currentline and info.currentline > 0 then
			return old_error(info.short_src .. ":" .. info.currentline .. ": " .. msg, 0);
		else
			return old_error(info.short_src .. ": " .. msg, 0);
		end
	end

	return old_error(msg, 0);
end
function _G.assert(...)
	local v, message = ...;

	if not v then
		error(message or "assertion failed!", 2);
	else
		return ...;
	end
end

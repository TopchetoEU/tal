local loading = require "tal.compiler.loading";
local old_error = error;

--- @param msg unknown
--- @param level? integer
function _G.error(msg, level)
	level = level or 1;

	if type(msg) ~= "string" or level < 1 then
		old_error(msg, level);
	end

	local info = debug.getinfo(level + 1, "Sl");

	local loc = loading.map(info.short_src, info.currentline);
	if loc then
		old_error(info.short_src .. ":" .. loc.row .. ":" .. loc.col .. ": " .. msg, 0);
	else
		old_error(info.short_src .. ":" .. info.currentline .. ": " .. msg, 0);
	end
end
function _G.assert(...)
	local v, message = ...;

	if not v then
		error(message or "assertion failed!", 2);
	else
		return ...;
	end
end

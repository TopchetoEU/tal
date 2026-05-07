-- Since our compiler supports columns, we need to patch lua's debug library to use our mappings

local loading = require "std.compiler.loading";
local buffer = require "string.buffer";
local sig = require "std.sig";

local old_getinfo = debug.getinfo;
local old_sethook = debug.sethook;

--- @class debuginfo
--- @field currentcol integer?
--- @field coldefined integer?
--- @field lastcoldefined integer?
--- @field activecols integer[]?

local debug = {
	debug = debug.debug,
	getfenv = debug.getfenv,
	gethook = debug.gethook,
	getinfo = debug.getinfo,
	getlocal = debug.getlocal,
	getmetatable = debug.getmetatable,
	getregistry = debug.getregistry,
	getupvalue = debug.getupvalue,
	getuservalue = debug.getuservalue,
	setcstacklimit = debug.setcstacklimit,
	setfenv = debug.setfenv,
	sethook = debug.sethook,
	setlocal = debug.setlocal,
	setmetatable = debug.setmetatable,
	setupvalue = debug.setupvalue,
	setuservalue = debug.setuservalue,

	upvalueid = debug.upvalueid,
	upvaluejoin = debug.upvaluejoin,
};

local function fix_args(...)
	if type((...)) == "thread" then
		return ...;
	else
		return nil, ...;
	end
end

function debug.sethook(...)
	local th, f, mask, cnt = fix_args(...);

	if mask and mask:find "l" and type(f) == "function" then
		local old_f = f;
		function f(...)
			if ... == "line" then
				local info = old_getinfo(2, "Sl");
				local loc = loading.map(info.source, info.currentline);
				return old_f(..., loc and loc.row or info.currentline, loc and loc.col);
			else
				return old_f(...);
			end
		end
	end

	if th then
		return old_sethook(th, f, mask, cnt);
	else
		return old_sethook(f, mask, cnt);
	end
end
function debug.getinfo(...)
	local th, lvl, mask = fix_args(...);

	if type(lvl) == "number" then
		lvl = lvl + 1;
	end

	local bogus_s = false;

	if type(mask) == "string" and (mask:find "l" or mask:find "L") and not mask:find "S" then
		mask = mask .. "S";
		bogus_s = true;
	end

	local info;
	if th then
		info = old_getinfo(th, lvl, mask);
	else
		info = old_getinfo(lvl, mask);
	end

	if not info then return nil end

	local def_loc = loading.map(info.source, info.linedefined);
	if def_loc then
		info.linedefined = def_loc.row;
		info.coldefined = def_loc.col;
	end

	if info.activelines then
		local cols = {};

		for i = 1, info.activelines do
			local loc = loading.map(info.source, info.activelines[i]);
			if loc then
				info.activelines[i] = loc.col;
			else
				cols[i] = -1;
			end
		end

		info.activecols = cols;
	end

	if not bogus_s then
		local lastdef_loc = loading.map(info.source, info.lastlinedefined);
		if lastdef_loc then
			info.lastlinedefined = lastdef_loc.row;
			info.lastcoldefined = lastdef_loc.col;
		end

		local curr_loc = loading.map(info.source, info.currentline);
		if curr_loc then
			info.currentline = curr_loc.row;
			info.currentcol = curr_loc.col;
		end
	else
		info.short_src = nil;
		info.source = nil;
		info.linedefined = nil;
		info.lastlinedefined = nil;
		info.what = nil;
	end

	return info;
end
function debug.traceback(...)
	local th, msg, lvl = fix_args(...);

	lvl = sig.optnum(lvl, "lvl", 1) + 1;

	local res = buffer.new();

	if msg ~= nil then
		res:put(tostring(msg), "\nstack traceback:");
	else
		res:put "stack traceback:";
	end

	while true do
		local info = debug.getinfo(th or coroutine.running(), lvl, "Snl");
		if not info then break end

		local curr = "";

		if info.short_src and (info.what == "Lua" or info.what == "main") then
			if info.source:find "^[@=]" then
				curr = curr .. "in " .. info.source:sub(2);
			else
				curr = curr .. "in " .. info.short_src;
			end
		end

		if info.currentline >= 0 then
			curr = curr .. ":" .. info.currentline;
			if info.currentcol then
				curr = curr .. ":" .. info.currentcol;
			end
		end

		if info.name and info.name ~= "main" then
			if curr == "" then
				curr = "at " .. info.name;
			else
				curr = curr .. " at " .. info.name;
			end
		end

		if curr == "" then
			res:put("\n\t<internal>");
		else
			res:put("\n\t", curr);
		end
		lvl = lvl + 1;
	end

	return tostring(res);
end

return debug;

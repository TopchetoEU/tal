local comp_err = require "std.compiler.comp_err"
local err = require "std.err";
local loc = require "std.err.loc";
--- @type table<string, table<integer, std.err.loc>>
local maps = {};

local mapping = {};

--- @param name string
function mapping.short_name(name)
	if name:find "^[=@]" then
		return name:sub(2);
	elseif #name > 100 then
		return "[string \"" .. name:sub(100) .. "...\"]";
	else
		return "[string \"" .. name .. "\"]";
	end
end

--- @param name? string
--- @param loc? std.err.loc
--- @param msg string
function mapping.err_stringify(name, loc, msg)
	local parts = {};
	if name then
		table.insert(parts, mapping.short_name(name));
	end

	if loc then
		if loc.row then
			if #parts > 0 then table.insert(parts, ":") end
			table.insert(parts, tostring(loc.row));
		end
		if loc.col then
			if #parts > 0 then table.insert(parts, ":") end
			table.insert(parts, tostring(loc.col));
		end
	end

	if #parts > 0 then table.insert(parts, ": ") end
	table.insert(parts, msg);

	return table.concat(parts);
end

--- @param e string
function mapping.err_parse(e)
	local i = 1;

	if e:find "^%[" then return err:new(e) end

	local name, name_l = e:match("^([^%[%]%:]+):()", i);
	i = name_l or i;

	local row, col, loc_i = e:match("^(%d+):(%d+):()", i);
	if not row then
		row, loc_i = e:match("^(%d+):()", i);
	end
	row = row and tonumber(row);
	col = col and tonumber(col);
	i = loc_i or i;

	local msg = e:match("^ ?(.+)", i);
	return comp_err:new(msg, row and loc.new(row, col or 1, name));
end

--- @param err string
--- @param fallback? table<integer, std.err.loc>
function mapping.err_map(err, fallback)
	local e = mapping.err_parse(err);
	if e ~= comp_err then return e end
	if not e.loc then return e end

	local map = e.loc.fname and (maps["@" .. e.loc.fname] or maps["=" .. e.loc.fname]) or fallback;

	if e.loc and map and map[e.loc.row] then
		e.loc = map[e.loc.row];
	end

	return e;
end

--- @param name string
--- @param line integer
function mapping.map(name, line)
	if not name then return nil end

	if name and line and maps[name] and maps[name][line] then
		return maps[name][line];
	end
end
--- @param name string
--- @param map table<integer, std.err.loc>
function mapping.emit_map(name, map)
	if maps[name] then return end
	maps[name] = map;
end
--- @param name string
function mapping.get_map(name)
	return maps[name];
end

return mapping;

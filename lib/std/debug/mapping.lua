--- @type table<string, table<integer, node.loc>>
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
--- @param loc? node.loc
--- @param msg string
function mapping.err_stringify(name, loc, msg)
	local parts = {};
	if name then
		table.insert(parts, mapping.short_name(name));
	end

	if loc then
		if loc.get then loc:get() end

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

--- @param err string
function mapping.err_parse(err)
	local i = 1;

	if err:find "^%[" then return nil, nil, err end

	local name, name_l = err:match("^([^%[%]%:]+):()", i);
	i = name_l or i;

	local row, col, loc_i = err:match("^(%d+):(%d+):()", i);
	if not row then
		row, loc_i = err:match("^(%d+):()", i);
	end
	row = row and tonumber(row);
	col = col and tonumber(col);
	i = loc_i or i;

	local msg = err:match("^ ?(.+)", i);

	return "=" .. name, row and { row = row, col = col or 1 }, msg;
end

--- @param err string
--- @param fallback? table<integer, node.loc>
function mapping.err_map(err, fallback)
	local name, loc, msg = mapping.err_parse(err);
	if not name then return msg end

	local map = maps["@" .. name] or maps["=" .. name] or fallback;

	if loc and map and map[loc.row] then
		loc = map[loc.row];
	end

	return mapping.err_stringify(name, loc, msg);
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
--- @param map table<integer, node.loc>
function mapping.emit_map(name, map)
	if maps[name] then return end
	maps[name] = map;
end
--- @param name string
function mapping.get_map(name)
	return maps[name];
end

return mapping;

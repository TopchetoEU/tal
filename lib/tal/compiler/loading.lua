local syntax = require "tal.compiler.syntax";
local fix = require "tal.compiler.fix";
local stringify = require "tal.compiler.stringify";
local node = require "tal.compiler.node";
local loading = {};

local load_raw = load;

--- @type table<string, table<integer, node.loc>>
local maps = {};

--- @param name string
function loading.short_name(name)
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
function loading.err_stringify(name, loc, msg)
	local parts = {};
	if name then
		table.insert(parts, loading.short_name(name));
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

--- @param err string
function loading.err_parse(err)
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

	return "=" .. name, row and node.loc(row, col or 1), msg;
end

--- @param err string
--- @param fallback? table<integer, node.loc>
function loading.err_map(err, fallback)
	local name, loc, msg = loading.err_parse(err);
	if not name then return msg end

	local sname = loading.short_name(name);

	if loc and sname and maps[sname] and (fallback or maps[sname][loc.row]) then
		loc = (maps[sname] or fallback)[loc.row];
	end

	return loading.err_stringify(name, loc, msg);
end

--- @param name string
--- @param line integer
function loading.map(name, line)
	if name and line and maps[name] and maps[name][line] then
		return maps[name][line];
	end
end

--- @param chunk string | fun(): string
--- @param name? string
--- @param mode? loadmode
--- @param env? table
--- @param no_map? boolean
function loading.load(chunk, name, mode, env, no_map)
	if type(chunk) == "function" then
		local res = {};

		for el in chunk do
			table.insert(res, el);
		end

		chunk = table.concat(res);
	end

	if name == nil then name = chunk end
	if mode == "b" or mode == "bt" then
		local fun, err = load_raw(chunk, name, "b", env or _G);
		if fun then
			return fun;
		elseif mode == "b" then
			return nil, err;
		end
	end

	local ast, err, loc = syntax.parse(chunk);
	if not ast then return nil, loading.err_stringify(name, loc, err --[[@as string]]) end

	ast = fix(ast);

	local str, map = stringify.all(ast);

	local fun, err = load_raw(str, name, "t", env or _G);
	if not fun then return nil, loading.err_map(err --[[@as string]], map) end

	if not no_map and name:match "^[=@]" then
		maps[name:sub(2)] = map;
	end

	return fun
end

--- @param name string
function loading.mod_searcher(name)
	local file, err = package.searchpath(name, package.path);
	if not file then return err end

	local res, err = loading.load(io.lines(file, 4096), "@" .. file, "t");
	if not res then error(err, 0) end
	return res, file;
end

return loading;

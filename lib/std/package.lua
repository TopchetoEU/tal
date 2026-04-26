--- @diagnostic disable: duplicate-set-field

require "std.string";
require "std.printing";
local load = require "std.compiler.loading".load;
local path = require "std.path";

local package = {
	path = package.path,
	cpath = package.cpath,
	loaded = package.loaded,
	preload = package.preload,
	pathsep = ".",
	pathrep = path.sep,
};

local function override_one(old, override)
	local prev_i = 1;
	local parts = {};

	for sep_i, sep_e in override:gmatch "();;+()" do
		local prefix = override:sub(prev_i, sep_i - 1);
		if #prefix > 0 then
			table.insert(parts, prefix);
		end

		if old and #old > 0 then
			table.insert(parts, old);
		end

		prev_i = sep_e;
	end

	local suffix = override:sub(prev_i);
	if #suffix > 0 then
		table.insert(parts, suffix);
	end

	return table.concat(parts, ";");
end

--- @param ... string
function package.overridepath(...)
	local n = select("#", ...);
	if n < 2 then return ... or "" end

	local old = ...;

	for i = 2, n do
		local override = select(i, ...) --[[@as string]];
		if override then
			old = override_one(old, override);
		end
	end

	return old;
end
--- @param name string
--- @param path string
--- @param sep? string
--- @param rep? string
--- @return string? filename
--- @return string? errmsg
function package.searchpath(name, path, sep, rep)
	local pat = {
		["?"] = name:gsub("%" .. (sep or package.pathsep), rep or package.pathrep),
		["@"] = package.root or ".",
	};

	local lines = {};

	for _, part in path:split ";" do
		local real_path = part:gsub("[%@%?]", pat);

		local f = io.open(real_path, "r");
		if f then
			f:close();
			return real_path;
		end

		table.insert(lines, "\tno file '" .. real_path .. "'");
	end

	return nil, table.concat(lines, "\n");
end

--- @param name string
function package.searchpreload(name)
	if package.preload[name] then
		return package.preload[name], ":preload:";
	else
		return "\tno field package.preload['" .. name .. "']";
	end
end
--- @param name string
function package.searchlua(name)
	local file, err = package.searchpath(name, package.path);
	if not file then return err end

	local f = assert(io.open(file, "r"));
	local src = assert(f:read "a");
	f:close();

	local res, err = load(src, "@" .. file, "t");
	if not res then error(err, 0) end
	return res, file;
end
--- @param name string
function package.searchc(name)
	local file, err = package.searchpath(name, package.path);
	if not file then return err end

	local funcname = name:match("^.*%-(.*)") or name;
	funcname = "luaopen_" .. funcname:gsub("%.", "_");

	return package.loadlib(file, funcname);
end

--- @param name string
--- @return (fun(name: string, data?: any): any)?
--- @return string | any err_or_data
function package.search(name)
	if package.loaded[name] then return package.loaded[name] end

	local errs = {};

	for i = 1, #package.loaders do
		local res, data = package.loaders[i](name);
		if type(res) == "string" or res == nil then
			if res then table.insert(errs, res) end
		else
			return res, data;
		end
	end

	if #errs > 0 then
		return nil, "module '" .. name .. "' not found:\n" .. table.concat(errs, "\n");
	else
		return nil, "module '" .. name .. "' not found";
	end
end
--- @param name string
--- @return any?
--- @return string | any err_or_data
function package.load(name)
	local loader, data = package.search(name);
	if not loader then return nil, data end

	return loader(name, data) or true, data;
end

--- @param name string
function package.require(name)
	if package.loaded[name] then return package.loaded[name] end

	local res, data = package.load(name);
	if res then
		package.loaded[name] = res;
		return res, data;
	else
		return error(data, 1);
	end
end

package.loaders = { package.searchpreload, package.searchlua, package.searchc };
package.searchers = package.loaders;

return package;

--- @diagnostic disable: duplicate-set-field

require "std.string";
local load = require "std.compiler.load";
local pkgpath = require "std.package.path";
local table = require "std.table";
local errors = require "std.errors";

--- @class packagelib
local package = {
	path = package.path,
	cpath = package.cpath,
	loaded = package.loaded,
	preload = package.preload,
	pathsep = pkgpath.sep,
	pathrep = pkgpath.rep,

	overridepath = pkgpath.override,
	searchpath = pkgpath.search,

	--- @type array<string>
	roots = table.mk {},
	--- @type array<string>
	croots = table.mk {},
	env = getfenv(0),
};

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
	local file, err = package.searchpath(name, package.path, nil, nil, package.roots);
	if not file then return err end

	local f = assert(io.open(file, "r"));
	local src = f:read "a";
	f:close();

	local res, err = load(src, "@" .. file, "t", package.env);
	if not res then error(err, 0) end
	return res, file;
end
--- @param name string
function package.searchc(name)
	local file, err = package.searchpath(name, package.cpath, nil, nil, package.croots);
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
		return errors.error(data);
	end
end

package.roots:insertall(debug.getregistry()._LUA_ROOTS or {});
for part in (os.getenv "LUA_ROOTS" or ""):gmatch "[^;]+" do
	package.roots:insert(part);
end

package.croots:insertall(debug.getregistry()._C_ROOTS or {});
for part in (os.getenv "LUA_CROOTS" or ""):gmatch "[^;]+" do
	package.croots:insert(part);
end

package.roots:insert(".");
package.croots:insert(".");

package.loaders = { package.searchpreload, package.searchlua, package.searchc };
package.searchers = package.loaders;
package.path = package.overridepath(package.path, ";;@" .. pkgpath.rep .. "?.lua;@" .. pkgpath.rep .. "?" .. pkgpath.rep .. "init.lua");

if jit.os == "Windows" then
	package.cpath = package.overridepath(package.cpath, ";;@\\?.dll");
else
	package.cpath = package.overridepath(package.cpath, ";;@/lib?.so");
end


return package;

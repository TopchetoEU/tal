--- @diagnostic disable: duplicate-set-field

local buffer = require "string.buffer";
local load = require "std.compiler.load";
local pkgpath = require "std.package.path";
local table = require "std.basic.table";
local fs = require "std.os.fs";
local errors = require "std.errors";
local path_err = require "std.package.path_err";
local error = errors.throw;

--- @class packagelib
local package = {
	path = package.path,
	cpath = package.cpath,
	loaded = package.loaded,
	weakloaded = setmetatable({}, { __index = package.loaded, __mode = "v" }),
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

	strongtag = require "std.package.strongtag",
};

--- @param name string
function package.searchpreload(name)
	if package.preload[name] then
		return package.preload[name], ":preload:";
	else
		return "no field package.preload['" .. name .. "']";
	end
end
--- @param name string
function package.searchlua(name)
	local file, f = package.searchpath(name, package.path, nil, nil, package.roots, function (p)
		local ok, res = pcall(fs.open, p, "r");
		if not ok then error(res .. ", open " .. p) end
		return res;
	end);

	local src = f:readto(buffer.new()):get();
	f:close();

	local res, err = load(src, "@" .. file, "t", package.env);
	if not res then return err end
	return res, file;
end
--- @param name string
function package.searchc(name)
	local file = package.searchpath(name, package.cpath, nil, nil, package.croots);
	local funcname = name:match("^.*%-(.*)") or name;
	funcname = "luaopen_" .. funcname:gsub("%.", "_");

	return package.loadlib(file, funcname);
end

--- @param name string
--- @return fun(name: string, data?: any): any loader
--- @return any data
function package.search(name)
	if package.loaded[name] then return package.loaded[name] end

	local errs = {};

	for i = 1, #package.loaders do
		local ok, res, data = pcall(package.loaders[i], name);
		if ok and data ~= nil then
			if data ~= nil then
				return res --[[@as function]], data;
			elseif res then
				table.insert(errs, res);
			end
		end

		table.insert(errs, res);
	end

	error(path_err.new(name, "package", errs));
end
--- @param name string
--- @return any package
--- @return any data
function package.load(name)
	local loader, data = package.search(name);
	return loader(name, data), data;
end

--- @param name string
function package.require(name)
	if package.weakloaded[name] == false then error("previous error or cyclical dependency with package '" .. name .. "'") end
	if package.weakloaded[name] then return package.weakloaded[name] end

	package.loaded[name] = false;
	local res, data = package.load(name);
	package.loaded[name] = nil;

	if type(res) == "table" and res[package.strongtag] then
		package.loaded[name] = res;
	else
		package.weakloaded[name] = res or true;
	end

	return res, data;
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

--- @type (fun(name: string): function | string, any?)[]
package.loaders = { package.searchpreload, package.searchlua, package.searchc };
package.searchers = package.loaders;
package.path = package.overridepath(package.path, ";;@" .. pkgpath.rep .. "?.lua;@" .. pkgpath.rep .. "?" .. pkgpath.rep .. "init.lua");

if jit.os == "Windows" then
	package.cpath = package.overridepath(package.cpath, ";;@\\?.dll");
else
	package.cpath = package.overridepath(package.cpath, ";;@/lib?.so");
end

return package;

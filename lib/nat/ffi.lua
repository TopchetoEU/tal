--- @class ffilib
local ffi = require "ffi";
local package = require "std.package";
local path = require "std.path";

local ffi_over = ffi;

local old_load = ffi.load;

function ffi_over.load(name, glob)
	if ffi.static then
		for i = 1, #ffi.static do
			if ffi.static[i] == name then return ffi.C end
		end
	end

	local res, err = package.searchpathx(name, ffi.path, nil, nil, ffi.roots, function (path)
		local ok, res = pcall(old_load, path, glob);
		if not ok then return nil, res --[[@as string]] end
		return res;
	end);

	if not res then
		if err then
			return error("failed to load " .. name);
		else
			return error("failed to load " .. name .. ":\n" .. err);
		end
	else
		return res;
	end
end

local reg = debug.getregistry();
reg._FFI_STATIC = reg._FFI_STATIC or {};

ffi.path = package.overridepath("?", os.getenv "FFI_PATH");
ffi.apath = package.overridepath("", os.getenv "FFI_APATH");

if jit.os == "Windows" then
	ffi.path = package.overridepath(
		ffi.path,
		path.join("@", "lib?.dll") .. ";" ..
		path.join("@", "?.dll") .. ";" ..
		path.join("@", "?") .. ";;"
	);
else
	ffi.path = package.overridepath(
		ffi.path,
		path.join("@", "lib?.so") .. ";" ..
		path.join("@", "?.so") .. ";" ..
		path.join("@", "?") .. ";;"
	);
	ffi.apath = package.overridepath(
		ffi.apath,
		path.join("@", "lib?.a") .. ";" ..
		path.join("@", "?.a") .. ";;"
	);
end

--- A list of all libraries that are statically-linked against the current executable
--- @type string[]
ffi.static = reg._FFI_STATIC;

--- @type string[]
ffi.roots = { "." };

if jit.os == "Windows" then
	table.insert(ffi.roots, "C:\\Windows\\System32");
else
	table.insert(ffi.roots, "/usr/lib");
	table.insert(ffi.roots, "/usr/local/lib");
end

return ffi;

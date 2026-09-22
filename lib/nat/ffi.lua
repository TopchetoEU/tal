--- @class ffilib
local ffi = require "ffi";
local pkgpath = require "std.package.path";
local path = require "std.path";
local table = require "std.basic.table";
local debug = require "std.basic.debug";
local objects = require "nat.utils.objects";
local path_err= require "std.package.path_err"

--- @class debug.registry
--- @field _FFI_PATH? string
--- @field _FFI_APATH? string
local reg = debug.registry;

local ffi_load = ffi.load;

---@diagnostic disable-next-line: duplicate-set-field
function ffi.load(name, glob)
	if ffi.static then
		for i = 1, #ffi.static do
			if ffi.static[i] == name then return ffi.C end
		end
	end

	local ok, res, namespace = pcall(pkgpath.search, name, ffi.path, nil, nil, ffi.roots, function (path)
		local ok, res = pcall(ffi_load, path, glob);
		if not ok then return error(res --[[@as string]]) end
		return res;
	end);

	if not ok then
		error(path_err.new(name, "library", errors.all(res)));
	else
		return namespace --[[@as ffi.namespace*]];
	end
end

--- This does NOT pin `str` to the produced pointr
--- Thus, call this only if you can ensure that you hold `str` during the lifetime of the returned pointer
--- @param str string | string.buffer
--- @return ffi.cdata*, integer
function ffi.toptr_unsafe(str)
	return ffi.cast("char*", str), #str;
end
--- This function pins `str` to a global table. Use this only if the returned pointer will outlive `str`
--- @param str string | string.buffer
--- @return ffi.cdata*, integer
function ffi.toptr(str)
	local ptr = ffi.cast("char*", str);
	local str_key = objects.add { str };
	ffi.gc(ptr, function ()
		objects.del(str_key);
	end)
	return ptr, #str;
end

if jit.os == "Windows" then
	ffi.path = pkgpath.override(
		reg._FFI_PATH,
		os.getenv "FFI_PATH",
		path.join("@", "lib?.dll") .. ";" ..
		path.join("@", "?.dll") .. ";" ..
		path.join("@", "?") .. ";?;;"
	);
else
	ffi.path = pkgpath.override(
		reg._FFI_PATH,
		os.getenv "FFI_PATH",
		path.join("@", "lib?.so") .. ";" ..
		path.join("@", "?.so") .. ";" ..
		path.join("@", "?") .. ";?;;"
	);
end

ffi.apath = pkgpath.override(
	reg._FFI_APATH,
	os.getenv "FFI_APATH",
	path.join("@", "lib?.a") .. ";" ..
	path.join("@", "?.a") .. ";;"
);
--- A list of all libraries that are statically-linked against the current executable
--- @type string[]
ffi.static = table.mk(reg._FFI_STATIC or {});

--- @type array<string>
ffi.roots = table.mk(reg._FFI_ROOTS or {});
for part in (os.getenv "FFI_ROOTS" or ""):gmatch "[^;]+" do
	ffi.roots:insert(part);
end

if jit.os == "Windows" then
	if not ffi.roots:find "C:\\Windows\\System32" then
		ffi.roots:insert "C:\\Windows\\System32";
	end
else
	if not ffi.roots:find "/lib" then
		ffi.roots:insert "/lib";
	end
	if not ffi.roots:find "/usr/lib" then
		ffi.roots:insert "/usr/lib";
	end
	if not ffi.roots:find "/usr/local/lib" then
		ffi.roots:insert "/usr/local/lib";
	end
end

reg._FFI_STATIC = ffi.static;
reg._FFI_ROOTS = ffi.roots;

return ffi;

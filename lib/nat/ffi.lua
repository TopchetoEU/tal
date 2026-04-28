--- @class ffilib
local ffi = require "ffi";
local package = require "std.package";
local path = require "std.path";

local ffi_over = ffi;

local old_load = ffi.load;

function ffi_over.load(name, glob)
	local errors = {};

	for _, seg in ffi.path:split ";" do
		local real_seg = seg:gsub("[%?%@]", { ["?"] = name, ["@"] = package.root or "." });

		local ok, res = pcall(old_load, real_seg, glob);
		if ok then return res end

		table.insert(errors, res);
	end

	error("failed to load " .. name .. ":\n\t" .. table.concat(errors, "\n\t"), 2);
end

function ffi.addpath(ffipath, dir)
	if jit.os == "Windows" then
		ffipath = package.overridepath(
			ffipath,
			path.join(dir, "lib?.dll") .. ";" ..
			path.join(dir, "?.dll") .. ";" ..
			path.join(dir, "?") .. ";;"
		);
	else
		ffipath = package.overridepath(
			ffipath,
			path.join(dir, "lib?.so") .. ";" ..
			path.join(dir, "?") .. ";;"
		);
	end

	return ffipath, (ffipath:gsub("%.so", "%.a"));
end

ffi.path = package.overridepath("?", os.getenv "FFI_PATH");

if jit.os == "Windows" then
	ffi.path, ffi.apath = ffi.addpath(ffi.path, "@");
	ffi.path, ffi.apath = ffi.addpath(ffi.path, "C:\\Windows\\System32");
else
	ffi.path, ffi.apath = ffi.addpath(ffi.path, "@");
	ffi.path, ffi.apath = ffi.addpath(ffi.path, "/usr/lib");
	ffi.path, ffi.apath = ffi.addpath(ffi.path, "/usr/local/lib");
end

return ffi;

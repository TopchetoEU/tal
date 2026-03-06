---@class ffilib
local ffi = require "ffi";
require "tal.globs.package";
require "std.printing";

local ffi_over = ffi;

local old_load = ffi.load;

if jit.os == "Windows" then
	ffi.path = package.overridepath(ffi.path,
		"C:\\Windows\\System32\\?.dll;C:\\Windows\\System32\\?;;@\\?;@\\?.dll;@\\lib?.dll;?",
		os.getenv "FFI_PATH"
	);
	ffi.apath = ffi.path:gsub("%.dll", ".lib");
else
	ffi.path = package.overridepath(ffi.path,
		"/lib/lib?.so;/usr/local/lib/?.so;;@/?;@/lib?.so;?",
		os.getenv "FFI_PATH"
	);
	ffi.apath = ffi.path:gsub("%.so", ".a");
end

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

return ffi;

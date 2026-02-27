---@class ffilib
local ffi = require "ffi";
local ffi_over = ffi;

local old_load = ffi.load;

--- @return string
local function override_path(override, old)
	old = old or "";

	if override == nil then return old end

	if override == ";;" then
		return old;
	elseif override:match "^;;" then
		if old == "" then
			return override:sub(3);
		else
			return old .. ";" .. override:sub(3);
		end
	elseif override:match ";;$" then
		if old == "" then
			return override:sub(1, -3);
		else
			return override:sub(1, -3) .. ";" .. old;
		end
	elseif old == "" then
		return (override:gsub(";;", ";", 1));
	else
		return (override:gsub(";;", ";" .. old .. ";", 1));
	end
end

if ffi.os ~= "Windows" then
	ffi.path = override_path("/usr/lib/?.so;/usr/lib/?;/usr/local/lib/?.so;/usr/local/lib/?;;", ffi.path);
end

if os.getenv "FFI_PATH" then
	ffi.path = override_path(os.getenv "FFI_PATH", ffi.path);
end

ffi.path = override_path(";;?", ffi.path);

function ffi_over.load(name, glob)
	local errors = {};

	for seg in ffi.path:gmatch "[^;]+" do
		local real_seg = seg:gsub("%?", name, 1);

		local ok, res = pcall(old_load, real_seg, glob);
		if ok then return res end

		table.insert(errors, res);
	end

	error("failed to load " .. name .. ":\n\t" .. table.concat(errors, "\n\t"), 2);
end

return ffi;

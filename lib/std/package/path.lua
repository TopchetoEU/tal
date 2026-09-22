local fs --[[= require "std.os.fs"]];
local errors = require "std.errors";
local error = errors.throw;
local require_alt = require;

local path = {
	sep = ".",
	rep = require "std.path".sep,
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
function path.override(...)
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
--- Like lua's searchpath algorithm, but extended to replace @ with a list of roots
--- (useful for a more ergonomic path specification API)
--- @generic T
--- @param name string
--- @param p string
--- @param sep? string
--- @param rep? string
--- @param roots? string[]
--- @param func? fun(p: string): T
--- @return string filename
--- @return T data
--- @overload fun(name: string, p: string, sep?: string, rep?: string, roots?: string[]): string
function path.search(name, p, sep, rep, roots, func)
	if not func then
		function func(p)
			fs = fs or require_alt "std.os.fs";
			local stat, err = fs.stat(p);
			if not stat then error(err .. ", stat " .. p) end
		end
	end

	local errs = {};

	for part in p:gmatch "[^;]+" do
		local real_path = part:gsub("%?", function () return (name:gsub("%" .. (sep or path.sep), rep or path.rep)) end);

		if real_path:find "@" then
			if roots then
				for i = 1, #roots do
					local realer_path = real_path:gsub("@", roots[i]);
					local ok, res = pcall(func, realer_path);
					if ok then return realer_path, res end
					table.insert(errs, res);
				end
			end
		else
			local ok, res = pcall(func, real_path);
			if ok then return real_path, res end
			table.insert(errs, res);
		end
	end

	if #errs == 0 then
		error "path string is empty";
	else
		error(errors.aggr(errs));
	end
end

return path;

require "std.basic.string";

local package = {
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
function package.override(...)
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
--- @param path string
--- @param sep? string
--- @param rep? string
--- @param roots? string[]
--- @param func? fun(path: string): T?, string?
--- @return T? filename
--- @return string? errmsg
function package.search(name, path, sep, rep, roots, func)
	if not func then
		function func(path)
			local f = io.open(path, "r");
			if f then
				f:close();
				return path;
			end

			return nil, "\tno file '" .. path .. "'";
		end
	end

	local lines = {};

	for _, part in path:split ";" do
		local real_path = part:gsub("%?", function () return (name:gsub("%" .. (sep or package.sep), rep or package.rep)) end);

		if real_path:find "@" then
			if roots then
				for i = 1, #roots do
					local res, err = func(real_path:gsub("@", roots[i]));
					if res then return res end
					if err then table.insert(lines, err) end
				end
			end
		else
			local res, err = func(real_path);
			if res then return res end
			if err then table.insert(lines, err) end
		end
	end

	return nil, table.concat(lines, "\n");
end

return package;

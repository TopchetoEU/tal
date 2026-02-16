---@diagnostic disable: cast-local-type
local path = setmetatable({}, { __index = require "std.path._base" });

---@param ... string
---@return string[] parts
---@return integer? back_n
---@return boolean dir
function path:split(...)
	--- @type integer | nil
	local back_n = 0;
	--- @type string[]
	local res = {};
	local dir = false;
	local start_i = 1;

	if ... and (...):find "^/" then
		back_n = nil;
		dir = true;
		start_i = 2;
	end

	for j = 1, select("#", ...) do
		local p = select(j, ...);

		if p ~= nil then
			for part in p:gmatch("[^/]+", start_i) do
				if part == ".." then
					if #res == 0 then
						back_n = back_n and back_n + 1;
					else
						res[#res] = nil;
					end
				else
					if part ~= "." and part ~= "" then
						res[#res + 1] = part;
					end
				end
			end

			dir = p:find "/$" ~= nil;
			start_i = 1;
		end
	end

	return res, back_n, dir;
end

---@param parts array<string>
---@param i integer?
---@param dir boolean | "all"
function path:stringify(parts, i, dir)
	if #parts == 0 then
		if i == nil then
			return dir and "/" or "/.";
		elseif i == 0 then
			return dir and "./" or "";
		else
			local res = (".."):rep(i, "/");
			return dir and res .. "/" or res;
		end
	end

	local res = i and ("../"):rep(i) or "/";
	local str = table.concat(parts, "/");

	if dir then
		return res .. str .. "/";
	else
		return res .. str;
	end
end

return path;

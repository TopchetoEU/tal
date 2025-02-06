---@diagnostic disable: cast-local-type
local exports = {};

---@param ... string
---@return array<string> parts
---@return integer? i
---@return boolean dir
function exports.split(...)
	--- @type integer | nil
	local i = 0;
	--- @type string[]
	local res = {};
	local dir = false;

	local _, start = (... or ""):find("^/+");
	if start == nil then
		start = 1;
	else
		i = nil;
		dir = true;
	end

	for i = 1, select("#", ...) do
		local p = select(i, ...);

		if p ~= nil then
			for part, slashes in p:gmatch("([^/]+)(/*)", start) do
				dir = #slashes > 0;
				if part == ".." then
					if #res == 0 then
						if i ~= nil then
							i = i + 1;
						end
					else
						res[#res] = nil;
					end
				elseif part ~= "." and part ~= "" then
					res[#res + 1] = part;
				end
			end
		end
	end

	return res, i, dir;
end

---@param parts array<string>
---@param i integer?
---@param dir boolean | "all"
function exports.stringify(parts, i, dir)
	local a = table.concat(parts, "/");

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

	if dir then
		return res .. a .. "/";
	else
		return res .. a;
	end
end

---@param ... string
---@return string path
---@return boolean dir
function exports.join(...)
	local parts, i, dir = exports.split(...);
	return exports.stringify(parts, i, dir), dir;
end

---@param ... string
---@return string
function exports.join_dir(...)
	local p, i = exports.split(...);
	return exports.stringify(p, i, true);
end
---@param ... string
---@return string
function exports.join_file(...)
	local p, i = exports.split(...);
	return exports.stringify(p, i, false);
end
---@param p string
---@return boolean
function exports.is_dir(p)
	return p:match "/$" ~= nil;
end

---@param ... string
---@return string
---@return boolean dir
function exports.chroot(...)
	local parts, i, dir = exports.split((...));

	for i = 2, select("#", ...) do
		local new_parts, _, new_dir = exports.split((select(i, ...)));
		dir = new_dir;

		for j = 1, #new_parts do
			parts[#parts + 1] = new_parts[j];
		end
	end

	return exports.stringify(parts, i, dir), dir;
end

---@param ... string
---@return string
function exports.cwd(...)
	local parts, i, dir = exports.split((...));

	for i = 2, select("#", ...) do
		local new_parts, new_i, new_dir = exports.split((select(i, ...)));
		dir = new_dir;

		if new_i == nil then
			parts = new_parts;
			i = nil;
		else
			for _ = 1, new_i do
				parts[#parts] = nil;
			end

			if new_parts ~= nil then
				local offset = parts and #parts or 0;
				for i = 1, #new_parts do
					parts[i + offset] = new_parts[i];
				end
			end
		end
	end

	return exports.stringify(parts, i, dir);
end

---@param ... string
---@return string
function exports.dirname(...)
	local parts, i = exports.split(...);
	parts[#parts] = nil;
	return exports.stringify(parts, i, true);
end

---@param ... string
---@return string
function exports.filename(...)
	return table.remove(exports.split(...)) or "";
end

return exports;

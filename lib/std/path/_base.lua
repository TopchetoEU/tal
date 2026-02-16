--- @diagnostic disable: cast-local-type
local path = {};

---@param ... string
---@return string path
---@return boolean dir
function path:join(...)
	local parts, i, dir = self:split(...);
	return self:stringify(parts, i, dir), dir;
end

---@param ... string
---@return string
function path:join_dir(...)
	local p, i = self:split(...);
	return self:stringify(p, i, true);
end
---@param ... string
---@return string
function path:join_file(...)
	local p, i = self:split(...);
	return self:stringify(p, i, false);
end
---@param ... string
---@return boolean
function path:is_dir(...)
	local parts, i, dir = self:split(...);
	return dir;
end

---@param ... string
---@return string
---@return boolean dir
function path:chroot(...)
	local parts, i, dir = self:split((...));

	for i = 2, select("#", ...) do
		local new_parts, _, new_dir = self:split((select(i, ...)));
		dir = new_dir;

		for j = 1, #new_parts do
			parts[#parts + 1] = new_parts[j];
		end
	end

	return self:stringify(parts, i, dir), dir;
end

---@param ... string
---@return string
function path:cwd(...)
	local parts, back_i, dir = {}, 0, false;

	for i = 1, select("#", ...) do
		local new_parts, new_back_i, new_dir = self:split((select(i, ...)));
		dir = new_dir;

		if type(new_back_i) == "number" then
			for _ = 1, new_back_i do
				table.remove(parts);
			end

			if new_parts ~= nil then
				table.move(new_parts, 1, #new_parts, #parts + 1, parts);
			end
		else
			parts = new_parts;
			back_i = new_back_i;
		end
	end

	return self:stringify(parts, back_i, dir);
end

---@param ... string
---@return string
function path:dirname(...)
	local parts, i = self:split(...);
	table.remove(parts);
	return self:stringify(parts, i, true);
end

---@param ... string
---@return string
function path:filename(...)
	return table.remove(self:split(...)) or "";
end

return path;

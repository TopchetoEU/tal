--- @diagnostic disable: cast-local-type
local path_base = {};

--- @alias std.path.split fun(...: string): string[], integer | string?, boolean
--- @alias std.path.stringify fun(parts: string[], back_i: integer | string?, dir: boolean | "all"): string

--- @param split std.path.split
--- @param stringify std.path.stringify
--- @param ... string
--- @return string path
--- @return boolean dir
function path_base.join(split, stringify, ...)
	local parts, i, dir = split(...);
	return stringify(parts, i, dir), dir;
end

--- @param split std.path.split
--- @param stringify std.path.stringify
--- @param ... string
--- @return string
function path_base.join_dir(split, stringify, ...)
	local p, i = split(...);
	return stringify(p, i, true);
end
--- @param split std.path.split
--- @param stringify std.path.stringify
--- @param ... string
--- @return string
function path_base.join_file(split, stringify, ...)
	local p, i = split(...);
	return stringify(p, i, false);
end
--- @param split std.path.split
--- @param ... string
--- @return boolean
function path_base.is_dir(split, ...)
	local parts, i, dir = split(...);
	return dir;
end

--- @param split std.path.split
--- @param stringify std.path.stringify
--- @param ... string
--- @return string
--- @return boolean dir
function path_base.chroot(split, stringify, ...)
	local parts, i, dir = split((...));

	for i = 2, select("#", ...) do
		local new_parts, _, new_dir = split((select(i, ...)));
		dir = new_dir;

		for j = 1, #new_parts do
			parts[#parts + 1] = new_parts[j];
		end
	end

	return stringify(parts, i, dir), dir;
end

--- @param split std.path.split
--- @param stringify std.path.stringify
--- @param ... string
--- @return string
function path_base.cwd(split, stringify, ...)
	local parts, back_i, dir = {}, 0, false;

	for i = 1, select("#", ...) do
		local new_parts, new_back_i, new_dir = split((select(i, ...)));
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

	return stringify(parts, back_i, dir);
end


--- For two absolute paths, returns the relative path, that when joined with the first, yields the second
--- If the first or second path is relative, returns the second path
--- For DOS paths, if the drive of the second path differs from the one in the first, the second path is returned. Otherwise, one of the defined roots is taken
---
--- This is usually used to convert an absolute path to a relative path, although there are cases in which an absolute path *may* be returned
--- @param split std.path.split
--- @param stringify std.path.stringify
--- @param src string From where to begin travsersing
--- @param dst string Where to end the travsersal
--- @return string
function path_base.diff(split, stringify, src, dst)
	local src_parts, src_i, src_dir = split(src);
	local dst_parts, dst_i, dst_dir = split(dst);

	if type(src_i) == "number" or type(dst_i) == "number" then
		return stringify(dst_parts, dst_i, dst_dir);
	end

	if src_i and dst_i and src_i ~= dst_i then
		return stringify(dst_parts, dst_i, dst_dir);
	end

	local common_n = 0;
	while common_n <= #src_parts and common_n <= #dst_parts do
		common_n = common_n + 1;
		if src_parts[common_n] ~= dst_parts[common_n] then break end
	end

	local res_i = math.max(#src_parts - common_n, 0);
	local res_parts = {};

	for j = common_n, #dst_parts do
		table.insert(res_parts, dst_parts[j]);
	end

	return stringify(res_parts, res_i, dst_dir);
end

--- @param split std.path.split
--- @param stringify std.path.stringify
--- @param ... string
--- @return string
function path_base.dirname(split, stringify, ...)
	local parts, i = split(...);
	table.remove(parts);
	return stringify(parts, i, true);
end

--- @param split std.path.split
--- @param ... string
--- @return string
function path_base.filename(split, ...)
	return table.remove((split(...))) or "";
end

return path_base;

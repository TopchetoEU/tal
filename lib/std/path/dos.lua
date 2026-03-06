local _base = require "std.path._base";

---@diagnostic disable: cast-local-type
local dos_path = {};

local function split_init(first)
	-- TODO: This is incorrect but i literally cannot be bothered with full support
	-- Will be unsafe. Use linux god damn it
	local special = first:match "^([\\/][\\/][^\\/]+[\\/]+[^\\/]+)[\\/]*";
	if special then
		return special:gsub("/", "\\") .. "\\", #special + 1;
	end

	if first:match "^[\\/]" then
		return "\\", 2;
	end

	local drive = first:match "^([A-Za-z]:)[\\/]*";
	if drive then
		return drive:upper() .. "\\", #drive + 2;
	end

	return 0, 1;
end

dos_path.sep = "\\";

---@param ... string
---@return string[] parts
---@return integer | string back_n
---@return boolean dir
function dos_path.split(...)
	--- @type integer | string
		local back_n = 0;
	--- @type string[]
	local res = {};
	local dir = false;
	local start_i = 1;

	-- DOS-like paths are significantly more shitty, so we have multiple roots
	-- We "cheat" by setting 'back_n' to a string, which is then detected by 'stringify'
	if ... then
		local first = ...;

		if first:match "^[\\/][\\/][%.%?][\\/]*" then
			-- Might not be what you expect, but windows uses \\?\ and \\.\ verbatim, so we should preserve these
			return { table.concat { (...):sub(5), select(2, ...) } }, first:sub(1, 3) .. "\\", false;
		end

		back_n, start_i = split_init(first);
	end

	for j = 1, select("#", ...) do
		--- @type string
		local p = select(j, ...);

		if p ~= nil then
			local part;

			while true do
				part, start_i = p:match("([^\\/]+)/*()", start_i);
				if not part then break end

				if part == ".." then
					if #res == 0 then
						if type(back_n) == "number" then
							back_n = back_n + 1;
						end
					else
						table.remove(res);
					end
				else
					if part ~= "." and part ~= "" then
						table.insert(res, part);
					end
				end
			end

			dir = p:find "[\\/]$" ~= nil;
			start_i = 1;
		end
	end

	return res, back_n, dir;
end
---@param parts string[]
---@param back_i integer | string
---@param dir boolean | "all"
function dos_path.stringify(parts, back_i, dir)
	if #parts == 0 then
		if type(back_i) == "string" then
			return dir and back_i or (back_i .. ".");
		elseif back_i == 0 then
			return dir and ".\\" or "";
		else
			local res = (".."):rep(back_i, "\\");
			return dir and res .. "\\" or res;
		end
	end

	if type(back_i) == "number" then
		back_i = ("..\\"):rep(back_i);
	end
	local str = table.concat(parts, "\\");

	if dir then
		return back_i .. str .. "\\";
	else
		return back_i .. str;
	end
end

function dos_path.join(...)
	return _base.join(dos_path.split, dos_path.stringify, ...);
end
function dos_path.join_dir(...)
	return _base.join_dir(dos_path.split, dos_path.stringify, ...);
end
function dos_path.join_file(...)
	return _base.join_file(dos_path.split, dos_path.stringify, ...);
end
function dos_path.is_dir(...)
	return _base.is_dir(dos_path.split, ...);
end
function dos_path.chroot(...)
	return _base.safejoin(dos_path.split, dos_path.stringify, ...);
end
function dos_path.cwd(...)
	return _base.cwd(dos_path.split, dos_path.stringify, ...);
end
function dos_path.dirname(...)
	return _base.dirname(dos_path.split, dos_path.stringify, ...);
end
function dos_path.filename(...)
	return _base.filename(dos_path.split, ...);
end

return dos_path;

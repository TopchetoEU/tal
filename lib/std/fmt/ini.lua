local ini = {};

--- @param raw string
--- @param glob_group? boolean = false
function ini.parse(raw, glob_group)
	local lines = {};

	for line in raw:gmatch "[^\n]+" do
		lines[#lines + 1] = line:match "^%s+(.+)%s+$";
	end

	local groups = {};
	local curr_group;

	if glob_group then
		curr_group = {};
		groups[glob_group] = curr_group;
	end

	local line_i = 0;

	for line in raw:gmatch "[^\n]+" do
		line_i = line_i + 1;
		line = line:match "^%s*(.-)%s*$";

		if line ~= "" then
			local group = line:match "^%[%s*(.-)%s*%]$";

			if group ~= nil then
				curr_group = {};
				groups[group] = curr_group;
			elseif curr_group == nil then
				error("line " .. line_i .. ": Unexpected global key");
			else
				local key, value = line:match "^%s*(.-)%s*=%s*(.-)%s*$";
				if key == nil then
					error("line " .. line_i .. ": Unexpected ini syntax");
				end

				curr_group[key] = value;
			end
		end
	end

	return groups;
end

--- @param raw string
function ini.parse_list(raw)
	local res = {};

	for el in raw:split ";%s*" do
		if el ~= "" then
			res[#res + 1] = el;
		end
	end

	return res;
end

return ini;

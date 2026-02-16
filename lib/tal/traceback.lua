return function (level)
	local res = {};

	level = level or 1;
	while true do
		local info = debug.getinfo(level, "Snl");
		if not info then break end

		local curr = "";

		if info.short_src and info.what == "Lua" then
			curr = curr .. "in " .. info.short_src;

			if info.currentline >= 0 then
				curr = curr .. ":" .. info.currentline;
				if info.currentcol then
					curr = curr .. ":" .. info.currentcol;
				end
			end
		end

		if info.name then
			if curr == "" then
				curr = "at " .. info.name;
			else
				curr = curr .. " at " .. info.name;
			end
		end

		if curr == "" then
			table.insert(res, "\t<internal>");
		else
			table.insert(res, "\t" .. curr);
		end
		level = level + 1;
	end

	return table.concat(res, "\n");
end

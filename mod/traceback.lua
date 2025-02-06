return function(i, prefix)
	i = i + 1;
	local lines = array {};

	while true do
		local info = debug.getinfo(i, "Snl");
		if info == nil then break end

		local name = info.name;
		local location = info.short_src;

		if location == "[C]" then
			location = "at <internal>";
		elseif string.find(location, "[string", 1, true) then
			location = "at <string>";
		else
			location = "at " .. location;
		end

		if info.currentline > 0 then
			location = location .. ":" .. info.currentline;
		end

		if name ~= nil then
			lines:push(prefix .. location .. " in " .. name);
		else
			lines:push(prefix .. location);
		end

		i = i + 1
	end

	return lines:join "\n";
end

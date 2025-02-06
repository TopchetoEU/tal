--- @diagnostic disable: duplicate-set-field

return function (glob)
	--- @param self string
	function glob.string:split(sep)
		sep = sep or "";
		local lines = array {};
		local pos = 1;

		if sep == "" then
			for i = 1, #self do
				lines:push(self:sub(1, 1));
			end
		else
			while true do
				local b, e = self:find(sep, pos);

				if not b then
					table.insert(lines, self:sub(pos));
					break;
				else
					table.insert(lines, self:sub(pos, b - 1));
					pos = e + 1;
				end
			end
		end

		return lines;
	end
	--- @param self string
	function glob.string:at(i)
		return self:sub(i, i);
	end
	--- @param self string
	function glob.string:replace_first(old, new)
		local b, e = self:find(old, 1, true);

		if b == nil then
			return self;
		else
			return self:sub(1, b - 1) .. new .. self:sub(e + 1);
		end
	end

	--- @param self string
	function glob.string:quote()
		return ("%q"):format(self);
	end

	--- @param self string
	function glob.string:quotesh()
		return "'" .. self
			:gsub("%*", "\\*")
			:gsub("%?", "\\?")
			:gsub("%~", "\\~")
			:gsub("%$", "\\$")
			:gsub("%&", "\\&")
			:gsub("%|", "\\|")
			:gsub("%;", "\\;")
			:gsub("%<", "\\<")
			:gsub("%>", "\\>")
			:gsub("%(", "\\)")
			:gsub("%[", "\\]")
			:gsub("%{", "\\}")
			:gsub("%%\\", "\\\\")
			:gsub("%\'", "\\\'")
			:gsub("%\"", "\\\"")
			:gsub("%`", "\\`") .. "'";
	end
end

--- @diagnostic disable: duplicate-set-field


--- @param self string
--- @param sep? string
function string:split(sep)
	sep = sep or "";

	--- @param self string
	--- @param i? integer
	local function splitter(self, i)
		if not i or i > #self then return nil end

		local sep_f, sep_l = self:find(sep, i + 1);
		if not sep_f then
			return #self + 1, self:sub(i + 1);
		else
			return sep_l, self:sub(i + 1, sep_f - 1);
		end
	end
	return splitter, self, 0;
end
--- @param self string
function string:at(i)
	return self:sub(i, i);
end

--- @param self string
function string:quote()
	return (("%q"):format(self):gsub("\\\n", "\\n"));
end

--- Might not be safe...
--- @param self string
function string:quotesh()
	return "'" .. self:gsub("[*?~$&|;<>%(%)%[%]%{%}\\\'\"`%z\x01-\x1F]", "\\%1") .. "'";
end

return string;

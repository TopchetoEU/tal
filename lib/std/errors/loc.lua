--- @class std.errors.loc
--- @field row integer
--- @field col? integer
--- @field fname? string
local loc = {};
loc.__index = loc;
loc.__metatable = "std.errors.loc";

function loc:__tostring()
	local res = {};
	if self.fname and (self.fname:sub(1, 1) == "@" or self.fname:sub(1, 1) == "=") then
		table.insert(res, self.fname:sub(2));
	elseif self.fname then
		table.insert(res, self.fname);
	end
	table.insert(res, self.row);
	table.insert(res, self.col);
	return table.concat(res, ":");
end

--- @param row integer
--- @param col? integer
--- @param fname? string
function loc.new(row, col, fname)
	return setmetatable({ row = row, col = col, fname = fname }, loc);
end

return loc;

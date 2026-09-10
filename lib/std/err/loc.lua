--- @class std.err.loc
--- @field row integer
--- @field col? integer
--- @field fname? string
local loc = {};
loc.__index = loc;
loc.__metatable = "std.err.loc";

function loc:__tostring()
	local res = {};
	table.insert(res, self.fname);
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

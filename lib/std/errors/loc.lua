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
--- @param src string
--- @param fname string
--- @param i integer
function loc.from_src(src, fname, i)
	local newl_i = 1;
	local row = 1;
	local j = 1;

	while true do
		local next_newl_i = src:match("\n()", newl_i) --[[@as integer?]];
		if not next_newl_i then break end
		if i < next_newl_i then break end
		row = row + 1;
		newl_i = next_newl_i;
	end

	return loc.new(row, i - newl_i + 1, fname);
end

return loc;

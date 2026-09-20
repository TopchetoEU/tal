--- @class std.errors.aggr: errbox
--- @field children? any[]
local aggr = {};
aggr.__index = aggr;
aggr.__metatable = "std.errors.aggr";

function aggr:__tostring()
	local parts = {};

	for i = 1, #self.children do
		table.insert(parts, tostring(self.children[i]));
	end

	return table.concat(parts, "\n");
end

function aggr:errors()
	return self.children;
end

--- @param errs any[]
function aggr.new(errs)
	return setmetatable({ children = errs }, aggr);
end

return aggr;

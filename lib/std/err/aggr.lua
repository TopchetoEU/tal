local err = require "std.err";

--- @class err.aggr: err
--- @field children? err[]
local aggr = setmetatable({}, err);
aggr.msg = "multiple errors";
aggr.__index = aggr;
aggr.__metatable = "err.aggr";

--- Returns a list of all errors this error represents (recursively)
--- Must not include objects, that only represent the list of actual errors, nor the errors' parents
--- @param dst err[]
--- @return err[]
function aggr:errors(dst)
	return table.move(self.children, 1, #self.children, #dst + 1, dst);
end

--- @param errs err[]
function aggr:new(errs)
	local res = {};

	for i = 1, #errs do
		errs[i]:errors(res);
	end

	return setmetatable({ parent = self, children = res }, aggr);
end
function aggr:find(other)
	for i = 1, #self.children do
		local res = self.children[i]:find(other);
		if res then return res end
	end

	return err.find(self, other);
end

function aggr:__tostring()
	local parts = {};

	for i = 1, #self.children do
		table.insert(parts, tostring(self.children[i]));
	end

	return table.concat(parts, "\n");
end

return aggr;

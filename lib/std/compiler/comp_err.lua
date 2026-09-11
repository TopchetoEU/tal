local err = require "std.err";

--- @class std.compiler.err: err
--- @field loc? std.err.loc
local comp_err = setmetatable({}, err);
comp_err.parent = err.syntax;
comp_err.__index = comp_err;

function comp_err:__tostring()
	local res = "";

	if self.loc then res = res .. tostring(self.loc) end

	if self.msg then
		if res ~= "" then res = res .. ": " end
		res = res .. self.msg;
	end

	return res;
end

--- @param msg string
--- @param loc? std.err.loc
function comp_err:new(msg, loc)
	return setmetatable({ parent = self, msg = msg, loc = loc }, comp_err);
end

return comp_err;

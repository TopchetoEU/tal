--- @class std.errors.syntax
--- @field msg string
--- @field loc? std.errors.loc
local syntax_err = {};
syntax_err.__index = syntax_err;
syntax_err.__metatable = "std.errors.syntax";

function syntax_err:__tostring()
	local res = "";

	if self.loc then res = res .. tostring(self.loc) end

	if self.msg then
		if res ~= "" then res = res .. ": " end
		res = res .. self.msg;
	end

	return res;
end

--- @param msg string
--- @param loc? std.errors.loc
function syntax_err.new(msg, loc)
	return setmetatable({ msg = msg, loc = loc }, syntax_err);
end

return syntax_err;

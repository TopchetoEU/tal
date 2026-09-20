local syntax_err = require "std.errors.syntax_err";
local debug = require "std.basic.debug";
local is = require "std.basic.is";

--- @class std.errors.traced: errbox
--- @field why string
--- @field trace string
--- @field err any
local traced = {};
traced.__index = traced;
traced.__metatable = "std.errors.traced";

function traced:__tostring()
	local msg = tostring(self.err);
	if #msg == 0 then return self.why .. " " .. self.trace end

	return msg .. "\n" .. self.why .. " " .. self.trace;
end
function traced:errors()
	return { self.err };
end

--- @param err any
--- @param why? string
--- @param trace? string | integer
function traced.new(err, why, trace)
	if not why then
		if is(err, "std.errors.traced") then
			why = "rethrow";
		else
			why = "throw";
		end
	end

	if type(trace) == "number" then
		trace = debug.traceback("", trace + 2):sub(2);
	elseif not trace then
		trace = trace or debug.traceback("", 3):sub(2);
	end


	-- TODO: move to syntax error
	if type(err) == "string" then
		local msg = err:match "^[^:]+:%d+: (.*)$";
		if msg then
			err = syntax_err.new(msg);
		else
			err = syntax_err.new(err);
		end
	end

	return setmetatable({ err = err, trace = trace, why = why }, traced);
end

return traced;

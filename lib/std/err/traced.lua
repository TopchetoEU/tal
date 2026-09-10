local err = require "std.err";
local debug = require "std.basic.debug";
local xpcall = xpcall;

--- @class err.traced: err
--- @field trace string
--- @field child err
local traced = setmetatable({}, err);
traced.msg = "traced error";
traced.__index = traced;
traced.__metatable = "err.traced";

--- Returns a list of all errors this error represents (recursively)
--- Must not include objects, that only represent the list of actual errors, nor the errors' parents
--- @param dst err[]
--- @return err[]
function traced:errors(dst)
	table.insert(dst, self.child);
	return dst;
end
--- @param e err
--- @param trace string
function traced:new(e, trace)
	if type(e) == "string" then
		local msg = e:match "^[^:]+:%d+: (.*)$";
		if msg then
			e = err.syntax:new(msg);
		else
			e = err.syntax:new(e);
		end
	end

	return setmetatable({ parent = self, child = e, trace = trace }, traced);
end
function traced:find(other)
	local res = self.child and self.child:find(other);
	if res then return res end

	return err.find(self, other);
end

function traced:__tostring()
	if self.child == traced then
		return tostring(self.child) .. "\nrethrow " .. self.trace;
	end

	local msg = tostring(self.child);
	if #msg == 0 then return self.trace end

	return msg .. "\n" .. self.trace;
end

local function spcall_catch(e)
	if e == "stack overflow" then return e.nostack end
	return traced:new(e, debug.traceback(nil, 2));
end

--- Calls the given function with xpcall and captures a stack trace on an error. It is returned alongside the unmodified error
--- @param f function
function traced.spcall(f, ...)
	return xpcall(f, spcall_catch, ...);
end
--- Calls the given function with xpcall and captures a stack trace on an error. It is returned alongside the unmodified error
--- @param f function
--- @param hnd fun(err: err | string): any, boolean The second boolean return, if true, doesn't emit a stack
function traced.sxpcall(f, hnd, ...)
	return xpcall(f, function (err)
		local err, trace = hnd(err);
		if trace then return err end
		return spcall_catch(err);
	end, ...);
end

return traced;

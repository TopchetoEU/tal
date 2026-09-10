--- @class err
--- @field parent? err
--- @field msg? string
local err = {};
err.__index = err;
err.__metatable = "err";

--- Returns a list of all errors this error represents (recursively)
--- Must not include objects, that only represent the list of actual errors, nor the errors' parents
--- @param dst err[]
--- @return err[]
function err:errors(dst)
	table.insert(dst, self);
	return dst;
end

--- @param msg? string
function err:new(msg)
	return setmetatable({ parent = self, msg = msg }, err);
end
--- @generic T: err
--- @param self any
--- @param other T
--- @return T?
function err:find(other)
	if rawequal(self, other) then return self end
	if type(self) ~= "table" then return false end
	return self.parent and self.parent:find(other);
end

function err:__tostring()
	if self.msg then return self.msg end
	if not self.parent then return "" end
	return tostring(self.parent);
end
function err:__eq(other)
	return self:find(other) ~= nil;
end


--- Class of errors, having special semantic meanings
--- Those generally should be left unreported
err.tag = err:new();
err.cancelled = err.tag:new "cancelled";
err.eof = err.tag:new "eof";

--- Class of errors, caused by bad code
err.bad = err:new();
err.never = err.bad:new "unreachable code reached";
err.notimpl = err.bad:new "not implemented";
err.syntax = err.bad:new "syntax error";

--- Class of errors, caused by non-conforming usage
err.ill = err:new();
err.badarg = err.ill:new "illegal argument";
err.badop = err.ill:new "illegal operation";
err.badaccess = err.ill:new "restricted access";
err.badrange = err.ill:new "out of range";
err.closed = err.ill:new "closed";

--- Class of all other errors, caused neither by bad code, nor bad usage of an API
--- With such errors, we are but victims of the circumstances
--- @class err.env: err
err.env = err:new();
err.nomem = err.env:new "out of memory";
err.nostack = err.env:new "stack overflow";
err.noperm = err.env:new "permission denied";

err.notfound = err.env:new "not found";
err.duplicate = err.env:new "already exists";

err.timeout = err.env:new "timed out";

err.notsupp = err.env:new "not supported";

--- A subset of env errors, relating to I/O errors
err.io = err.env:new();
--- A subset of I/O errors, relating to network errors
err.net = err.io:new();

local error = error;

function err.throw(e)
	return error(e, 0);
end
---@generic T
---@param val? T
---@param ... any
---@return T
---@return any ...
function err.assert(val, ...)
	if not val then
		return err.throw((...));
	end

	return val, ...;
end
return err;

--- @class argp
--- @field noopt boolean If true, treats all arguments as plain arguments, even if prefixed by a dash. false by default
--- @field ddash boolean If true, when -- is encountered sets noopt to true. true by default
--- @field pending string[] A list of single-dash arguments that are yet to be taken by :next()
--- @field currarg? string The name of the argument that is being currently processed. Used for error messages
--- @field i integer
--- @field [integer] string
local argp = {};
argp.__index = argp;

function argp:has()
	return self.i <= #self;
end

--- @return string?
function argp:tryget()
	if self.i > #self then return nil end
	local res = self[self.i];
	return res;
end
function argp:get()
	return (assert(self:tryget(), self.currarg and "expected a value for " .. self.currarg or "expected a value for argument"));
end

function argp:trypop()
	local res = self:get();
	if res then
		self.i = self.i + 1;
	end

	return res;
end
function argp:pop()
	return (assert(self:trypop(), self.currarg and "expected a value for " .. self.currarg or "expected a value for argument"));
end

--- Returns the remainder of the arguments
function argp:rest()
	return table.unpack(self, self.i);
end
--- Returns the remainder of the arguments
function argp:poprest()
	local i = self.i;
	self.i = #self + 1;
	return table.unpack(self, i);
end

--- @return string? arg
--- @return boolean? isopt
function argp:next()
	local pending = table.remove(self.pending, 1);
	if pending then
		self.currarg = pending;
		return pending, true;
	end

	if not self:has() then return nil end

	local arg = self:pop();
	if self.noopt then
		self.currarg = nil;
		return arg, false;
	end

	if self.ddash and arg == "--" then
		self.noopt = true;
		return self:next();
	end

	if arg:find "^%-%-" then
		self.currarg = arg;
		return arg, true;
	elseif arg:find "^%-." then
		for c in arg:sub(2):gmatch "." do
			table.insert(self.pending, "-" .. c);
		end

		return self:next();
	else
		self.currarg = nil;
		return arg, false;
	end
end

function argp:iter()
	return self.next, self;
end

--- @param ... string
function argp.new(...)
	return setmetatable({ pending = {}, ddash = true, noopt = false, i = 1, ... }, argp);
end

return argp;

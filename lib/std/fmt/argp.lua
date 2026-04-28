local read_args;

--- @class argp
--- @field i integer
--- @field [integer] string
local argp = {};
argp.__index = argp;

function argp:has()
	return self.i <= #self;
end
--- @return string?
function argp:get()
	if self.i > #self then return nil end
	local res = self[self.i];
	return res;
end
function argp:pop()
	local res = self:get();
	if res then
		self.i = self.i + 1;
	end

	return res;
end
--- @param msg string
function argp:aget(msg)
	local res = self:get();
	assert(res, msg);
	return res;
end
--- @param msg string
function argp:apop(msg)
	local res = self:pop();
	assert(res, msg);
	return res;
end
--- @param arg string
--- @return (fun(): string?)?
function argp:opt(arg)
	if arg:find "^%-%-" or arg == "-" then
		local done = false;
		return function ()
			if done then return nil end
			done = true;
			return arg;
		end
	elseif arg:find "^%-" then
		local iter = arg:sub(2):gmatch ".";
		return function ()
			local res = iter();
			if not res then return nil end
			return "-" .. res;
		end
	else
		return nil;
	end
end
function argp:popopt()
	local arg = self:get();
	if not arg then return false end

	local res = self:opt(arg);
	if res then self:pop() end

	return res;
end

--- @return argp
function argp:rest()
	return argp.new(table.unpack(self, self.i));
end
--- @return argp
function argp:poprest()
	local res = self:rest();
	self.i = #self + 1;
	return res;
end

--- @param ... string
function argp.new(...)
	return setmetatable({ i = 1, ... }, argp);
end

return argp;

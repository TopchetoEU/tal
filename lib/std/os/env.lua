local impl = require "impl";
local sig = require "std.sig";
local env = {};

--- @param key string
function env.get(key)
	sig.str(key, "key");
	return impl:env_get(key)
end
--- @param key string
--- @param val string
function env.set(key, val)
	sig.str(key, "key");
	sig.str(val, "val");
	return impl:env_set(key, val)
end
--- @return fun(self: _impl.iterenv): string?, string?
--- @return _impl.iterenv
function env.iter()
	return function (self)
		local res = self:next();
		if not res then return end

		local k, v = res:match "^(.-)=(.*)$";
		if k then
			return k, v;
		else
			return res;
		end
	end, impl:iterenv();
end

--- A map-like representation of the environment
env.map = setmetatable({}, {
	__index = function (self, k)
		return env.get(k);
	end,
	__newindex = function (self, k, v)
		env.set(k, v);
	end,
	__pairs = function (t)
		return env.iter();
	end,
	__metatable = "std.env.map",
});

return env;

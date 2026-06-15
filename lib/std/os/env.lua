local impl = require "impl";
local sig = require "std.sig";
local env = {};

--- @param key string
function env.get(key)
	sig.str(key, "key");
	return impl:getenv(key)
end
--- @param key string
--- @param val string
function env.set(key, val)
	sig.str(key, "key");
	sig.str(val, "val");
	return impl:setenv(key, val)
end
--- @return fun(): string?, string?
function env.iter()
	local iter = impl:iterenv();

	return function ()
		local res = iter:next();
		if not res then
			iter:close();
			return;
		end

		local k, v = res:match "^(.-)=(.*)$";
		if k then
			return k, v;
		else
			return res;
		end
	end
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

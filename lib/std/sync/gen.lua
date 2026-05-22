local loop = require "std.loop";
local pipe = require "std.sync.pipe";

local i = 0;

--- @generic T1, T2, T3, T4, T5, T6, T7, T8, T9, T10
--- @param fun fun(yield: fun(_1?: T1, _2?: T2, _3?: T3, _4?: T4, _5?: T5, _6?: T6, _7?: T7, _8?: T8, _9?: T9, _10?: T10))
--- @return fun(): T1, T2, T3, T4, T5, T6, T7, T8, T9, T10
return function (fun)
	local p = pipe.new();

	local function yield(...)
		return p:write(...);
	end

	local th = loop.fork(function ()
		return yield(fun(yield));
	end);
	i += 1;
	loop.name(th, "Generator #" .. i);
	return function () return p:read() end
end

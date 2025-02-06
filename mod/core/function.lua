local unpack = unpack or table.unpack;

--- @class functions
local functions = {};
functions.__index = functions;

--- Constructs a function, such that it calls the first function with the passed arguments,
--- the second function with the return of the first, and so on. The return value of the last function is returned
---
--- In short, does the following, if the passed functions are a, b and c: return c(b(a(...)))
---
--- Sometimes less cumbersome to write (a | b | c | d)(args...) than d(c(b(a(args...))))
--- @param self function
function functions:pipe(...)
	if ... == nil then
		return self;
	else
		local next = ...;

		return functions.pipe(function (...)
			return next(self(...));
		end, select(2, ...));
	end
end
function functions:apply(args)
	return self(unpack(args));
end
--- Constructs a function, such that it calls the first function with the passed arguments,
--- the second function with the return of the first, and so on. The return value of the last function is returned
---
--- In short, does the following, if the passed functions are a, b and c: return c(b(a(...)))
---
--- Sometimes less cumbersome to write (a | b | c | d)(args...) than d(c(b(a(args...))))
--- @param self function
function functions:pcall(...)
	return pcall(self, ...);
end
--- Calls pipe with a and b; Alternative syntax for older Lua installation
function functions.__sub(a, b)
	return functions.pipe(a, b);
end
--- Calls pipe with a and b
function functions.__bor(a, b)
	return functions.pipe(a, b);
end


return function (glob)
	-- It's not vital to have this metatable, so we will just try our very best
	if debug then
		debug.setmetatable(debug.setmetatable, functions);
	end

	glob.functions = functions;
	glob["function"] = functions;
end


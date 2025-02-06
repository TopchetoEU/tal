--- @meta

--- @class functionlib
functions = {};

--- Constructs a function, such that it calls the first function with the passed arguments,
--- the second function with the return of the first, and so on. The return value of the last function is returned
---
--- In short, does the following, if the passed functions are a, b and c: return c(b(a(...)))
---
--- Sometimes less cumbersome to write (a | b | c | d)(args...) than d(c(b(a(args...))))
--- @param self function
function functions:pipe(...) end
function functions:apply(args) end
--- Constructs a function, such that it calls the first function with the passed arguments,
--- the second function with the return of the first, and so on. The return value of the last function is returned
---
--- In short, does the following, if the passed functions are a, b and c: return c(b(a(...)))
---
--- Sometimes less cumbersome to write (a | b | c | d)(args...) than d(c(b(a(args...))))
--- @param self function
function functions:pcall(...) end
--- Calls pipe with a and b; Alternative syntax for older Lua installations
function functions.__sub(a, b) end
--- Calls pipe with a and b
function functions.__bor(a, b) end

--- @class function: functionlib
--- @class functionlib
local functionlib = {};
functionlib.__metatable = "function";

debug.setmetatable(print, functionlib);

return functionlib;

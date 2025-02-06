--- @meta

box = table.pack;
unbox = table.unpack;
exit = os.exit;
promise = require "promise";

--- @param box table
--- @param s? number
--- @param e? number
--- @return table
function rebox(box, s, e) end

--- Concatenates the arguments to a string
--- @return string
function str(...) end

---@generic T
---@param obj { [integer]: T }
---@return fun(): T
function iterate(obj) end

--- @class nil: nillib
--- @class nillib
local nillib = {};
nillib.__metatable = "nil";

debug.setmetatable(nil, nillib);

return nillib;

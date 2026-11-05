--- @class debug.registry
local registry = debug.getregistry();

--- @type table<thread, function>
registry._HOOKS = {};

local has_libhook, libhook = pcall(require, "nat.libhook");

local function sethook(en, )

end

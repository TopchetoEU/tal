_TAL = "0.1.1-alpha";
_G._ENV = _G;

-- First, we import package to load all further packages using our require functions
package = require "std.package";
-- Then, we import our ffi, to add our custom load function (without it, everything breaks)
require "nat.ffi";

require "std.printing";
require "std.string";
local err = require "std.error";

debug = require "std.debug";
io = require "std.io";

table.clear = require "table.clear";
table.new = require "table.new";
table.unpack = unpack or table.unpack;

load = require "std.compiler.loading".load;
exit = os.exit;
require = package.require;
unpack = table.unpack;
error = err.error;
assert = err.assert;
throw = err.throw;

return _G;

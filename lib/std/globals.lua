_TAL = "0.2.1-alpha";
_G._ENV = _G;

-- First, we import package to load all further packages using our require functions
package = require "std.package";
-- Then, we import our ffi, to add our custom load function (without it, everything breaks)
require "nat.ffi";

local printing = require "std.printing";
local err = require "std.error";

debug = require "std.debug";
io = require "std.io";
jit = require "jit";
string = require "std.string";

table.clear = require "table.clear";
table.new = require "table.new";
table.unpack = unpack or table.unpack;

load = require "std.compiler.loading".load;
function loadfile(filename, mode, env)
	return load(io.lines(filename, "c"), "@" .. filename, mode, env);
end

pprint = printing.pprint;

exit = os.exit;
require = package.require;
unpack = table.unpack;

error = err.error;
assert = err.assert;
throw = err.throw;

ierror = err.ierror;
iassert = err.iassert;

spcall = err.spcall;

return _G;

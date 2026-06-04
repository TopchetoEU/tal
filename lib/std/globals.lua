_TAL = "0.2.9-alpha";
_G._ENV = _G;

-- First, we import package to load all further packages using our require functions
package = require "std.package";
package.env = _G;
require = package.require;

-- Then, we import our ffi, to add our custom load function (without it, everything breaks)
require "nat.ffi";

local printing = require "std.printing";
local err = require "std.errors";

load = require "std.compiler.load";

newproxy = newproxy;
getfenv = getfenv;
setfenv = setfenv;

pprint = printing.pprint;
eprint = printing.eprint;

exit = os.exit;
require = package.require;
unpack = table.unpack;

error = err.error;
assert = err.assert;
throw = err.throw;

ierror = err.ierror;
iassert = err.iassert;

spcall = err.spcall;
sxpcall = err.sxpcall;
srethrow = err.srethrow;

debug = require "std.debug";
io = require "std.io";
jit = require "jit";
bit = require "bit";
string = require "std.string";

table.clear = require "table.clear";
table.new = require "table.new";
table.unpack = unpack or table.unpack;

function loadfile(filename, mode, env)
	return load(io.lines(filename, "c"), "@" .. filename, mode, env);
end
function loadstring(str, mode, env)
	return load(str, str, mode, env);
end
function dofile(filename, mode, env)
	local res = assert(loadfile(filename, mode, env));
	return res();
end

return _G;

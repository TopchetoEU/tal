_TAL = "0.4.0-beta";
_G._ENV = _G;

-- First, we import package to load all further packages using our require functions
package = require "std.package";
package.env = _G;
require = package.require;

-- Then, we import our ffi, to add our custom load function (without it, everything breaks)
require "nat.ffi";

local printing = require "std.printing";
local errs = require "std.errors";

errors = errs;
load = require "std.compiler.load";
is = require "std.basic.is";

newproxy = newproxy;
getfenv = getfenv;
setfenv = setfenv;

pprint = printing.pprint;
eprint = printing.eprint;

exit = os.exit;
require = package.require;
--- Use this when untying recursive loops
--- Helps out mklua
require_alt = package.require;
unpack = table.unpack;

assert = errs.assert;
error = errs.throw;
throw = errs.throw;

spcall = errors.spcall;
sxpcall = errors.sxpcall;

debug = require "std.basic.debug";
table = require "std.basic.table";
io = require "std.io";
os = require "std.os";
jit = require "jit";
bit = require "bit";
string = require "std.basic.string";
number = require "std.basic.number";
boolean = require "std.basic.boolean";
coroutine = require "std.basic.coroutine";
require "std.basic.nil";
require "std.basic.function";

package.loaded.io = io;
package.loaded.os = os;
package.loaded.debug = debug;
package.loaded.string = string;
package.loaded.coroutine = coroutine;
package.loaded.table = table;

function loadfile(filename, mode, env)
	return load(io.lines(filename, "c"), "@" .. filename, mode, env);
end
function loadstring(str, mode, env)
	return load(str, str, mode, env);
end
function dofile(filename, mode, env)
	return errs.assert(loadfile(filename, mode, env))();
end

return _G;

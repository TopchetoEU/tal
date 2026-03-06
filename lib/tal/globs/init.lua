_TAL = "0.0.1-alpha";
_ENV = _G;

exit = os.exit;
load = require "tal.compiler.loading".load;

require "std.printing";
require "std.string";
require "nat.ffi";

require "tal.globs.package";
require "tal.globs.errors";


table.clear = require "table.clear";
table.new = require "table.new";
debug = require "tal.globs.debug";
io = require "std.io";

package.root = ".";

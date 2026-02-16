_TAL = "0.0.1-alpha";
_ENV = _G;

exit = os.exit;

require "std.printing";
require "std.string";
require "nat.ffi";
require "tal.globs.loading";
require "tal.globs.errors";

table.clear = require "table.clear";
table.new = require "table.new";
debug = require "tal.globs.debug";
io = require "std.io";

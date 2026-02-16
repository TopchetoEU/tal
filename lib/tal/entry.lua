require "nat.ffi";
require "tal.globs.errors";
local ev = require "nat.libev";
local loop = require "tal.loop";
debug = require "tal.globs.debug";

local has_dbg, debugger = pcall(require, "lldebugger");
if has_dbg then debugger.start() end

return function (module, ...)
	return assert(loop.run(ev.new(), function (...)
		local env = setmetatable({}, { __index = _G });
		env._G = env;
		env._ENV = env;
		setfenv(0, env);

		require "std.printing";
		require "tal.globs";
		local entry = require(module);

		if type(entry) == "table" and type(entry.main) == "function" then
			return entry.main(...);
		else
			return entry(...);
		end
	end, ...));
end

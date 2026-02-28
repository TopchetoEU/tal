require "nat.ffi";
require "tal.globs.errors";
require "std.printing";
local ev = require "nat.libev";
local loop = require "tal.loop";
debug = require "tal.globs.debug";

local has_dbg, dbg = pcall(require, "lldebugger");
if has_dbg then dbg.start() end

return function (...)
	return assert(loop.run(ev.new(), function (...)
		local env = setmetatable({}, { __index = _G });
		env._G = env;
		env._ENV = env;
		setfenv(0, env);

		require "tal.globs";
		local entry = require "tal.cli";

		if type(entry) == "table" then
			if type(entry.__main) == "function" then
				return entry.main(...);
			elseif type(entry.main) == "function" then
				return entry.main(...);
			end
		end

		return entry(...);
	end, ...));
end

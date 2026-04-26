require "std.error";
require "nat.ffi";

local has_dbg, dbg = pcall(require, "lldebugger");
if has_dbg then dbg.start() end

return function (...)
	local env = setmetatable({}, { __index = _G });
	env._G = env;
	env._ENV = env;
	setfenv(0, env);

	require "tal.globs";
	local loop = require "std.loop";
	local entry = require "tal.cli";

	loop.name(coroutine.running(), "Main thread");

	if type(entry) == "table" then
		if type(entry.__main) == "function" then
			entry.main(...);
		elseif type(entry.main) == "function" then
			entry.main(...);
		end
	else
		entry(...);
	end

	return assert(loop.run());
end

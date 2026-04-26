local has_dbg, dbg = pcall(require, "lldebugger");
if has_dbg then
	debug = require "std.debug";
	dbg.start();
end

return function (...)
	local env = setmetatable({}, { __index = _G });
	env._G = env;
	env._ENV = env;
	setfenv(0, env);

	require "std.globals";
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

	assert(loop.run());

	-- Run one more time to collect __gc tables
	collectgarbage();
	assert(loop.run());
end

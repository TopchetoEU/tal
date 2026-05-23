local has_dbg, dbg = pcall(require, "lldebugger");

return function (entry_mod, ...)
	require "ffi";
	-- Breaks stuff if called twice
	package.preload.ffi = nil;
	local oldenv = getfenv();

	if has_dbg then
		oldenv.debug = require "std.debug";
		local old_tb = debug.traceback;
		dbg.start();
		oldenv.debug.traceback = old_tb;
	end

	local stderr = io.stderr;

	local env = setmetatable({}, { __index = oldenv, __metatable = "_G" });
	env._G = env;
	env._ENV = env;
	-- setfenv(0, _G);
	setfenv(1, env);

	local ok, err, trace = require "std.errors".spcall(function (...)
		local package = require "std.package";
		require = package.require;
		package.env = env;

		require "std.globals";
		local loop = require "std.loop";
		local fs = require "std.io.fs";
		local ffi = require "nat.ffi";

		package.roots:add(fs.path "cwd");
		ffi.roots:add(fs.path "cwd");

		local entry = require(entry_mod);

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

		local ok, err, trace = loop.run();
		if not ok then srethrow(err, trace) end

		-- Run one more time to collect __gc tables
		collectgarbage();

		local ok, err, trace = loop.run();
		if not ok then srethrow(err, trace) end
	end, ...);

	if not ok then env.eprint(err, trace, nil, function (...)
		return stderr:write(...);
	end) end
end

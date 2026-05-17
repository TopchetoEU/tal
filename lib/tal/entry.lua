#!/bin/env luajit
local has_dbg, dbg = pcall(require, "lldebugger");

return function (entry_mod, ...)
	-- Breaks stuff if called twice
	package.preload.ffi = nil;

	local old_env = _G;
	local env = setmetatable({}, { __index = _G });
	env._G = env;
	env._ENV = env;
	setfenv(0, env);
	setfenv(1, env);

	local ok, err = xpcall(function (...)
		local require = require "std.package".require;

		if has_dbg then
			old_env.debug = require "std.debug";
			dbg.start();
		end

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

		assert(loop.run());

		-- Run one more time to collect __gc tables
		collectgarbage();
		assert(loop.run());
	end, require "std.debug".traceback, ...);

	if not ok then print("Uncaught error: " .. err) end
end

local stderr = io.stderr;
local has_dbg, dbg = pcall(require, "lldebugger");
local printing = require "std.printing";

return function (entry_mod, ...)
	require "ffi";
	-- Breaks stuff if called twice
	package.preload.ffi = nil;
	local oldenv = getfenv();

	if has_dbg then
		oldenv.debug = require "std.basic.debug";
		local old_tb = debug.traceback;
		dbg.start();
		oldenv.debug.traceback = old_tb;
	end

	local env = setmetatable({}, { __index = oldenv });
	env._G = env;
	env._ENV = env;
	-- setfenv(0, _G);
	setfenv(1, env);

	local err = require "std.err";
	local traced = require "std.err.traced";

	local ok, e = traced.spcall(function (...)
		local package = require "std.package";
		require = package.require;
		package.env = env;

		require "std.basic.globals";
		local loop = require "std.loop";
		local fs = require "std.os.fs";
		local ffi = require "nat.ffi";

		package.roots:insert(fs.path "cwd");
		ffi.roots:insert(fs.path "cwd");

		local entry = require(entry_mod);

		coroutine.running():name "Main thread";

		if type(entry) == "table" then
			if type(entry.__main) == "function" then
				entry.main(...);
			elseif type(entry.main) == "function" then
				entry.main(...);
			end
		else
			entry(...);
		end

		local ok, e = loop.run();
		if not ok then err.throw(e) end

		-- Run one more time to collect __gc tables
		collectgarbage();

		local ok, e = loop.run();
		if not ok then err.throw(e) end
	end, ...);

	if not ok then
		printing.eprint(tostring(e), nil, function (line) return stderr:write(line, "\n") end);
	end
end

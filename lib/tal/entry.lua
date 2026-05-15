#!/bin/env luajit
local has_dbg, dbg = pcall(require, "lldebugger");

return function (entry_mod, ...)
	package.path = package.path:match "^;*(.-);*$";

	local old_env = _G;
	local env = setmetatable({}, { __index = _G });
	env._G = env;
	env._ENV = env;
	setfenv(0, env);
	setfenv(1, env);

	-- The section in do-end is terrible and must be deleted on first notice.
	-- TODO: delete this asap-ably
	if not package.loaded["std.path"] then
		local root = arg[0]:match "^(.*)/[^/]-$" or ".";

		local old_path = package.path;
		package.path = (
			root .. "/?.lua;" .. root .. "/?/init.lua;" ..
			root .. "/../lib/lua/?.lua;" .. root .. "/../lib/lua/?/init.lua;" ..
			old_path
		):gsub("/", old_path:match "[/\\]");

		if not pcall(require, "std.path") then
			print "error: TAL std libraries not found in the expected locations or the lua path. Please, fix your LUA_PATH";
			os.exit(1);
		end

		local package = require "std.package";
		local ffi = require "nat.ffi";
		local path = require "std.path";

		local old_ffi_roots = ffi.roots;
		local old_pkg_roots = package.roots;

		ffi.roots = { root, path.join(root, "../lib"), table.unpack(old_ffi_roots) };
		package.roots = { root, path.join(root, "../lib"), table.unpack(old_pkg_roots) };

		require = package.require;

		package:init_paths(old_path);

		local cwd = assert(require "impl":getpath "cwd");
		root = path.cwd(cwd, root);

		ffi.roots = { root, path.join(root, "../lib"), table.unpack(old_ffi_roots) };
		package.roots = { root, path.join(root, "../lib"), table.unpack(old_pkg_roots) };
	end

	if has_dbg then
		old_env.debug = require "std.debug";
		dbg.start();
	end

	require "std.globals";
	local loop = require "std.loop";
	local entry = require(entry_mod);

	loop.name(coroutine.running(), "Main thread");

	local ok, err = xpcall(function (...)
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
	end, debug.traceback, ...);

	if not ok then print("Uncaught error: " .. err) end
end

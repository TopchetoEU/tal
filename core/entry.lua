local module = require "core.module";
local fs = require "mod.fs";
local path = require "mod.path";

TAL = "0.0.1";

return function (...)
	local root, loop_run = module.init {
		tal_path = require "__tal__PATH",
		fs = fs,
		path = path,
	};

	loop_run.run(function (...)
		root.require "tal.cli".main(...);
	end, ...);
end

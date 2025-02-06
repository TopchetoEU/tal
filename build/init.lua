local fs;

if not TAL then
	local module = require "core.module";
	local root = module.init {
		tal_path = { "./mod/" },
		lua_path = package.path,
		target_glob = _G,

		pwd = "./",
		home = "",

		join = require "mod.path".join,
		cwd = require "mod.path".cwd,
	};

	require = root.require;
	import = root.import;
	export = root.export;
	exports = root.exports;
end

fs = require "fs";

local args = require "..mod.args";
local modules = {
	"core.entry",
	"core.module",
	"mod.path",
	"mod.fs",
};

local function main(...)
	local arg_readers = {};
	local target;
	local executable;
	local paths = array {};

	function arg_readers.dst(v)
		target = v;
		return true;
	end
	function arg_readers.path(v)
		paths:push(v);
		return true;
	end
	function arg_readers.executable(v)
		executable = v;
		return true;
	end
	function arg_readers.linux()
		target = fs.home() .. "/.local/bin/tal";

		if fs.exists "/bin/luajit" then
			executable = "/bin/luajit";
		elseif fs.exists "/bin/lua" then
			executable = "/bin/lua"
		else
			print "No valid lua runtime found, WTF?";
		end

		paths = array {
			"~/.local/lib/tal",
			"~/.local/lib/.tal_mod",
			"/usr/lib/tal",
			"/usr/lib/.tal_mod",
			"/usr/local/lib/.tal_mod",
		};

		return false;
	end

	arg_readers.o = arg_readers.dst;
	arg_readers.x = arg_readers.executable;
	arg_readers.p = arg_readers.path;

	args(arg_readers, ...);

	if not target then error "No target specified" end

	local f = assert(io.open(target, "w"));

	if executable then
		f:write(("#!%s\n"):format(executable));
	end

	f:write "load(string.dump(function(...)\n";
	f:write "function package.preload.__tal__PATH() return {\n";
	f:write(paths:map(function (v) return "\t" .. v:quote() .. ",\n" end, true):join"");
	f:write("} end\n");

	for i = 1, #modules do
		local name = modules[i];
		local file = name:gsub("%.", "/") .. ".lua";

		f:write(("package.preload[%q] = function(...)\n"):format(name));
		for el in assert(io.open(file, "r")):lines(1024) do
			f:write(el);
		end
		f:write("\nend\n");
	end

	f:write(("require %q(...)"):format("core.entry"));

	f:write "\nend, true), '<internal>', 'b')(...)";

	f:close();

	if executable then
		os.execute(("chmod +x %q"):format(target));
	end
end

if type(module) ~= "table" then
	main(...);
else
	return main;
end

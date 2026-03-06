local args = require "std.fmt.args";
local mklua= require "tal.mklua"
local spawn = require "std.proc";
local ffi   = require "ffi"

local help_msg = [[tal bundle by TopchetoEU

Generates a C program, a bundle of a lua module + its dependencies, and optionally compiles it to an executable

Flags:

<entry> - the name of a lua module to be bundled

--compile-cmd (-C) ... - specifies the rest of the arguments as a compiler, to be used to produce the executable.
	The static libraries, used by the lua module will be appended to the arguments.
	The contents of the generated C file will be piped in stdin
--compiler (-c) - sets compile-cmd to a preexisting compile command preset:
	- gcc - A gcc-like command (uses cc for clang compat)
	- msvc - An msvc-like command. Not tested, not recommended
	If --output is specified in conjunction with this, it will translate to an output flag for the compile command.

--output (-o) <file> - specifies the file to which the C source should be written
--bootstrap <module> - specifies an alternative to "tal.entry" that will bootstrap the compiled module
]]

return args.cli {
	ctx = {},
	flags = {
		help = args.bool "help",
		["compile-cmd"] = args.rest "compile_cmd",
		compiler = args.str "compiler",
		output = args.str "output",
		debug = args.bool "debug",
		deps = args.bool "deps",
		libs = args.bool "libs",

		bootstrap = args.str "bootstrap",

		C = "compile-cmd",
		c = "compiler",
		o = "output",
		g = "debug",
	},
	rest = args.str "entry",
	next = function (ctx)
		if ctx.help or not ctx.compile_cmd and not ctx.compiler and not ctx.output then
			return io.stderr:write(help_msg);
		end

		if not ctx.entry then
			return io.stderr:write "error: an entry must be specified\n";
		end

		if ctx.compiler then
			if ctx.compiler == "gcc" then
				ctx.compile_cmd = { "cc", "-x", "c", "-", "-x", "none", "-lm" };

				if ctx.output then
					table.insert(ctx.compile_cmd, "-o");
					table.insert(ctx.compile_cmd, ctx.output);
				end
			elseif ctx.compiler == "msvc" then
				ctx.compile_cmd = { "cl", "/Tc", "-" };

				if ctx.output then
					table.insert(ctx.compile_cmd, "/Fe:" .. ctx.output);
				end
			else
				io.stderr:write "invalid compiler preset\n";
				return;
			end
		end

		local mklua_ctx = {
			entries = { ctx.bootstrap or "tal.entry", ctx.entry },
			args = { "-m", ctx.entry },
			path = package.path,
			cpath = package.cpath,
			entry = true,
			main = true,
			noinc = true,
			debug = ctx.debug,
		};

		if ctx.compile_cmd then
			local lj_lib, err_a, err_so;
			lj_lib, err_a = package.searchpath("luajit", ffi.apath);
			if not lj_lib then
				lj_lib, err_so = package.searchpath("luajit", ffi.path)
				if not lj_lib then
					io.stderr:write("luajit not found in ffi path:\n" .. err_a .. "\n" .. err_so);
					return;
				end
			end

			table.insert(ctx.compile_cmd, lj_lib)

			local comp_proc = assert(spawn {
				argv = ctx.compile_cmd,
				stdin = "pipe",
				env = { PATH = os.getenv "PATH" or "" }
			});

			local libs = {};

			mklua.gen(mklua_ctx, { f = comp_proc.stdin --[[@as file*]], libs = libs });

			comp_proc.stdin:close();
			assert(comp_proc:wait());

			if #libs > 0 then
				io.stderr:write [[
The lua code depends on some native libraries. For luajit's ffi to find them,
you must either 1. include them in the cwd (usually next to the executable),
2. install the libraries on the targeted system or 3. install the libraries to
a known path and then set the env variable FFI_PATH, so that ffi can find the
libraries.

For easier distribution, bundle the executable + the libraries in an appimage.
]];
			end
		elseif ctx.output then
			local f, close = mklua.open_w(ctx.output);
			mklua.gen(mklua_ctx, { f = f });
			close(f);
		elseif ctx.libs then
			local libs = {};

			mklua.gen(mklua_ctx, { libs = libs });

			for i = 1, #libs do
				io.stdout:write(libs[i] .. "\n");
			end
		elseif ctx.deps then
			local deps = {};

			mklua.gen(mklua_ctx, { deps = deps });

			for k, v in pairs(deps) do
				io.stdout:write(v .. "\n");
			end
		else
			io.stderr:write "--compile-cmd or --output must be specified\n";
			return io.stderr:write(help_msg);
		end
	end
}

local args = require "std.fmt.args";
local mklua= require "tal.mklua"
local spawn = require "std.proc";

local help_msg = [[tal bundle by TopchetoEU

Generates a C program, a bundle of a lua module + its dependencies, and optionally compiles it to an executable

Flags:

<entry> - the name of a lua module to be bundled

--compile-cmd (-c) ... - specifies the rest of the arguments as a compiler, to be used to produce the executable.
	The static libraries, used by the lua module will be appended to the arguments.
	The contents of the generated C file will be piped in stdin
--output (-o) <file> - specifies the file to which the C source should be written
--bootstrap <module> - specifies an alternative to "tal.entry" that will bootstrap the compiled module
]]

return args.cli {
	ctx = {},
	flags = {
		help = args.bool "help",
		["compile-cmd"] = args.rest "compile_cmd",
		output = args.str "output",
		deps = args.bool "deps",
		libs = args.bool "libs",

		bootstrap = args.str "bootstrap",

		c = "compile-cmd",
		o = "output",
	},
	rest = args.str "entry",
	next = function (ctx)
		if ctx.help then
			return io.stderr:write(help_msg);
		end

		if not ctx.entry then
			return io.stderr:write "error: an entry must be specified\n";
		end

		local mklua_ctx = {
			entries = { ctx.bootstrap or "tal.entry", ctx.entry },
			args = { "-m", ctx.entry },
			path = package.path,
			cpath = package.cpath,
			entry = true,
			main = true,
			noinc = true,
		};

		if ctx.compile_cmd then
			local comp_proc = assert(spawn {
				argv = ctx.compile_cmd,
				stdin = "pipe",
				env = { PATH = os.getenv "PATH" or "" }
			});

			mklua.gen(mklua_ctx, { f = assert(comp_proc.stdin) --[[@as file*]] });
			comp_proc.stdin:close();
			assert(comp_proc:wait());
		elseif ctx.output then
			local f, close = mklua.open_w(ctx.output);
			mklua.gen(mklua_ctx, { f = f });
			close(f);
		elseif ctx.libs then
			local libs = {};

			mklua.gen(mklua_ctx, { libs = libs });

			if ctx.libs then
				for i = 1, #libs do
					io.stdout:write(libs[i] .. "\n");
				end
			end
		elseif ctx.deps then
			local deps = {};

			mklua.gen(mklua_ctx, { deps = deps });

			if ctx.deps then
				for k, v in pairs(deps) do
					io.stdout:write(v .. "\n");
				end
			end
		else
			io.stderr:write "--compile-cmd or --output must be specified\n";
			return io.stderr:write(help_msg);
		end
	end
}

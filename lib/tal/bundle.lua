local argp = require "std.fmt.argp";
local mklua = require "tal.mklua";
local spawn = require "std.proc";
local ffi = require "ffi";

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

return function (...)
	local argv = argp.new(...);

	local mode = "gen";
	local bootstrap = "tal.entry";
	local compiler_cmd;
	local output;
	local debug = false;
	local entry;

	local rest = false;

	while argv:has() do
		local opts = not rest and argv:popopt() or nil;
		if opts then
			for opt in opts do
				if opt == "--" then
					rest = true;

				elseif opt == "--help" or opt == "-h" then
					print(help_msg);
					return;

				elseif opt == "--gen" or opt == "-G" then
					mode = "gen";
				elseif opt == "--deps" or opt == "-D" then
					mode = "deps";
				elseif opt == "--libs" or opt == "-L" then
					mode = "libs";

				elseif opt == "--debug" or opt == "-g" then
					debug = true;
				elseif opt == "--output" or opt == "-o" then
					output = argv:apop("no value for " .. opt);

				elseif opt == "--compiler" or opt == "-c" then
					local compiler = argv:apop("no value for " .. opt);
					if compiler == "gcc" then
						compiler_cmd = { "cc", "-x", "c", "-", "-x", "none", "-lm" };
						if output then
							table.insert(compiler_cmd, "-o");
							table.insert(compiler_cmd, output);
						end
					elseif compiler == "mscv" then
						compiler_cmd = { "cl", "/Tc", "-" };
						if output then
							table.insert(compiler_cmd, "/Fe:" .. output);
						end
					else
						error "invalid or unsupported compiler type";
					end

				elseif opt == "--compiler-cmd" or opt == "-C" then
					compiler_cmd = argv:poprest();

				elseif opt == "--" then
					rest = true;
				else
					error("unknown option " .. opt);
				end
			end
		else
			entry = argv:pop();
		end
	end

	if not compiler_cmd and not output then
		return io.stderr:write(help_msg);
	end

	if not entry then
		return io.stderr:write "error: an entry must be specified\n";
	end

	local mklua_ctx = {
		entries = { bootstrap or "tal.entry", entry },
		args = { entry },
		path = package.path,
		cpath = package.cpath,
		entry = true,
		main = true,
		noinc = true,
		debug = debug,
	};

	if mode == "gen" then
		if compiler_cmd then
			local lj_lib, err_a, err_so;
			lj_lib, err_a = package.searchpath("luajit", ffi.apath);
			if not lj_lib then
				lj_lib, err_so = package.searchpath("luajit", ffi.path)
				if not lj_lib then
					io.stderr:write("luajit not found in ffi path:\n" .. err_a .. "\n" .. err_so);
					return;
				end
			end

			table.insert(compiler_cmd, lj_lib)

			local comp_proc = assert(spawn {
				argv = compiler_cmd,
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
		elseif output then
			local f, close = mklua.open_w(output);
			mklua.gen(mklua_ctx, { f = f });
			close(f);
		else
			print(help_msg);
		end
	elseif mode == "libs" then
		local libs = {};

		mklua.gen(mklua_ctx, { libs = libs });

		for i = 1, #libs do
			if not libs[libs[i]] then
				libs[libs[i]] = true;
				io.stdout:write(libs[i] .. "\n");
			end
		end
	elseif mode == "deps" then
		local deps = {};

		mklua.gen(mklua_ctx, { deps = deps });

		for k, v in pairs(deps) do
			io.stdout:write(v .. "\n");
		end
	end
end

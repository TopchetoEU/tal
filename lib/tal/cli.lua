local readline = require "nat.libreadline";
local printing = require "std.printing";
local traceback = require "tal.traceback";
local fs = require "std.io.fs";
local path = require "std.path";
local argp = require "std.fmt.argp"
local cli = {};

local function stacktrace_fin(ok, ...)
	if ok then return true, ... end

	local err = (...).err;
	local trace = (...).trace;

	if type(err) == "string" then
		io.stderr:write("Unhandled error: ", err, "\n", trace, "\n");
	else
		io.stderr:write("Unhandled error: ", printing.stringify(err), "\n", trace, "\n");
	end

	return false, err;
end

function cli.stacktrace_call(func, ...)
	return stacktrace_fin(xpcall(func, function (err)
		local trace = traceback(3);
		return { err = err, trace = trace };
	end, ...));
end

function cli.load_eval(src, name, env)
	local f, err = load("return " .. src, name, "t", env);
	if f == nil then
		f, err = load(src, name, "t", env);
	end

	return f, err;
end

function cli.repl()
	while true do
		local cont = true;

		cli.stacktrace_call(function ()
			local src = "";
			local err;

			repeat
				local done = false;
				local f;

				local line = readline(src == "" and "> " or "... ");
				if line == nil or src == "" and line == ".exit" then
					cont = false;
					return;
				elseif line == "" then
					break;
				end

				src = src .. "\n" .. line;
				f, err = cli.load_eval(src, "=<repl>");

				if f ~= nil then
					pprint(f());

					done = true;
				end
			until done;

			if err ~= nil then
				error(err, 0);
			end

			return true;
		end);

		if not cont then return end
	end
end

function cli.run_mod(module, ...)
	if type(module) == "table" and module.main then
		return module.main(...);
	else
		return module(...);
	end
end

function cli.print_version()
	print(("TAL v%s by TopchetoEU"):format(_TAL));
end
function cli.print_help()
	print [[
A pseudo-runtime on top of my beloved Lua. Includes async IO (with libuv) and some really useful stdlibs.
PLEASE DON'T USE IN PRODUCTION, MIGHT BREAK AT ANY SECOND!!

Options:
--require (-l) [name]: Requires the given package before execution, similar to "lua -l"
--help (-h): Shows this message
--version (-v): Shows the version
--eval (-e): Evaluates the rest of the arguments
--repl (-i): Enables interactive mode after all other tasks are done. Enters by default if no -e or file is specified
--: Passes the rest of the arguments as arguments]];
end

function cli.main(...)
	local argv = argp.new(...);

	local evals = {};
	local requires = {};

	local version = false;
	local repl = false;
	local rest = false;
	local any = false;

	local file = nil;
	local module = nil;
	local args;

	while argv:has() do
		local opts = not rest and argv:popopt() or nil;
		if opts then
			for opt in opts do
				if opt == "--eval" or opt == "-e" then
					table.insert(evals, argv:apop("no value for " .. opt));
					any = true;
				elseif opt == "--require" or opt == "-l" then
					local val = argv:apop("no value for " .. opt);

					local glob, name = val:match "^(.-)=(.*)$";
					if not glob then name = val end

					requires[name] = glob;
				elseif opt == "--help" or opt == "-h" then
					cli.print_version();
					cli.print_help();
					return;
				elseif opt == "--version" or opt == "-v" then
					version = true;
					any = true;
				elseif opt == "--repl" or opt == "-i" then
					repl = true;
					any = true;
				elseif opt == "--module" or opt == "-m" then
					module = argv:apop("no value for " .. opt);
					args = argv:poprest();
					any = true;
				elseif opt == "--" then
					rest = true;
					any = true;
				else
					error("unknown option " .. opt);
				end
			end
		else
			file = argv:pop();
			args = argv:poprest();
			any = true;
		end
	end

	if not any then
		repl = true;
		version = true;
	end

	cli.stacktrace_call(function ()
		if version then
			cli.print_version();
		end

		for i = 1, #requires do
			require(requires[i]);
		end

		for i = 1, #evals do
			local fun, err = load(evals[i], "=<eval " .. i .. ">", "t");
			if not fun then
				io.stderr:write(err);
				return;
			end

			fun(table.unpack(args));
		end

		if module then
			package.root = fs.path "cwd";

			local mod = require(module);
			if type(mod) == "table" then
				if mod.__main then
					mod.__main(table.unpack(args));
				else
					mod.main(table.unpack(args));
				end
			else
				mod(table.unpack(args));
			end
		end

		if file then
			local f = assert(io.open(file));
			local src = f:read "a";
			f:close();

			package.root = path.dirname(file);

			local func, err = load(src, "@" .. file, "t");
			if not func then error(err, 0) end

			func(table.unpack(args));
		end

		if repl then
			cli.repl();
		end
	end);
end

return cli;

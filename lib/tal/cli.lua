local readline = require "nat.libreadline";
local printing = require "std.printing";
local fs = require "std.io.fs";
local path = require "std.path";
local argp = require "std.fmt.argp";
local cli = {};

local function stacktrace_fin(ok, ...)
	if ok then return true, ... end

	if ... == "stack overflow" then
		io.stderr:write("Unhandled error: STACK OVERFLOW!\n");
		return;
	end

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
		local trace = debug.traceback(nil, 2);
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
	-- TODO: uncomment when libreadline is made concurrent
	-- assert(signal.on "INT");
	-- loop.fork(function ()
	-- 	for sig in signal.wait do
	-- 		print(sig);
	-- 		if sig == "INT" then
	-- 			exit(0);
	-- 		end
	-- 	end
	-- end);

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
	print "A lua runtime with concurrent I/O and a lot of useful utils.";
end
function cli.print_help()
	print [[
Options:
--require (-l) [name]: Requires the given package before execution, similar to "lua -l"
--help (-h): Shows this message
--version (-v): Shows the version
--eval (-e): Evaluates the rest of the arguments
--repl (-i): Enables interactive mode after all other tasks are done. Enters by default if no -e or file is specified]];
end

function cli.main(...)
	local argv = argp.new(...);

	local evals = {};
	local requires = {};

	local version = false;
	local repl = false;
	local any = false;

	local file = nil;
	local module = nil;
	local args;

	for arg, isopt in argv:iter() do
		if isopt then
			if arg == "--eval" or arg == "-e" then
				table.insert(evals, argv:pop());
				any = true;
			elseif arg == "--require" or arg == "-l" then
				local val = argv:pop();

				local glob, name = val:match "^(.-)=(.*)$";
				if not glob then name = val end

				requires[name] = glob;
			elseif arg == "--help" or arg == "-h" then
				cli.print_version();
				cli.print_help();
				return;
			elseif arg == "--version" or arg == "-v" then
				version = true;
				any = true;
			elseif arg == "--repl" or arg == "-i" then
				repl = true;
				any = true;
			elseif arg == "--module" or arg == "-m" then
				module = argv:pop();
				args = { argv:poprest() };
				any = true;
			else
				error("unknown option " .. arg);
			end
		else
			file = arg;
			args = { argv:poprest() };
			any = true;
		end
	end

	if not any then
		repl = true;
		version = true;
	end

	if version then
		cli.print_version();
	end

	for k, v in pairs(requires) do
		if not cli.stacktrace_call(function ()
			_G[v] = require(k);
		end) then
			return false
		end
	end

	for i = 1, #evals do
		if not cli.stacktrace_call(function ()
			return assert(load(evals[i], "=<eval " .. i .. ">", "t"))();
		end) then return false end
	end

	if module then
		package.root = fs.path "cwd";

		cli.stacktrace_call(function ()
			local mod = require(module);
			if type(mod) == "table" then
				if mod.__main then
					return mod.__main(table.unpack(args));
				else
					return mod.main(table.unpack(args));
				end
			else
				return mod(table.unpack(args));
			end
		end);
	elseif file then
		cli.stacktrace_call(function ()
			local f = assert(io.open(file));
			local src = f:read "a";
			f:close();

			package.root = path.dirname(file);

			local func = iassert(load(src, "@" .. file, "t"));
			return func(table.unpack(args));
		end);
	end

	if repl then
		return cli.repl();
	end
end

return cli;

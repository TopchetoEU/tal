local readline = require "nat.libreadline";
local args = require "std.fmt.args";
local printing = require "std.printing";
local traceback = require "tal.traceback";
local fs = require "std.io.fs";
local path = require "std.path";
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

cli.main = args.cli {
	ctx = {
		requires = {},
		evals = {},
		args = {},
		help = false,
		version = false,
		repl = false,
		module = nil,
		file = nil,
	},
	flags = {
		eval = args.str_arr "evals",
		require = args.str_arr "requires",
		help = args.bool "help",
		version = args.bool "version",
		repl = args.bool "repl",
		module = function (ctx, val, ...)
			assert(val, "expected string value for '--module'");

			ctx.module = val;
			ctx.args = { ... };
		end,

		v = "version",
		i = "repl",
		m = "module",
		l = "require",
		e = "eval",
	},
	rest = function (ctx, ...)
		if ctx.module then
			ctx.args = { ... };
			return;
		end

		local file = ...;
		assert(file);

		ctx.file = file;
		ctx.args = { select(2, ...) };
	end,
	next = function (ctx)
		if ctx.help then
			cli.print_version();
			cli.print_help();
			return;
		end

		local runners = {};
		local req_runners = {};
		local use_req = false;
		local args = ctx.args;

		if ctx.version then
			table.insert(runners, cli.print_version);
		end

		for i = 1, #ctx.requires do
			local glob, name = ctx.requires[i]:match "^(.-)=(.*)$";
			if not glob then name = ctx.requires[i] end

			table.insert(req_runners, function ()
				local res = require(name);
				if glob then _ENV[glob] = res end
			end);
		end

		for i = 1, #ctx.evals do
			use_req = true;

			local fun, err = load(ctx.evals[i], "=<eval " .. i .. ">", "t");
			if not fun then
				io.stderr:write(err);
				return;
			end

			table.insert(runners, function ()
				cli.stacktrace_call(function ()
					fun(table.unpack(args));
				end);
			end);
		end

		if ctx.module then
			use_req = true;

			table.insert(runners, function ()
				cli.stacktrace_call(function ()
					package.root = fs.path "cwd";

					local mod = require(ctx.module);
					if type(mod) == "table" then
						if mod.__main then
							return mod.__main(table.unpack(ctx.args));
						else
							return mod.main(table.unpack(ctx.args));
						end
					else
						return mod(table.unpack(ctx.args));
					end
				end);
			end);
		elseif ctx.file then
			use_req = true;

			table.insert(runners, function ()
				cli.stacktrace_call(function ()
					local f = assert(io.open(ctx.file));
					local src = f:read "a";
					f:close();

					package.root = path.dirname(ctx.file);

					local func, err = load(src, "@" .. ctx.file, "t");
					if not func then error(err, 0) end

					return func(table.unpack(ctx.args));
				end);
			end);
		end

		if ctx.repl then
			use_req = true;
			table.insert(runners, cli.repl);
		end

		if #runners == 0 then
			use_req = true;
			table.insert(runners, cli.print_version);
			table.insert(runners, cli.repl);
		end

		if use_req then
			table.move(runners, 1, #runners, #req_runners + 1);
			table.move(req_runners, 1, #req_runners, 1, runners);
		end

		for i = 1, #runners do
			if i == #runners then
				return runners[i]();
			else
				runners[i]();
			end
		end
	end
};

return cli;

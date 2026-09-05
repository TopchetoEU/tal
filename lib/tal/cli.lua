local path = require "std.path";
local argp = require "std.argp";
local cli = {};

function cli.load_eval(src, name, env)
	local f, err = load("return " .. src, name, "t", env);
	if f == nil then
		f, err = load(src, name, "t", env);
	end

	return f, err;
end

function cli.repl(prefix, eot)
	prefix = prefix or "";
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

		local ok, err, trace = spcall(function ()
			local src = "";
			local err;

			repeat
				local done = false;
				local f;

				local line = require "nat.libreadline"(src == "" and (prefix .. "> ") or "... ");
				if line == eot then
					cont = false;
					return;
				end
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
		if not ok then eprint(err, trace) end

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
	print(("TAL v%s Copyright (C) 2025-2026 TopchetoEU"):format(_TAL));
	print "This program comes with ABSOLUTELY NO WARRANTY. This is free software, and you are welcome to redistribute it under certain conditions";
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
				if not glob then
					name = val;
					glob = val:match "[^.]+$" or val;
				end

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
		_G[v] = require(k);
	end

	for i = 1, #evals do
		assert(load(evals[i], "=<eval " .. i .. ">", "t"))();
	end

	if module then
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
	elseif file then
		local root = path.dirname(file);
		package.roots:insert(root);

		local f = assert(io.open(file));
		local src = f:read "a";
		f:close();

		iassert(load(src, "@" .. file, "t"))(table.unpack(args));

		package.roots:delete(root);
	end

	io.stdout:flush();

	if repl then
		return cli.repl();
	end
end

return cli;

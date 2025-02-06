local arg_parse = require "args";
local path = require "path";
local traceback = require "traceback";
local root = require "root";

local exports = {};

function exports.stacktrace_call(func, ...)
	return xpcall(func, function (err)
		local trace = traceback(2, "\t");

		io.stderr:write "Unhandled error: ";

		if type(err) == "string" then
			print(err);
		else
			pprint(err);
		end

		print(trace);

		return err;
	end, ...);
end

function exports.load_eval(src, name, env)
	local f, err = load(iterate { "return ", src }, name, "t", env);
	if f == nil then
		f, err = load(src, name, "t", env);
	end

	return f, err;
end

function exports.repl()
	local mod = root.mk(path.join(root.name, "../<repl>"));
	function mod.export()
		error "Can't export in the REPL";
	end

	mod.exports = nil;
	mod.returns = {};

	mod.env.export = mod.export;
	mod.env.import = mod.import;
	mod.env.require = mod.require;
	mod.env.module = mod;
	local local_err_shown = false;

	while true do
		local cont = true;

		exports.stacktrace_call(function ()
			local src = "";
			local err;

			repeat
				local done = false;
				local f;

				if src == "" then
					io.stderr:write "> ";
				else
					io.stderr:write "... ";
				end

				--- @type string
				local line = io.stdin:read("l");
				if line == nil then
					cont = false;
					return;
				elseif line == "" then
					break
				end

				src = src .. "\n" .. line;
				f, err = exports.load_eval(src, "<repl>", mod.env);

				if f ~= nil then
					if not local_err_shown then
						local i = 1;
						local locals = array {};

						while true do
							local n = debug.getlocal(f, i);
							if not n then break end

							if not n:match("^%(") then
								locals:push(n);
							end

							i = i + 1;
						end

						if #locals > 0 then
							local_err_shown = true;
							print "You have defined the following locals in your code:";
							print(locals:join ", ");
							print "Consider declaring them as globals instead (\"a = 10\" and \"function a() ... end\")";
						end
					end

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

		promise.resolve():await();
	end
end

function exports.exec(mod, requires, compile, ...)
	exports.stacktrace_call(function (...)
		for i = 1, #requires do
			mod.require(requires[i])
		end

		local func = compile();

		mod.main = true;
		mod.returns = box(func(...));

		if mod.returns.n > 0 then
			mod.exports = mod.returns[1];
		end

		if type(mod.exports) == "function" then
			return mod.exports(...);
		elseif type(mod.exports) == "table" and type(mod.exports.main) == "function" then
			return mod.exports.main(...);
		end
	end, ...);
end

function exports.main(...)
	require "core";

	local file;
	local args = array {};
	local requires = array {};
	local eval;

	arg_parse({
		function (v)
			if eval then
				eval:push(v);
			elseif file ~= nil then
				args:push(v);
			else
				file = v;
			end

			return true;
		end,
		require = function (v)
			requires:push(v);
			return true;
		end,
		eval = function ()
			eval = array {};
			return false, true;
		end,
		version = function ()
			print(str("TAL v", TAL));
			print("Created /w love and dread by TopchetoEU");
			exit();
		end,
		help = function ()
			print(str("TAL v", TAL, " by TopchetoEU"));
			print "A pseudo-runtime on top of my beloved Lua. Includes a better module system and";
			print "an improved set of stdlibs to make your life easier.";
			print "PLEASE DON'T USE IN PRODUCTION, MIGHT BREAK AT ANY SECOND";
			print "Options:";
			print "\t--require (-r) [name]: Requires the given package before execution, similar to \"lua -l\"";
			print "\t--help (-h): Shows this message";
			print "\t--version: Shows the version";
			print "\t--eval (-e): Evaluates the rest of the arguments";
			print "\t--: Passes the rest of the arguments as arguments";

			exit();
		end,

		r = "require",
		h = "help",
		e = "eval",
	}, ...);

	if eval then
		local mod = root.mk(path.join(root.name, "../<eval>"));
		return exports.exec(mod, requires, function ()
			return assert(exports.load_eval(eval:join " ", "<eval>", mod.env));
		end, unpack(args));
	elseif file then
		return exports.stacktrace_call(function (...)
			if not file:match "^/" then
				file = "./" .. file;
			end

			local mod = root.import(file);

			if type(mod) == "function" then
				return mod(...);
			elseif mod and type(mod.main) == "function" then
				return mod.main(...);
			end
		end, ...);
	else
		return exports.repl();
	end
end

return exports;

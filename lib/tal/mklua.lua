local argp = require "std.fmt.argp";
local ffi = require "ffi";

--- @class tal.mklua.ctx
--- @field mode "deps" | "libs" | "gen"
--- @field entries string[]
---
--- @field path? string
--- @field cpath? string
--- @field ffi_path? string
--- @field output? string | file*
--- @field args? string[]
--- @field debug? boolean
--- @field main? boolean
--- @field entry? boolean
--- @field noinc? boolean

local int_libs = {
	string = true,
	table = true,
	ffi = true,
	["table.clear"] = true,
	["table.new"] = true,
	["string.buffer"] = true,
}

--- @class tal.mklua.out
--- @field f? file*
--- @field deps? table<string, string>
--- @field ffi_deps? table<string, string>
--- @field libs? string[]

local help_msg = [[
A tool that walks a lua dependency tree and emits a C file, used to
compile the application to a self-contained executable.

Flags:

<module[:output-name]> - exports the given module with a luaopen function.
	If :output-name is specified, changes the luaopen to the specified module name

Mode selector:
--gen (-G) - generates a C file that contains the bytecode for the app (default mode)
--deps (-D) - outputs a list of files the entries depend on
--libs (-L) - outputs a list of native libraries the entries depend on

--noinc - instead of emitting #include directives, embeds all needed lua functions as extern declares
--entry - generates a talb_entry function, which takes an initialized lua state
	and executes the first entry
--main - generates a main function, which creates a lua state and runs the entry. Implies `--entry`

--output (-o) <file> - the file to write to. May be stdout, piped into a compiler
--debug (-g) - emits debugging data in the lua bytecode
--path <path> - specifies a lua path to search (separated by ;, ;; is a substitute for the interpreter's default)
--cpath <path> - specifies a c path to search
--arg ... - passes the rest of the args to the last entry, if "--entry" is specified
]];

local entry_format = [[
#ifndef TALB_ENTRY_NAME
	#define TALB_ENTRY_NAME talb_entry
#endif

TALB_EXPORT int TALB_ENTRY_NAME(lua_State *ctx, int argc, const char **argv) {
	int larg, lerrcb, i, ok;
	lua_checkstack(ctx, argc + %d + 16);

	lua_createtable(ctx, argc, 0);
	lua_setfield(ctx, LUA_REGISTRYINDEX, "_FFI_PRELOAD");

	/* Emit other requiref-s */
	%s

	lua_createtable(ctx, argc, 0);
	larg = lua_gettop(ctx);

	lua_pushvalue(ctx, larg);
	lua_setglobal(ctx, "arg");

	%s(ctx);
	%s(ctx);

	lua_pushinteger(ctx, 0);
	lua_pushstring(ctx, argv[0]);
	lua_settable(ctx, larg);

	/* custom arguments */
%s

	for (i = 1; i < argc; i++) {
		lua_pushstring(ctx, argv[i]);
		lua_pushinteger(ctx, i);
		lua_pushvalue(ctx, -2);
		lua_settable(ctx, larg);
	}

	ok = !lua_pcall(ctx, argc + %d - 1, 0, lerrcb);
	if (!ok) fprintf(stderr, "lua error: %%s\n", lua_tostring(ctx, -1));

	return ok;
}
]];
local main_format = [[
#ifndef TALB_MAIN_NAME
	#define TALB_MAIN_NAME main
#endif

TALB_EXPORT int TALB_MAIN_NAME(int argc, const char **argv) {
	int ok;
	lua_State *ctx = luaL_newstate();
	luaL_openlibs(ctx);

	ok = TALB_ENTRY_NAME(ctx, argc, argv);
	lua_close(ctx);
	return ok ? 0 : 1;
}
]];

local lua_declares = [[
#include <stddef.h>
#include <stdio.h>

#define LUA_REGISTRYINDEX (-10000)
#define LUA_GLOBALSINDEX (-10002)

typedef ptrdiff_t lua_Integer;
typedef struct lua_State lua_State;
typedef int (*lua_CFunction) (lua_State *L);
typedef void *(*lua_Alloc) (void *ud, void *ptr, size_t osize, size_t nsize);

extern lua_State *(lua_newstate) (lua_Alloc f, void *ud);
extern void (lua_close) (lua_State *L);

extern void (lua_settable) (lua_State *L, int idx);
extern void (lua_getfield) (lua_State *L, int idx, const char *k);
extern void (lua_setfield) (lua_State *L, int idx, const char *k);
extern void (lua_createtable) (lua_State *L, int narr, int nrec);

extern void  (lua_call) (lua_State *L, int nargs, int nresults);
extern int   (lua_pcall) (lua_State *L, int nargs, int nresults, int errfunc);

extern int (lua_gettop) (lua_State *L);
extern void (lua_settop) (lua_State *L, int idx);
extern void (lua_pushvalue) (lua_State *L, int idx);
extern int (lua_checkstack) (lua_State *L, int sz);

extern void (lua_pushinteger) (lua_State *L, lua_Integer n);
extern void (lua_pushstring) (lua_State *L, const char *s);
extern void (lua_pushcclosure) (lua_State *L, lua_CFunction fn, int n);

extern const char *(lua_tolstring) (lua_State *L, int idx, size_t *len);

#define lua_pop(L,n) lua_settop(L, -(n)-1)
#define lua_pushcfunction(L,f) lua_pushcclosure(L, (f), 0)
#define lua_tostring(L,i) lua_tolstring(L, (i), NULL)
#define lua_setglobal(L,s) lua_setfield(L, LUA_GLOBALSINDEX, (s))

extern lua_State *(luaL_newstate) (void);
extern int (luaL_error) (lua_State *L, const char *fmt, ...);
extern int (luaL_loadbufferx) (lua_State *L, const char *buff, size_t sz, const char *name, const char *mode);

extern void luaL_openlibs(lua_State *L);
]];
local lua_includes = [[
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
]];
local prolog = [[
#ifndef TALB_INTERNAL
	#define TALB_INTERNAL static
#endif
#ifndef TALB_EXPORT
	#ifdef TALB_HEADER
		#define TALB_EXPORT static
	#else
		#define TALB_EXPORT extern
	#endif
#endif

TALB_INTERNAL void talb_register(lua_State *ctx, const char *modname, lua_CFunction openf) {
	lua_getfield(ctx, LUA_REGISTRYINDEX, "_PRELOAD");
	lua_pushcfunction(ctx, openf);
	lua_setfield(ctx, -2, modname);
	lua_pop(ctx, 1);
}
]];

local function c_escape(str)
	local parts = {};
	for i = 1, math.ceil(#str / 32) do
		table.insert(parts, "\"" .. str:sub((i - 1) * 32 + 1, i * 32):gsub(".", function (c)
			local b = string.byte(c);

			if c == "\n" then
				return "\\n";
			elseif c == "\\" then
				return "\\\\";
			elseif c == "\"" then
				return "\\\"";
			elseif b >= 32 and b <= 126 then
				return c;
			else
				return ("\\%.3o"):format(b);
			end
		end) .. "\"");
	end

	return table.concat(parts, "\n\t\t");
end

--- @param src string
local function find_lua(src)
	local func = src:gmatch "require%s*([\"'])([^\n\\\"']-)%1";
	return function ()
		return select(2, func());
	end
end
--- @param src string
local function find_ffi(src)
	local func = src:gmatch "ffi%.load%s*([\"'])([^\n\\\"']-)%1";
	return function ()
		return select(2, func());
	end
end

--- @param ctx tal.mklua.ctx
--- @param name string
local function resolve_lua(ctx, name)
	local path;
	path = package.searchpath(name, ctx.path or package.path);
	if path then
		return "lua", path;
	end

	path = package.searchpath(name, ctx.cpath or package.cpath);
	if path then
		return "c", path;
	end

	return nil;
end
--- @param ctx tal.mklua.ctx
--- @param dep string
local function resolve_ffi(ctx, dep)
	return package.searchpath(dep, ctx.ffi_path or ffi.path);
end

--- @param ctx tal.mklua.ctx
--- @param name string
--- @param filename string
--- @param func? function
--- @param out tal.mklua.out
--- @param passed table<string, string>
local function emit_lua(ctx, name, filename, func, out, passed)
	if passed[name] then return end

	local lua_deps = {};
	local c_deps = {};

	if not func then
		local f = assert(io.open(filename, "r"));
		local src = assert(f:read "a");
		f:close();

		for dep in find_lua(src) do
			local kind, path = resolve_lua(ctx, dep);

			if out.deps then
				out.deps[dep] = path;
			end

			if kind == "lua" then
				table.insert(lua_deps, dep);
				emit_lua(ctx, dep, path --[[@as string]], func, out, passed);
			elseif kind == "c" then
				table.insert(c_deps, dep);
				passed[dep] = "luaopen_" .. dep:gsub("[%.%-]", "_");
			elseif not kind and not int_libs[dep] then
				io.stderr:write("Module '" .. dep .. "' could not be resolved!\n");
			end
		end

		for dep in find_ffi(src) do
			local path = resolve_ffi(ctx, dep);

			if out.ffi_deps then
				out.ffi_deps[dep] = path;
			end

			if not path then
				io.stderr:write("FFI library '" .. dep .. "' could not be resolved!\n");
			elseif out.libs then
				table.insert(out.libs, path);
			end
		end

		func = assert(load(src, "@" .. filename, "t"));
	end

	local funcname = "talb_open_" .. name:gsub("[%.%-]", "_");

	local bc = string.dump(func, not ctx.debug);

	if out.f then
		out.f:write("TALB_INTERNAL int " .. funcname .. "(lua_State *ctx) {\n");

		for i = 1, #lua_deps do
			out.f:write(("\ttalb_register(ctx, %q, %s);\n"):format(lua_deps[i], "talb_open_" .. lua_deps[i]:gsub("[%.$-]", "_")));
		end
		for i = 1, #c_deps do
			out.f:write(("\ttalb_register(ctx, %q, %s);\n"):format(c_deps[i], "luaopen_" .. c_deps[i]:gsub("[%.%-]", "_")));
		end

		out.f:write (("\n\tif (luaL_loadbufferx(ctx, %s, %d, %q, \"b\")) {\n"):format(c_escape(bc), #bc, "@" .. filename));
		out.f:write ("\t\tluaL_error(ctx, \"lua bytecode error: %s\", lua_tostring(ctx, -1));\n");
		out.f:write ("\t}\n\n");
		out.f:write (("\tlua_pushstring(ctx, %q);\n"):format(name));
		out.f:write (("\tlua_pushstring(ctx, %q);\n"):format(filename));
		out.f:write ("\tlua_call(ctx, 2, 1);\n");
		out.f:write ("\treturn 1;\n");
		out.f:write ("}\n");
	end

	passed[name] = funcname;
end

--- @param ctx tal.mklua.ctx
--- @param name string
--- @param out tal.mklua.out
--- @param passed table<string, string>
local function emit_luaopen(ctx, name, out, passed)
	local kind, path = resolve_lua(ctx, name);
	if kind == "lua" then
		emit_lua(ctx, name, path --[[@as string]], nil, out, passed);
		passed[name] = "talb_open_" .. name:gsub("[%.%-]", "_");
	elseif kind == "c" then
		passed[name] = "luaopen_" .. name:gsub("[%.%-]", "_");
	else
		error("entry '" .. name .. "' couldn't be resolved");
	end

	if out.deps then
		out.deps[name] = path;
	end

	if out.f then
		out.f:write("TALB_EXPORT int luaopen_", name:gsub("[.%-]", "_"), "(lua_State *ctx) {\n");
		out.f:write("\treturn ", passed[name], "(ctx);\n");
		out.f:write("}\n\n");
	end
end

--- @param ctx tal.mklua.ctx
--- @param out tal.mklua.out
local function gen(ctx, out)
	if out.f then
		out.f:write "/* Generated by tal bundle */\n";

		if ctx.noinc then
			out.f:write(lua_declares);
		else
			out.f:write(lua_includes);
		end

		out.f:write(prolog);
	end

	--- @type table<string, string>
	local passed = {};

	for i = 1, #ctx.entries do
		emit_luaopen(ctx, ctx.entries[i], out, passed);
	end

	if ctx.entry and out.f then
		local register_calls = {};

		for i = 2, #ctx.entries do
			local name = ctx.entries[i];
			table.insert(register_calls, ("talb_register(ctx, %q, %s);"):format(name, passed[name]))
		end

		emit_lua(ctx, "__err_handle", "<internal>", function () return debug.traceback end, { f = out.f }, passed);

		local args_str = {};
		local args = ctx.args or {};

		for i = 1, #args do
			table.insert(args_str, ("\tlua_pushstring(ctx, %q);"):format(args[i]));
		end

		out.f:write(entry_format:format(
			#args,
			table.concat(register_calls, "\n\t\t"),
			passed["__err_handle"], passed[ctx.entries[1]],
			table.concat(args_str, "\n"),
			#args
		));

		if ctx.main then
			out.f:write(main_format);
		end
	end

	return passed;
end

local function open_w(path)
	if type(path) == "string" then
		if path == "-" then
			return io.stdout, function () end
		else
			local f = assert(io.open(path, "w"));
			return f, f.close;
		end
	else
		return assert(path);
	end
end


return {
	main = function (...)
		local argv = argp.new(...);

		--- @type tal.mklua.ctx
		local ctx = {
			entries = {},
			args = {},
			mode = "gen",
		};

		for arg, isopt in argv:iter() do
			if isopt then
				if arg == "--help" or arg == "-h" then
					print(help_msg);
					return;
				elseif arg == "--debug" or arg == "-g" then
					ctx.debug = true;
				elseif arg == "--noinc" then
					ctx.noinc = true;
				elseif arg == "--main" then
					ctx.main = true;
					ctx.entry = true;
				elseif arg == "--entry" then
					ctx.entry = true;
				elseif arg == "--header" then
					ctx.header = true;
				elseif arg == "--gen" or arg == "-G" then
					ctx.mode = "gen";
				elseif arg == "--deps" or arg == "-D" then
					ctx.mode = "deps";
				elseif arg == "--libs" or arg == "-L" then
					ctx.mode = "libs";
				elseif arg == "--path" then
					ctx.path = argv:pop();
				elseif arg == "--cpath" then
					ctx.cpath = argv:pop();
				elseif arg == "--ffi-path" then
					ctx.ffi_path = argv:pop();
				elseif arg == "--output" or arg == "-o" then
					ctx.output = argv:pop();
				elseif arg == "--arg" then
					table.insert(ctx.args, argv:pop());
				else
					error("unknown option " .. arg);
				end
			else
				table.insert(ctx.entries, arg);
			end
		end

		if not ctx.cpath and ctx.mode == "gen" and not ctx.output then
			print(help_msg);
			return;
		end

		if ctx.mode == "deps" then
			local deps = {};
			gen(ctx, { deps = deps });
			for k, v in pairs(deps) do
				io.stdout:write(v .. "\n");
			end
		elseif ctx.mode == "libs" then
			local libs = {};
			gen(ctx, { libs = libs });
			for i = 1, #libs do
				io.stdout:write(libs[i] .. "\n");
			end
		elseif ctx.output then
			local f, close = open_w(ctx.output);
			gen(ctx, { f = f });
			close(f);
		end
	end,
	gen = gen,
	open_w = open_w,
};


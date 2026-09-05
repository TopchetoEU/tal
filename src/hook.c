#include <string.h>
#include <stdbool.h>

#include <lua.h>
#include <lauxlib.h>

// Taken somewhat directly from lib_debug.c:303, in luajit

static int _makemask(const char *smask, int count) {
	int mask = 0;
	if (strchr(smask, 'c')) mask |= LUA_MASKCALL;
	if (strchr(smask, 'r')) mask |= LUA_MASKRET;
	if (strchr(smask, 'l')) mask |= LUA_MASKLINE;
	if (count > 0) mask |= LUA_MASKCOUNT;
	return mask;
}

static lua_State *_getthread(lua_State *ctx, int *arg) {
	if (lua_type(ctx, 1) == LUA_TTHREAD) {
		*arg = 1;
		return lua_tothread(ctx, 1);
	}
	else {
		*arg = 0;
		return ctx;
	}
}

static void _hookfn(lua_State *ctx, lua_Debug *ar) {
	static const char *const hooknames[] = { "call", "return", "line", "count", "tail return" };

	// (registry)._HOOKS
	lua_getfield(ctx, LUA_REGISTRYINDEX, "_HOOKS");
	if (lua_type(ctx, -1) != LUA_TTABLE) return;

	// (registry)._HOOKS[coroutine.running()]
	lua_pushthread(ctx);
	lua_gettable(ctx, -2);
	if (lua_type(ctx, -1) != LUA_TFUNCTION) return;

	// Arg 1
	lua_pushthread(ctx);

	// Arg 2
	lua_pushstring(ctx, hooknames[(int)ar->event]);

	// Arg 3
	if (ar->currentline >= 0) lua_pushinteger(ctx, ar->currentline);
	else lua_pushnil(ctx);

	lua_call(ctx, 3, 1);

	if (lua_isboolean(ctx, -1) && lua_toboolean(ctx, -1)) {
		lua_yield(ctx, 0);
	}
}

static int _sethook(lua_State *ctx) {
	luaL_checktype(ctx, 1, LUA_TTHREAD);
	lua_State *th = lua_tothread(ctx, 1);

	luaL_checktype(ctx, 2, LUA_TBOOLEAN);
	bool en = lua_tothread(ctx, 2);

	const char *smask = luaL_checkstring(ctx, 3);
	int cnt = luaL_optinteger(ctx, 3, 0);

	if (en) {
		lua_sethook(ctx, _hookfn, _makemask(smask, cnt), cnt);
	}
	else {
		lua_sethook(ctx, NULL, 0, 0);
	}

	return 0;
}

static int luaopen_nat_libhook(lua_State *ctx) {
	lua_pushcfunction(ctx, _sethook);
	return 1;
}

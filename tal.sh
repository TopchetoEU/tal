#!/bin/sh

ROOT=$(dirname "$0")

export FFI_ROOTS="$ROOT/deps/luajit/src;$ROOT/deps/libev/bin/Linux;$FFI_ROOTS"
export LUA_CROOTS="$ROOT/.prefix/lib/lua;$LUA_CROOTS"
export LUA_ROOTS="$ROOT/deps/luajit/src;$LUA_ROOTS"
# export LUA_PATH="$ROOT/lib/?.lua;$ROOT/lib/?/init.lua;$LUA_PATH;;"

if [ "$1" = "--gdb" ]; then
	shift 1
	exec gdb --args "$ROOT/deps/luajit/src/luajit" "$ROOT/lib/tal.lua" "$@"
else
	exec "$ROOT/deps/luajit/src/luajit" "$ROOT/lib/tal.lua" "$@"
fi


#!/bin/sh

ROOT=$(dirname "$0")

export FFI_ROOTS="$ROOT/deps/luajit/src;$ROOT/deps/libyaooi/bin/Linux;$FFI_ROOTS"
export LUA_CROOTS="$ROOT/.prefix/lib/lua;$LUA_CROOTS"
export LUA_ROOTS="$ROOT/deps/luajit/src;$LUA_ROOTS"
export LUA_PATH="$ROOT/deps/luajit/src/?.lua;$ROOT/deps/luajit/src/?/init.lua;$LUA_PATH;;"

LUAJIT="$ROOT/deps/luajit/src/luajit"
# LUAJIT=luajit

if [ "$1" = "--gdb" ]; then
	shift 1
	exec gdb --args "$LUAJIT" $LUAJIT_ARGS "$ROOT/lib/tal.lua" "$@"
elif [ "$1" = "--valgrind" ]; then
	shift 1
	exec valgrind --tool=memcheck "$LUAJIT" $LUAJIT_ARGS "$ROOT/lib/tal.lua" "$@"
elif [ "$1" = "--helgrind" ]; then
	shift 1
	exec valgrind --tool=helgrind "$LUAJIT" $LUAJIT_ARGS "$ROOT/lib/tal.lua" "$@"
else
	exec "$LUAJIT" $LUAJIT_ARGS "$ROOT/lib/tal.lua" "$@"
fi


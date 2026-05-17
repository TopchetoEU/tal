#!/usr/bin/env bash

ROOT=$(dirname "$0")

export FFI_ROOTS="$ROOT/deps/luajit/src;$ROOT/deps/libev/bin/Linux;$FFI_ROOTS"
export LUA_ROOTS="$ROOT/deps/luajit/src;$LUA_ROOTS"

# export LUA_PATH="$ROOT/lib/?.lua;$ROOT/lib/?/init.lua;$LUA_PATH;;"
exec "$ROOT/deps/luajit/src/luajit" "$ROOT/lib/tal.lua" "$@"

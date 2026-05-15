#!/usr/bin/env bash

ROOT=$(dirname "$0")

for el in "?" "?.so" "lib?.so"; do
	FFI_PATH="$ROOT/deps/luajit/src/$el;$ROOT/deps/libev/bin/Linux/$el;$FFI_PATH"
done
for el in "?" "?.a" "lib?.a"; do
	FFI_APATH="$ROOT/deps/luajit/src/$el;$ROOT/deps/libev/bin/Linux/$el;$FFI_APATH"
done

export FFI_PATH="$FFI_PATH;;"
export FFI_APATH="$FFI_APATH;;"
export LUA_PATH="$ROOT/deps/luajit/src/?.lua;$ROOT/deps/luajit/src/?/init.lua;$LUA_PATH;;"
export LUA_PATH="$ROOT/lib/?.lua;$ROOT/lib/?/init.lua;$LUA_PATH;;"
exec "$ROOT/deps/luajit/src/luajit" "$ROOT/lib/tal.lua" "$@"

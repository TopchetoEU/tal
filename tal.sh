#!/bin/env bash

ROOT=$(dirname "$0")

export FFI_PATH="$ROOT/deps/luajit/src/lib?.so;$ROOT/deps/libev/bin/Linux/lib?.so;;"
export LUA_PATH="$ROOT/lib/?.lua;$ROOT/lib/?/init.lua;$LUA_PATH"
exec "$ROOT/deps/luajit/src/luajit" "$ROOT/lib/tal.lua" "$@"

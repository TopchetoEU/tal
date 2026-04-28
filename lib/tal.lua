#!/bin/env luajit

local root = arg[0]:match "^(.*)/[^/]-$" or ".";
return (loadfile(root .. "/../lib/tal/entry.lua") or loadfile(root .. "/tal/entry.lua"))()("tal.cli", ...);

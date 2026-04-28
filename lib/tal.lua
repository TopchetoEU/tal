#!/bin/env luajit

local root = arg[0]:match "^(.*)/[^/]-$" or ".";
local loc = package.searchpath("tal.entry", package.path);
if loc then
	return require "tal.entry"("tal.cli", ...);
end
return (loadfile(root .. "/../lib/lua/tal/entry.lua") or loadfile(root .. "/tal/entry.lua"))()("tal.cli", ...);

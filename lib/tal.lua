#!/bin/env luajit
-- TAL bootstrap file. Mostly sets up path so that modules are located correctly
-- TODO: make this more isolatable

-- Initial setup of package.path

--- @type string
local root = arg[0]:match "^(.-)[\\/]*[^\\/]+[\\/]*$" or error "invalid arg[0]";
--- @type string
local sep = package.path:match "[/\\]";

local old_path = package.path
	:gsub("%.[\\/]%?%.lua;?", "")
	:gsub("%.[\\/]init[\\/]%?%.lua;?", "");

package.path = (root .. "/?.lua;" .. root .. "/?/init.lua;"):gsub("/", sep) .. old_path;

-- Setup initial "half-baked" roots with newly-accessible modules

local package = require "std.package";
require = package.require;

local path = require "std.path";

local function mkroots(root)
	return path.join(root, ".."), root;
end

local ffi = require "nat.ffi";

local ffi_root, lua_root = mkroots(root);
package.roots:insert(lua_root);
ffi.roots:insert(ffi_root);

-- Using new modules, use impl to get abs variants of root

local cwd = assert(require "impl":getpath "cwd");
root = path.cwd(cwd, root);

package.roots:delete(lua_root);
ffi.roots:delete(ffi_root);

ffi_root, lua_root = mkroots(root);
package.roots:insert(lua_root);
ffi.roots:insert(ffi_root);

package.path = package.overridepath(old_path, "@" .. sep .. "?.lua;@" .. sep .. "?" .. sep .."init.lua;;")

return require "tal.entry"("tal.cli", ...);

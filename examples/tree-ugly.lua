-- A simpler version of examples.tree

local fs = require "std.io.fs";
local path = require "std.path";

local function list(curr_path, depth)
	if assert(fs.stat(curr_path)).type ~= "dir" then return end

	for child in fs.readdir(curr_path) do
		local child_path = path.join(curr_path, child);
		io.stdout:write(("\t"):rep(depth), child, "\n");
		list(child_path, depth + 1);
	end
end

return function (path)
	if path == nil then
		print "Usage: tree.lua <path>";
	else
		list(path, 0);
	end
end


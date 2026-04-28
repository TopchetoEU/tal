-- An example tree printing program, that prints the structure of a given directory in a nice format
-- Most of the complexity comes from the pretty-printing part

local fs = require "std.io.fs";
local path = require "std.path";
local time = require "std.time";

-- local f = assert(io.open("test.txt", "w"));
local f = io.stdout;

local function list(dir_path, line, ...)
	f:write(line, "\n");
	if assert(fs.stat(dir_path)).type ~= "dir" then return end

	local children = {};
	for child in fs.readdir(dir_path) do
		table.insert(children, child);
	end

	for i = 1, #children do
		local child_path = path.join(dir_path, children[i]);

		for i = select("#", ...), 1, -1 do
			f:write((select(i, ...)));
		end

		if i == #children then
			f:write("└─ ");
			list(child_path, children[i], "   ", ...);
		else
			f:write("├─ ");
			list(child_path, children[i], "│  ", ...);
		end
	end
end

return function (path)
	if path == nil then
		print "Usage: tree.lua <path>";
	else
		list(path, path);
	end
end


local path;

if jit.os == "Windows" then
	path = require "std.path.dos";
else
	path = require "std.path.unix";
end

return path;

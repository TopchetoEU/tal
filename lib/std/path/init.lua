if jit.os == "Windows" then
	return require "std.path.dos";
else
	return require "std.path.unix";
end

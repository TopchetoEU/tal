local exports = {};

function exports.exists(path)
	local f = io.open(path, "r");
	if f == nil then return false end
	if f:read(1) == nil then return false end

	return true;
end

function exports.home()
	return os.getenv "HOME";
end

function exports.pwd()
	return os.getenv "PWD" or "./";
end

function exports.ls(path)
	return os.execute("ls ")
end

return exports;

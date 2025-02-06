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

--- @param path string
function exports.ls(path)
	local f = assert(io.popen("ls " .. path:quotesh()));
	local res = f:read "*a";
	f:close();
	return res;
end

return exports;

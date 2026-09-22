local zlib = require "std.proto.zlib";
local mem  = require "std.str.mem";

local function compress(data, level)
	local dst = mem.new();
	local conn = zlib.deflate_writer { backend = dst, owned = false, format = "raw", level = level }:to_text();
	conn:write(data);
	conn:close();
	return dst.data:tostring();
end
return function (fname)
	local data;
	if fname == "-" then
		data = io.stdin:read "a";
	else
		data = io.open(fname):read "a";
	end

	for level = 0, 9 do
		print("LVL", level, "IN", #data, "OUT", #compress(data, level));
	end
end

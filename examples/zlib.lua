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
	if fname == "--help" then
		print "Compresses a file with each zlib level and outputs the result size and coefficient";
		print "examples.zlib <file name>";
	end
	local data;
	if fname == "-" then
		data = io.stdin:read "a";
	else
		data = io.open(fname):read "a";
	end

	print "LVL %      IN           OUT";

	for level = 0, 9 do
		local res = #compress(data, level);
		print(("%d   %5.1f%% %-12d %-12d"):format(level, res * 100. / tonumber(#data), #data, res));
	end
end

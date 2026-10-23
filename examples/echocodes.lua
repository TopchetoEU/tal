local keys = require "std.con.keys";
local printing = require "std.con.printing";

return function ()
	local k = keys.new();

	local ok, err = spcall(function ()
		for evn in k:iter() do
			print(("%10s: key=%6s; chr=%7s; mod=%.2X"):format(
				evn.evn or "-",
				evn.key or "(-)",
				evn.chr and printing.stringify(utf8.encode(evn.chr)) or "(-)",
				evn.mod or 0));
			io.stderr:write "\r";

			if evn.key == string.byte "c" and (evn.mod & keys.modifiers.CTRL) ~= 0 then
				break
			end
		end
	end);
	if not ok then eprint(err) end

	k:fin();
end

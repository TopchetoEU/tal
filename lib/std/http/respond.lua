local http = require "std.http";
local headers = require "std.http.headers";

--- @param conn std.io.stream
--- @param code? integer
--- @param hdrs? std.http.headers
--- @param body? string | std.io.stream | fun(): string?
return function (conn, code, hdrs, body)
	hdrs = hdrs or headers.new();

	if type(body) == "table" then
		local ok, stat = pcall(body.stat, body);
		if ok and stat.type == "file" and stat.size >= 0 then
			hdrs:set("content-length", stat.size);
		end
	end

	local body_out = http.write_res(conn, { code = code or 200, headers = hdrs or headers.new() }, body ~= nil);

	if body then
		--- @cast body_out std.io.stream
		body_out:pipe(body);
		body_out:close();
	end

	conn:close();
	return true;
end

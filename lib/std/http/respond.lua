local http = require "std.http";
local headers = require "std.http.headers";

--- @param stream std.io.stream
--- @param code? integer
--- @param hdrs? http_headers
--- @param body? http_body
return function (stream, code, hdrs, body)
	local body_out, err = http.write_res(stream, code or 200, hdrs or headers.new(), body ~= nil);
	if not body_out then return nil, err end

	if body then
		--- @cast body_out std.io.stream
		local _, err = http.write_body(body_out, body);
		if not _ then return nil, err end
	else
		stream:close();
	end
	return true;
end

local http = require "std.http";
local headers = require "std.http.headers";
local ffi = require "nat.ffi";

--- @param conn std.str
--- @param code? integer
--- @param hdrs? std.http.headers
--- @param req_hdrs? std.http.headers
--- @param body? string | std.str | fun(): string?
return function (conn, code, hdrs, body, req_hdrs)
	hdrs = hdrs or headers.new();

	local etag = hdrs:get "etag";

	if type(body) == "table" then
		local ok, stat = pcall(body.stat, body);
		if ok then
			if stat.type == "file" then
				if stat.size >= 0 then
					hdrs:set("content-length", stat.size);
				end
			end

			if not etag and stat.mtime >= 0 then
				-- hdrs:set("last-modified", os.date("%a, %d %b %Y %H:%M:%S GMT", stat.mtime));
				-- Im so done with WWW's bullshit
				etag = "\"" .. tostring(stat.mtime) .. "\"";
			end
		end
	end

	if etag then
		hdrs:set("cache-control", "max-age=0, must-revalidate");
		hdrs:set("etag", etag);
	end

	if req_hdrs and req_hdrs:get "if-none-match" == etag then
		http.write_res(conn, { code = 304, headers = hdrs });
		return true;
	end

	local body_out = http.write_res(conn, { code = code or 200, headers = hdrs }, body ~= nil);

	if body then
		--- @cast body_out std.str

		if type(body) == "string" or getmetatable(body) == "buffer" then
			body_out:fullwrite(ffi.toptr(body));
		elseif type(body) == "function" then
			for el in body do
				body_out:fullwrite(ffi.toptr(el));
			end
		else
			body_out:pipe(body);
		end

		body_out:close();
	end

	conn:close();
	return true;
end

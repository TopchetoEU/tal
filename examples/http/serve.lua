-- Demonstrates a simple HTTP server, serving a given directory
-- - Using std.path, the requested path is contained within the root directory (no /../../../../etc/passwd possible)
-- - Using cooperative multithreading, processing multiple requests efficiently is made possible
-- - The code, as low level as it may be, is concise, for what it does

local io = require "std.io";
local http = require "std.http";
local loop = require "std.loop";
local respond = require "std.http.respond";
local path = require "std.path";
local url = require "std.fmt.url";
local fs = require "std.io.fs";
local headers = require "std.http.headers";
local net     = require "std.io.net"

local function send_dir(conn, get_path, file_path)
	local res_f = assert(http.write_res(conn, 200, headers.of {
		["Content-Type"] = "text/html",
	}, true));
	res_f:write("<!DOCTYPE html>\n");
	res_f:write("File contents of " .. get_path .. ":<ul>");

	res_f:write("<li><a href=\"./\">.</a></li>\n");
	res_f:write("<li><a href=\"../\">..</a></li>\n");

	for el in fs.readdir(file_path) do
		res_f:write("<li><a href=\"" .. (get_path .. "/"):gsub("//", "/") .. el .. "\">" .. el .. "</a></li>\n");
	end

	res_f:close();
end
local function send_not_found(conn)
	return assert(respond(conn, 404, nil, "Not found :/\n"));
end

return function (serve_path)
	if not serve_path then
		print("Usage: http-serve.lua <path>");
		return;
	end

	local server = assert(net.bind("0.0.0.0", 8080));

	while true do
		local conn = assert(server:next()).client;
		loop.fork(function (conn)
			local ok, err = xpcall(function ()
				local method, get_path, headers_req = assert(http.read_req(conn));
				if method ~= "GET" then
					return assert(respond(conn, 405));
				end

				get_path = url.parse_path(get_path);
				print("GET", get_path);

				local file_path = path.chroot(serve_path, get_path);

				local f = io.open(file_path, "r");
				if not f then return send_not_found(conn) end

				local stat = assert(f:stat());

				if stat.type == "dir" then
					f:close();
					return send_dir(conn, get_path, file_path);
				elseif stat.type == "file" then
					local ok, err = respond(conn, 200, nil, f);
					f:close();
					return assert(ok, err);
				else
					return send_not_found(conn);
				end
			end, debug.traceback);

			if not ok then
				print("Unhandled error: " .. tostring(err));
				return respond(conn, 500, nil, "Internal server error\n")
			end
		end, conn);
	end
end

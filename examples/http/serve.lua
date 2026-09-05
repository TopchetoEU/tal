-- Demonstrates a simple HTTP server, serving a given directory
-- - Using std.path, the requested path is contained within the root directory (no /../../../../etc/passwd possible)
-- - Using cooperative multithreading, processing multiple requests efficiently is made possible
-- - The code, as low level as it may be, is concise, for what it does

local io = require "std.io";
local http = require "std.http";
local loop = require "std.loop";
local respond = require "std.http.respond";
local path = require "std.path";
local url = require "std.http.url";
local fs = require "std.os.fs";
local headers = require "std.http.headers";
local net = require "std.os.net";
local signal = require "std.os.signal";

local function send_dir(conn, get_path, file_path)
	local res_f = http.write_res(conn, {
		code = 200,
		headers = headers.of { ["Content-Type"] = "text/html" }
	}, true):to_text();

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
	return respond(conn, 404, nil, "Not found :/\n");
end

return function (serve_path)
	signal.on "INT";
	signal.on "BADPIPE";

	loop.fork(function ()
		for sig in signal.wait do
			if sig == "INT" then
				io.stderr:write "Interrutped!";
				os.exit();
			end
		end
	end)

	if not serve_path then
		print("Usage: http-serve.lua <path>");
		return;
	end

	local server = net.bind("0.0.0.0", 8080);

	for conn in server:iter() do
		loop.fork(function ()
			local ok, err, trace = spcall(function ()
				local req = http.read_req(conn);
				if not req then return end

				if req.method ~= "GET" then return respond(conn, 405) end

				req.path = url.parse_path(req.path);
				print("GET", req.path);

				local file_path = path.chroot(serve_path, req.path);

				local ok, f = pcall(fs.open, file_path, "r");
				if not ok then return send_not_found(conn) end

				local stat = f:stat();

				if stat.type == "dir" then
					f:close();
					return send_dir(conn, req.path, file_path);
				elseif stat.type == "file" then
					return respond(conn, 200, nil, f);
				else
					return send_not_found(conn);
				end
			end);

			if not ok then
				eprint(err, trace, "in HTTP request handler");
				return respond(conn, 500, nil, "Internal server error\n")
			end
		end);
	end
end

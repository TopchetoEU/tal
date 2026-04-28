local headers = require "std.http.headers";
local fetch = require "std.http.fetch";
local io = require "std.io";

return function (...)
	local url;
	local method = "GET";
	local data;
	local hdrs = headers.new();

	local args = { ... };

	local function pop()
		return table.remove(args, 1);
	end

	for arg in pop do
		if arg == "--header" or arg == "-h" then
			hdrs:add(assert(pop(), "expected header name"), (assert(pop(), "expected header value")));
		elseif arg == "--method" or arg == "-m" then
			method = assert(pop(), "expected method");
		elseif arg == "--data" then
			data = assert(pop(), "expected data file");
		elseif arg:match "^%-%-" or url then
			error("unknown argument");
		else
			url = arg;
		end
	end

	assert(url, "expected a url to fetch");

	local f = nil;

	if data == "-" then
		f = io.stdin;
	elseif data then
		f = assert(io.open(data, "r"));
	end

	local res = assert(fetch {
		url = url,
		method = method,
		body = f,
		headers = hdrs,
	});

	for k in res.headers:keys() do
		print(k .. ": " .. table.concat({ res.headers:get(k) }, "; "));
	end

	if res.body then
		for part in res.body:lines("c") do
			io.write(part);
		end

		res.body:close();
	end
end

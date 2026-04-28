local headers = require "std.http.headers";
local fetch = require "std.http.fetch";
local io = require "std.io";
local argp = require "std.fmt.argp"

return function (...)
	local url;
	local method = "GET";
	local data;
	local hdrs = headers.new();

	local argv = argp.new(...);

	for arg, isopt in argv:iter() do
		if isopt then
			if arg == "--header" or arg == "-h" then
				hdrs:add(argv:pop(), argv:pop());
			elseif arg == "--method" or arg == "-m" then
				method = argv:pop();
			elseif arg == "--data" then
				data = argv:pop();
			else
				error("unknown option " .. arg);
			end
		elseif url then
			error("superfluous argument " .. arg);
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

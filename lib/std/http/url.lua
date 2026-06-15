local buffer = require "string.buffer";

--- @class url
--- @field scheme? string
--- @field username? string
--- @field password? string
--- @field host? string
--- @field port? integer
--- @field path string
--- @field params table<string, string | true>

local url = {};

function url.encode_path(data)
	data = tostring(data);
	return (data:gsub("[^/a-zA-Z0-9%-%.%+_]", function (c)
		return "%" .. ("%.2X"):format(string.byte(c));
	end));
end
function url.encode_param_key(data)
	data = tostring(data);
	return (data:gsub("[^%?=/&a-zA-Z0-9%-%.%+_]", function (c)
		return "%" .. ("%.2X"):format(string.byte(c));
	end));
end
function url.encode_param(data)
	data = tostring(data);
	return (data:gsub("[^%?/&a-zA-Z0-9%-%.%+_]", function (c)
		return "%" .. ("%.2X"):format(string.byte(c));
	end));
end

function url.decode(data)
	return (data:gsub("%%([a-zA-Z0-9][a-zA-Z0-9])", function (val)
		return string.char(assert(tonumber(val, 16)));
	end));
end

function url.encode_body(body)
	local parts = {};
	local passed = {};

	for i = 1, #body do
		if type(body[body[i]]) == "string" then
			table.insert(parts, url.encode_param_key(body[i]) .. "=" .. url.encode_param(body[body[i]]));
		else
			table.insert(parts, url.encode_param_key(body[i]));
		end

		passed[body[i]] = true;
	end

	for k, v in pairs(body) do
		if type(k) == "string" and not passed[k] then
			if type(v) == "string" then
				table.insert(parts, url.encode_param_key(k) .. "=" .. url.encode_param(v));
			else
				table.insert(parts, url.encode_param_key(k));
			end
		end
	end

	return table.concat(parts, "&");
end

--- @param raw string
--- @return table<string, string | true>
function url.parse_params(raw)
	if raw:find "^%?" then
		raw = raw:sub(2);
	end

	local res = {};

	for part in raw:gmatch "[^&]+" do
		local k, v = part:match "(.-)=(.*)";
		if not k then
			res[part] = true;
			table.insert(res, part);
		else
			res[k] = url.decode(v);
			table.insert(res, k);
		end
	end

	return res;
end

--- @param raw string
function url.parse_path(raw)
	local path = raw;
	local params;

	local q_i = raw:find "%?";
	if q_i then
		params = url.parse_params(raw:sub(q_i));
		path = raw:sub(1, q_i - 1);
	else
		params = {};
	end

	path = url.decode(path);

	return path, params;
end

--- @param raw string
--- @return url
function url.parse(raw)
	local scheme, username, password, host, port, path, params;

	local l;
	local i = 1;

	params = {};

	scheme, l = raw:match("^([%w%d_%-]+):()", i);
	i = l or i;

	if raw:match("^//", i) then
		i = i + 2;
		username, password, l = raw:match("^(.-):(.-)@()", i);
		i = l or i;

		if username then
			username = url.decode(username);
			password = url.decode(password);
		end

		host, i = raw:match("^([^:/]*)()", i);
		port, l = raw:match("^:(%d+)()", i);
		i = l or i;

		if host then
			host = url.decode(host);
		end
		if port then
			port = tonumber(port);
		end

		if i > #raw then
			return {
				scheme = scheme,
				username = username,
				password = password,
				host = host,
				port = tonumber(port),
				path = "/",
				params = {}
			};
		end

		i = raw:match("^()/", i);
	end

	if not i then error "invalid URL syntax" end

	path, i = raw:match("^([^?]*)()", i);
	params = url.parse_params(raw:sub(i));

	return {
		scheme = scheme,
		username = username,
		password = password,
		host = host,
		port = port,
		path = url.decode(path),
		params = params or {},
	};
end

--- @param parsed url
function url.stringify(parsed)
	local res = buffer.new();

	if parsed.scheme then
		res:put(parsed.scheme, ":");
	end

	if parsed.host then
		res:put("//");
		if parsed.username and parsed.password then
			res:put(parsed.username, ":", parsed.password "@");
		end

		res:put(parsed.host);

		if parsed.port then
			res:put(":", parsed.port);
		end
	end

	if not parsed.path:find "^/" then
		res:put("/");
	end

	res:put(url.encode_path(parsed.path));

	local encoded = url.encode_body(parsed.params);
	if #encoded > 0 then
		res:put("?", encoded);
	end

	return tostring(res);
end

return url;

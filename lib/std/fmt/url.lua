local url = {};

function url.encode(data)
	data = tostring(data);
	return data:gsub("[^a-zA-Z0-9%-_]", function (c)
		return "%" .. ("%.2X"):format(string.byte(c));
	end);
end
function url.encode_url(data)
	data = tostring(data);
	return data:gsub("[^%?/a-zA-Z0-9%-_]", function (c)
		return "%" .. ("%.2X"):format(string.byte(c));
	end);
end

function url.decode(data)
	return data:gsub("%%(%d%d)", function (val)
		return string.char(assert(tonumber(val, 16)));
	end);
end

function url.encode_body(body)
	local parts = {};

	for i = 1, #body do
		table.insert(parts, url.encode(body[i][1]) .. "=" .. url.encode(body[i][2]));
	end

	for k, v in pairs(body) do
		if type(k) == "string" then
			table.insert(parts, url.encode(k) .. "=" .. url.encode(v));
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
		else
			res[k] = url.decode(v);
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
--- @return { scheme: string?, host?: string, port?: integer, path: string, params: table<string, string | true>, username?: string, password?: string }?
--- @return string?
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

	if not i then return nil, "invalid URL syntax" end

	path, i = raw:match("^([^?]*)()", i);
	params = url.parse_params(raw:sub(i));

	return {
		scheme = scheme,
		username = username,
		password = password,
		host = host,
		port = port,
		path = path,
		params = params or {},
	};
end

return url;

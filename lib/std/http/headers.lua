--- @class std.http.headers
--- @field _map table<string, string[]>
local headers = {};
headers.__index = headers;
headers.__metatable = "std.http.headers";

--- @return (fun(self: std.http.headers, prev?: string): string?, ...: string?), std.http.headers
function headers:keys()
	--- @param prev string?
	--- @param self std.http.headers
	return function (self, prev)
		return (next(self._map, prev));
	end, self;
end
--- @param name string
function headers:get(name)
	local val = self._map[name:lower()];
	if not val then return end
	return table.unpack(val);
end
--- @param name string
--- @return string ...
function headers:add(name, ...)
	name = name:lower();
	if not self._map[name] then self._map[name] = {} end
	local val = self._map[name];

	for i = 1, select("#", ...) do
		assert(select(i, ...), "element can't be nil");
		table.insert(val, (select(i, ...)));
	end

	return table.unpack(val, 1);
end
--- @param name string
--- @return string ...
function headers:set(name, ...)
	self._map[name:lower()] = { ... };
	return ...;
end
--- @param name string
--- @return string ...
function headers:del(name, ...)
	name = name:lower();
	local val = self._map[name];
	self._map[name] = nil;
	if val then return table.unpack(val) end
end

function headers.new()
	return setmetatable({ _map = {} }, headers);
end
--- @param init table<string, string | string[]>
function headers.of(init)
	local res = headers.new();

	for k, v in pairs(init) do
		assert(type(k) == "string", "headers init key must be string");
		if type(v) == "string" then
			res:set(k, v);
		else
			res:set(k, table.unpack(v));
		end
	end

	return res;
end

return headers;

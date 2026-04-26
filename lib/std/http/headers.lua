--- @class http_headers
--- @field _map table<string, string[]>
local headers_index = {};
--- @return (fun(self: http_headers, prev?: string): string?, ...: string?), http_headers
function headers_index:keys()
	--- @param prev string?
	--- @param self http_headers
	return function (self, prev)
		return (next(self._map, prev));
	end, self;
end
--- @param name string
function headers_index:get(name)
	local val = self._map[name:lower()];
	if not val then return end
	return table.unpack(val);
end
--- @param name string
--- @return string ...
function headers_index:add(name, ...)
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
function headers_index:set(name, ...)
	self._map[name:lower()] = { ... };
	return ...;
end
--- @param name string
--- @return string ...
function headers_index:del(name, ...)
	name = name:lower();
	local val = self._map[name];
	self._map[name] = nil;
	if val then return table.unpack(val) end
end

local headers_meta = { __index = headers_index };

--- @class http_headers_lib
local headers = {};
--- @return http_headers
function headers.new()
	return setmetatable({ _map = {} }, headers_meta);
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

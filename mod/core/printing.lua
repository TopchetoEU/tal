local function escape_str(s)
	local in_char = { "\\", "\"", "/", "\b", "\f", "\n", "\r", "\t" };
	local out_char = { "\\", "\"", "/", "b", "f", "n", "r", "t" };
	for i, c in ipairs(in_char) do
		s = s:gsub(c, "\\" .. out_char[i]);
	end
	return s
end

local function stringify_impl(obj, indent_str, n, passed)
	local parts = {};
	local kind = type(obj);

	if kind == "table" then
		if passed[obj] then return "<circular>" end
		passed[obj] = true;

		local len = #obj;

		for i = 1, len do
			parts[i] = stringify_impl(obj[i], indent_str, n + 1, passed) .. ",";
		end

		local keys = {};

		for k, v in pairs(obj) do
			if type(k) ~= "number" or k > len then
				keys[#keys + 1] = { k, v };
			end
		end

		table.sort(keys, function (a, b)
			if type(a[1]) == "number" and type(b[1]) == "number" then
				return a[1] < b[1];
			elseif type(a[1]) == "string" and type(b[1]) == "string" then
				return a[1] < b[1];
			else
				return type(a[1]) < type(b[1]) or tostring(a[1]) < tostring(b[1]);
			end
		end);

		for i = 1, #keys do
			local k = keys[i][1];
			local v = keys[i][2];

			local val = stringify_impl(v, indent_str, n + 1, passed);
			if val ~= nil then
				if type(k) == "string" then
					parts[#parts + 1] = table.concat { k, ": ", val, "," };
				else
					parts[#parts + 1] = table.concat { "[", stringify_impl(k, indent_str, n + 1, passed), "]: ", val, "," };
				end
			end
		end

		local meta = getmetatable(obj);
		if meta ~= nil and meta ~= arrays then
			parts[#parts + 1] = "<meta> = " .. stringify_impl(meta, indent_str, n + 1, passed) .. ",";
		end

		passed[obj] = false;

		if #parts == 0 then
			if meta == arrays then
				return "[]";
			else
				return "{}";
			end
		end

		local contents = table.concat(parts, " "):sub(1, -2);
		if #contents > 80 then
			local indent = "\n" .. string.rep(indent_str, n + 1);

			contents = table.concat {
				indent,
				table.concat(parts, indent),
				"\n", string.rep(indent_str, n)
			};
		else
			contents = " " .. contents .. " ";
		end

		if meta == arrays then
			return table.concat { "[", contents, "]" };
		else
			return table.concat { "{", contents, "}" };
		end
	elseif kind == "string" then
		return "\"" .. escape_str(obj) .. "\"";
	elseif kind == "function" then
		local data = debug.getinfo(obj, "S");
		return table.concat { tostring(obj), " @ ", data.short_src, ":", data.linedefined };
	elseif kind == "nil" then
		return "nil";
	else
		return tostring(obj);
	end
end

--- Turns the given value to a human-readable string.
--- Should be used only for debugging and display purposes
local function to_readable(obj, indent_str)
	return stringify_impl(obj, indent_str or "    ", 0, {});
end

local function print(...)
	for i = 1, select("#", ...) do
		if i > 1 then
			io.stderr:write("\t");
		end

		io.stderr:write(tostring((select(i, ...))));
	end

	io.stderr:write("\n");
end

--- Prints the given values in a human-readable manner to stderr
--- Should be used only for debugging
local function pprint(...)
	if select("#", ...) == 0 then
		io.stderr:write "<nothing>\n";
	else
		for i = 1, select("#", ...) do
			if i > 1 then
				io.stderr:write "\t";
			end

			io.stderr:write(to_readable((select(i, ...))));
		end

		io.stderr:write "\n";
	end
end

return function (glob)
	glob.to_readable = to_readable;
	glob.print = print;
	glob.pprint = pprint;
end

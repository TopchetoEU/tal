local debug = require "std.basic.debug";

local default_colors = {
	kw = "\x1B[34m",
	func = "\x1B[93m",
	str = "\x1B[32m",
	num = "\x1B[33m",
	bool = "\x1B[34m",
	["nil"] = "\x1B[34m",
	meta = "\x1B[90m",
	ref = "\x1B[91m",
	reset = "\x1B[0m",
};
local str_escape_codes = {
	["\x00"] = "\\0",
	["\x01"] = "\\x01",
	["\x02"] = "\\x02",
	["\x03"] = "\\x03",
	["\x04"] = "\\x04",
	["\x05"] = "\\x05",
	["\x06"] = "\\x06",
	["\x07"] = "\\x07",
	["\x08"] = "\\x08",
	["\x09"] = "\\t",
	["\x0A"] = "\\n",
	["\x0B"] = "\\x0B",
	["\x0C"] = "\\x0C",
	["\x0D"] = "\\r",
	["\x0E"] = "\\x0E",
	["\x0F"] = "\\x0F",

	["\x10"] = "\\x10",
	["\x11"] = "\\x11",
	["\x12"] = "\\x12",
	["\x13"] = "\\x13",
	["\x14"] = "\\x14",
	["\x15"] = "\\x15",
	["\x16"] = "\\x16",
	["\x17"] = "\\x17",
	["\x18"] = "\\x18",
	["\x19"] = "\\x19",
	["\x1A"] = "\\x1A",
	["\x1B"] = "\\x1B",
	["\x1C"] = "\\x1C",
	["\x1D"] = "\\x1D",
	["\x1E"] = "\\x1E",
	["\x1F"] = "\\x1F",

	["\\"] = "\\\\",
	["\""] = "\\\"",

	["\x7F"] = "\\x7F",
	["\xFF"] = "\\xFF",
};

--- @alias tal.printing.color fun(color: string): fun(str: string): string, integer

--- @param colors? table<string, string>
--- @return string
--- @return integer text_len
local function stringify_int (obj, n, colors, passed, hit, max_line)
	local kind = type(obj);

	local color;

	do
		local function noop(v)
			return v, #v;
		end

		if colors then
			function color(name)
				if colors[name] then
					local fmt = colors[name];
					return function(text)
						return fmt .. text .. colors.reset, #text;
					end
				else
					return noop;
				end
			end
		else
			function color(name)
				return noop;
			end
		end
	end

	if kind == "table" then
		if passed[obj] then
			hit[obj] = true;
			return color "ref" ("<circular " .. passed[obj] .. ">");
		end

		passed[obj] = passed.next;
		passed.next = passed.next + 1;

		local tablen = #obj;
		local parts = {};
		local res_len = 0;

		for i = 1, tablen do
			local curr_len;
			parts[i], curr_len = stringify_int(obj[i], n .. "    ", colors, passed, hit, max_line - 4);
			parts[i] = parts[i] .. ",";
			res_len = res_len + curr_len;
		end

		local keys = {};

		for k in pairs(obj) do
			if type(k) ~= "number" or k < 1 or k > tablen then
				table.insert(keys, k);
			end
		end

		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then
				return type(a) < type(b);
			else
				local ok, res = pcall(function(a, b) return a < b end);
				if ok then return res end

				return tostring(a) < tostring(b);
			end
		end);

		for i = 1, #keys do
			local k = keys[i];
			local v = obj[k];

			local val, val_len = stringify_int(v, n .. "    ", colors, passed, hit, max_line - 4);
			if val ~= nil then
				if type(k) == "string" and k:find "^[a-zA-Z_][a-zA-Z0-9_]*$" then
					res_len = res_len + #k + 3 + val_len + 1;
					table.insert(parts, k .. " = " .. val .. ",");
				else
					local key, key_len = stringify_int(k, n .. "    ", colors, passed, hit, max_line - 4);
					res_len = res_len + 1 + key_len + 4 + val_len + 1;
					table.insert(parts, "[" .. key .. "] = " .. val .. ",");
				end
			end
		end

		local meta = getmetatable(obj);
		if meta ~= nil and type(meta) ~= "string" then
			local meta_str, meta_len = stringify_int(meta, n .. "    ", colors, passed, hit, max_line - 4);
			res_len = res_len + 6 + 3 + meta_len + 1;
			table.insert(parts, color "meta" ("<meta>") .. " = " .. meta_str .. ",");
		end

		local prefix = "";
		local prefix_n = 0;

		if hit[obj] ~= nil then
			prefix = prefix .. color "ref" ("<ref " .. passed[obj] .. "> ");
			prefix_n = prefix_n + 4 + #tostring(hit[obj]) + 2;
		end

		if type(meta) == "string" then
			prefix = prefix .. color "func" (meta) .. " ";
			prefix_n = prefix_n + #meta + 1;
		end

		if #parts == 0 then
			return prefix .. "{}", prefix_n + 2;
		end

		local contents;
		if res_len > max_line then
			local indent = "\n" .. n .. "    ";

			contents = indent .. table.concat(parts, indent) .. "\n" .. n;
			res_len = res_len + #parts * #n * 8;
		else
			contents = " " .. table.concat(parts, " "):sub(1, -2) .. " ";
		end

		return prefix .. "{" .. contents .. "}", prefix_n + 1 + res_len + 1;
	elseif kind == "function" then
		local data = debug.getinfo(obj, "Sn") --[[@as debuginfo]];
		local res = color "kw" "function";
		local res_len = 8;

		if data.name then
			res = res .. " " .. color "func" (data.name);
			res_len = res_len + 1 + #data.name;
		end

		if data.source ~= "=?" and data.source ~= "=[C]" then
			res = res .. " @ " .. data.short_src;
			res_len = res_len + 3 + #data.short_src;

			if data.linedefined then
				res = res .. ":" .. data.linedefined;
				res_len = res_len + 1 + #tostring(data.linedefined);
				if data.coldefined then
					res = res .. ":" .. data.coldefined;
					res_len = res_len + 1 + #tostring(data.coldefined);
				end
			end
		end

		return res, res_len;
	elseif kind == "string" then
		local escaped, n = obj:gsub("[\x01-\x1F\"\\\x7F\xFF]", str_escape_codes);
		if n > 4 and n > #obj / 80 then
			local marker = obj:match "%](%=*)%]";

			for curr in obj:gmatch "%](%=*)%]" do
				if not marker or #marker < #curr then
					marker = curr;
				end
			end

			if not marker then
				marker = "";
			else
				marker = marker .. "=";
			end
			return color "str" ("[" .. marker .. "[" .. obj .. "]" .. marker .. "]");
		else
			return color "str" ("\"" .. escaped .. "\"");
		end
	elseif kind == "nil" then
		return color "nil" ("nil");
	elseif kind == "boolean" then
		return color "bool" (tostring(obj));
	elseif kind == "number" then
		return color "num" (tostring(obj));
	elseif kind == "thread" then
		return color "kw" (tostring(obj));
	elseif kind == "userdata" then
		return color "kw" (tostring(obj));
	elseif kind == "cdata" then
		return color "kw" (tostring(obj));
	else
		error "unknown type";
	end
end

local printing = {};

--- @param colors? boolean | table
function printing.stringify (obj, colors)
	if colors == nil or colors == true then
		colors = default_colors;
	elseif colors == false then
		colors = nil;
	end
	return stringify_int(obj, "", colors --[[@as table]], { next = 0 }, {}, 120);
end

function printing.print (...)
	if select("#", ...) == 0 then
		return;
	elseif select("#", ...) == 1 then
		assert(io.stderr:write(tostring(...), "\n"));
	else
		assert(io.stderr:write(tostring(...), "\t"));
		return print(select(2, ...));
	end
end

function printing.pprint (...)
	if select("#", ...) == 0 then return end

	local function fix (...)
		if select("#", ...) == 0 then
			return;
		else
			return printing.stringify((...), true), fix(select(2, ...));
		end
	end

	print(fix(...));
end

function printing.eprint(err, trace, reason, write)
	local res = {};

	table.insert(res, "Unhandled error ");
	if reason then table.insert(res, ("(" .. reason .. ") ")) end
	if type(err) == "string" then
		table.insert(res, err);
	else
		table.insert(res, (printing.stringify(err)));
	end

	if trace then
		table.insert(res, "\n" .. trace);
	end

	(write or print)(table.concat(res));
end

return printing;

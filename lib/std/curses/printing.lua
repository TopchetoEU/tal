local debug = require "std.basic.debug";
local errors = require "std.errors";
local ansi = require "std.curses.ansi";
local no_ansi = require "std.curses.noansi";

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

--- @param codes table<string, string>
--- @return string
--- @return integer text_len
local function stringify_int(obj, n, codes, passed, hit, max_line)
	local kind = type(obj);

	local color = 1;

	if kind == "table" then
		local prefix = "";
		local prefix_n = 0;

		local rawmeta = debug.getmetatable(obj);
		local meta = getmetatable(obj);

		if rawmeta and rawmeta.__tostring then
			if type(meta) == "string" then
				prefix = prefix .. codes.func .. meta .. codes.reset .. " ";
				prefix_n = prefix_n + #meta + 1;
			end

			local str = tostring(obj);

			return prefix .. str, prefix_n + #str;
		end

		if passed[obj] then
			hit[obj] = true;
			return codes.ref .. "<circular " .. passed[obj] .. ">" .. codes.reset, 10 + #tostring(passed[obj]) + 1;
		end

		passed[obj] = passed.next;
		passed.next = passed.next + 1;

		local tablen = #obj;
		local parts = {};
		local res_len = 0;

		for i = 1, tablen do
			local curr_len;
			parts[i], curr_len = stringify_int(obj[i], n .. "    ", codes, passed, hit, max_line - 4);
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

			local val, val_len = stringify_int(v, n .. "    ", codes, passed, hit, max_line - 4);
			if val ~= nil then
				if type(k) == "string" and k:find "^[a-zA-Z_][a-zA-Z0-9_]*$" then
					res_len = res_len + #k + 3 + val_len + 1;
					table.insert(parts, k .. " = " .. val .. ",");
				else
					local key, key_len = stringify_int(k, n .. "    ", codes, passed, hit, max_line - 4);
					res_len = res_len + 1 + key_len + 4 + val_len + 1;
					table.insert(parts, "[" .. key .. "] = " .. val .. ",");
				end
			end
		end

		if meta ~= nil and type(meta) ~= "string" then
			local meta_str, meta_len = stringify_int(meta, n .. "    ", codes, passed, hit, max_line - 4);
			res_len = res_len + 6 + 3 + meta_len + 1;
			table.insert(parts, codes.meta .. "<meta>" .. codes.reset .. " = " .. meta_str .. ",");
		end

		if hit[obj] ~= nil then
			prefix = prefix .. codes.ref .. "<ref " .. passed[obj] .. ">" .. codes.reset .. " ";
			prefix_n = prefix_n + 4 + #tostring(hit[obj]) + 2;
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
		local res = codes.kw .. "function" .. codes.reset;
		local res_len = 8;

		if data.name then
			res = res .. " " .. codes.func .. data.name .. codes.reset;
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
		local escaped, n = obj:gsub("[%z\x01-\x1F\"\\\x7F\xFF]", str_escape_codes);
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
			return codes.str .. "[" .. marker .. "[" .. obj .. "]" .. marker .. "]" .. codes.reset, 1 + #marker + 1 + #obj + 1 + #marker + 1;
		else
			return codes.str .. "\"" .. escaped .. "\"" .. codes.reset, 2 + #escaped;
		end
	elseif kind == "nil" then
		return codes["nil"] .. "nil" .. codes.reset, 3;
	elseif kind == "boolean" then
		return codes.bool .. tostring(obj) .. codes.reset, #tostring(obj);
	elseif kind == "number" then
		return codes.num .. tostring(obj) .. codes.reset, #tostring(obj);
	elseif kind == "thread" then
		return codes.kw .. tostring(obj) .. codes.reset, #tostring(obj);
	elseif kind == "userdata" then
		return codes.kw .. tostring(obj) .. codes.reset, #tostring(obj);
	elseif kind == "cdata" then
		return codes.kw .. tostring(obj) .. codes.reset, #tostring(obj);
	else
		error(errors.never);
	end
end

local printing = {};

--- @param colors? boolean = false
function printing.stringify(obj, colors)
	local our_ansi = colors and ansi or no_ansi;
	local codes = {
		kw = our_ansi.gen_color(true, "blue"),
		func = our_ansi.gen_color(true, "light_yellow"),
		str = our_ansi.gen_color(true, "green"),
		num = our_ansi.gen_color(true, "yellow"),
		bool = our_ansi.gen_color(true, "blue"),
		["nil"] = our_ansi.gen_color(true, "blue"),
		meta = our_ansi.gen_color(true, "light_black"),
		ref = our_ansi.gen_color(true, "red"),
		reset = our_ansi.reset,
	};

	return stringify_int(obj, "", codes, { next = 0 }, {}, 120);
end

function printing.print(...)
	if select("#", ...) == 0 then
		return;
	elseif select("#", ...) == 1 then
		assert(io.stderr:write(tostring(...), "\n"));
	else
		assert(io.stderr:write(tostring(...), "\t"));
		return print(select(2, ...));
	end
end

function printing.pprint(...)
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

function printing.eprint(e, reason, write)
	local res = {};

	table.insert(res, "Unhandled ");
	if reason then table.insert(res, ("(" .. reason .. ") ")) end
	if type(e) == "string" or debug.getmetatable(e) and debug.getmetatable(e).__tostring then
		table.insert(res, tostring(e));
	else
		table.insert(res, (printing.stringify(e, true)));
	end

	(write or print)(table.concat(res));
end

return printing;

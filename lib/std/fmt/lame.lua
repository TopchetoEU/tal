-- Parses a stripped down, lua-adopted YAML variant (thusly named, lame)
-- Syntax differences with YAML:
-- - no {} and [] literals
-- - only string, number, bool and nil literals allowed
-- - string literals may be of the form "text", 'text', text (if not a keyword)
-- - multiline literals may be prefixed with > (removes indentation parts, DOES NOT INSERT SPACES BETWEEN LINES) or | (emits all indentation)
-- - an object may be a mix of list and key entries, which is also allowed in lua
-- - numeric and boolean keys may be used, also allowed in lua
-- - comments are a '#', which ignores itself and everything after it until the end of the line
-- - relaxed, python-like indentation rules


local lex = require "std.compiler.lex";
local ffi = require "nat.ffi";

local err_meta = { __metatable = "laml.error" };
local function throw(i, msg)
	error(setmetatable({ i = i, msg = msg }, err_meta));
end

local parse_table;

--- @param src string
--- @param i integer
local function skip_white(src, i)
	local j = i;

	j = src:match("^[ \r\t]*()", j) --[[@as integer]];

	if src:sub(j, j) == "#" then
		j = j + 1;
		j = src:match("^[^\n]*()", j) --[[@as integer]];
	end

	return j;
end
--- @param src string
--- @param i integer
local function parse_eol(src, i)
	local j = i;

	j = skip_white(src, j);

	if src:sub(j, j) == "\n" or j > #src then
		return j, true;
	else
		return i;
	end
end
--- @param src string
--- @param i integer
--- @param prefix? string
local function parse_indent(src, i, prefix, forced)
	local j = i;
	local curr_indent;
	local bad_i = j;

	while true do
		curr_indent = src:match("^[ \r\t]*", j) or "";
		bad_i = j;
		j = j + #curr_indent;

		if src:sub(j, j) == "#" then
			j = j + 1;
			j = src:match("^[^\n]*()", j) --[[@as integer]];
		end

		if src:sub(j, j) ~= "\n" then break end
		j = j + 1;
	end

	if prefix then
		if #curr_indent > #prefix then
			if curr_indent:sub(1, #prefix) ~= prefix then
				throw(j - #curr_indent, "inconsistent indentation");
			end
		else
			if curr_indent ~= prefix:sub(1, #curr_indent) then
				throw(j - #curr_indent, "inconsistent indentation");
			end

			-- We exit with a failure, as we have read a conforming, yet shorter indentation
			return bad_i, nil;
		end
	end

	if forced and curr_indent ~= forced then
		return bad_i;
	end

	return j, curr_indent;
end

--- @param src string
--- @param i integer
--- @param eol boolean
--- @return integer, string?
local function parse_str(src, i, eol)
	local j = i;

	-- Avoid parsing lua-style [[...]] literals
	if not src:match("^['\"]", j) then return i end

	-- TODO: expose module with generic whitespace-skippers and literal parsers, instead of doing *this*
	local ok, j, res = spcall(lex.parse_string, { lines = { 1 }, n = i, src = ffi.cast("char*", src) }, i - 1);
	if not ok then
		if getmetatable(j) == "lex.error" then
			throw(i, j.msg);
		else
			srethrow(j, res);
		end
	end

	j = j + 1;
	if not res then return i end

	if eol then
		local eol;
		j, eol = parse_eol(src, j);
		if not eol then return i end
	end

	return j, res;
end
--- @param src string
--- @param i integer
--- @param eol boolean
--- @return integer, number?
local function parse_num(src, i, eol)
	local j = i;

	local mul = 1;
	if src:sub(j, j) == "-" then
		mul = -1;
		j = j + 1;
	end

	-- TODO: expose module with generic whitespace-skippers and literal parsers, instead of doing *this*
	local ok, j, kind, val = spcall(lex.parse_number, { lines = { 1 }, n = i, src = ffi.cast("char*", src) }, j - 1);
	if not ok then
		if getmetatable(j) == "lex.error" then
			throw(i, j.msg);
		else
			srethrow(j, kind);
		end
	end

	j = j + 1;
	if not val then return i end

	if eol then
		local eol;
		j, eol = parse_eol(src, j);
		if not eol then return i end
	end

	return j , val * mul;
end
--- @param src string
--- @param i integer
local function parse_words(src, i, badwords)
	local j = i;
	local words = {};

	while true do
		local word = src:match("^[^%s#" .. badwords .. "]+", j);
		if not word then break end
		j = j + #word;

		table.insert(words, word);
		j = skip_white(src, j);
	end

	if #words == 0 then return i end

	local res = table.concat(words, " ");

	if res == "true" then
		return j, true, true;
	end
	if res == "false" then
		return j, true, false;
	end
	if res == "nil" then
		return j, true, nil;
	end

	return j, true, res;
end
local function parse_key(src, i)
	local j, str = parse_str(src, i, false);
	if str then return j, true, str end

	local j, num = parse_num(src, i, false);
	if num then return j, true, num end

	local j, ok, word = parse_words(src, i, ":");
	if ok then return j, ok, word end

	return i;
end
local function parse_val(src, i, indent)
	local j, str = parse_str(src, i, true);
	if str then return j, true, str end

	local j, num = parse_num(src, i, true);
	if num then return j, true, num end

	local j, ok, word = parse_words(src, i, "");
	if ok then return j, true, word end

	local j, obj = parse_table(src, i, indent);
	if obj then return j, true, obj end

	return i;
end

--- @param src string
--- @param i integer
--- @param indent? string
--- @return integer i
--- @return table
function parse_table(src, i, indent)
	local j = i;

	local enforced;
	local obj = {};
	local n = 0;

	while true do
		j, enforced = parse_indent(src, j, indent, enforced);
		if not enforced then break end
		if j > #src then break end

		local ok, key, val;

		if src:sub(j, j) == "-" then
			j, key = parse_num(src, j, false);
			if key then
				j = skip_white(src, j);

				if src:sub(j, j) ~= ":" then throw(j, "expected ':'") end
				j = j + 1;
			else
				j = j + 1;
				n = n + 1;
				key = n;
			end
		else
			j, ok, key = parse_key(src, j);
			if not ok then throw(j, "expected number, string, 'true', 'false' or '-' for list entry") end

			if key == nil then throw(j, "key may not be nil") end

			j = skip_white(src, j);

			if src:sub(j, j) ~= ":" then throw(j, "expected ':'") end
			j = j + 1;
		end

		j = skip_white(src, j);

		j, ok, val = parse_val(src, j, enforced);
		if not ok then throw(j, "expected value") end

		--- @diagnostic disable-next-line: need-check-nil
		obj[key] = val;
	end

	return j, obj;
end

--- @param src string
return function (src)
	local ok, j, res = spcall(parse_table, src, 1, nil);
	if not ok then
		if getmetatable(j) == "laml.error" then
			ierror("lame error at " .. j.i .. ": " .. j.msg);
		else
			srethrow(j, res);
		end
	end

	return res;
end

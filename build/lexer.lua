local TOK_ID = 1;
local TOK_OP = 2;
local TOK_STR = 3;
local TOK_NUM = 4;

local operators = {
	AND = 1,
	OR = 2,
	NOT = 3,

	CONCAT = 10,
	ADD = 11,
	SUB = 12,
	MUL = 13,
	DIV = 14,
	IDIV = 15,
	MOD = 16,

	B_AND = 20,
	B_OR = 21,
	B_XOR = 22,
	B_LSH = 24,
	B_RSH = 25,
	RSH = 26,

	EQ = 30,
	NEQ = 31,
	LEQ = 32,
	GEQ = 33,
	LESS = 34,
	GR = 35,

	PAREN_OPEN = 40,
	PAREN_CLOSE = 41,
	BRACKET_OPEN = 42,
	BRACKET_CLOSE = 43,
	BRACE_OPEN = 44,
	BRACE_CLOSE = 45,

	SEMICOLON = 50,
	COLON = 51,
	COMMA = 52,
	DOT = 53,
	SPREAD = 54,
	-- QUESTION = 55,

	ASSIGN = 60,
	ASSIGN_OR = 75,
};
local op_map = {
	["+"] = { operators.ADD },
	["-"] = { operators.SUB },

	["*"] = {
		operators.MUL,
		["*"] = { operators.POW },
	},
	["/"] = {
		operators.DIV,
		["/"] = { operators.IDIV },
	},
	["%"] = { operators.MOD },

	["&"] = { operators.B_AND },
	["|"] = {operators.B_OR },

	["^"] = { operators.POW },
	["~"] = {
		operators.B_XOR,
		["="] = { operators.NEQ },
	},

	[">"] = {
		operators.GR,
		[">"] = {
			operators.RSH,
			[">"] = { operators.B_RSH },
		},
	},
	["<"] = {
		operators.LESS,
		["<"] = { operators.B_LSH },
	},

	["="] = {
		operators.ASSIGN,
		["="] = { operators.EQ },
	},

	[","] = { operators.COMMA },
	["."] = { operators.DOT },
	[";"] = { operators.SEMICOLON },
	[":"] = { operators.COLON },
	["?"] = { operators.QUESTION },

	["("] = { operators.PAREN_OPEN },
	[")"] = { operators.PAREN_CLOSE },
	["["] = { operators.BRACKET_OPEN },
	["]"] = { operators.BRACKET_CLOSE },
	["{"] = { operators.BRACE_OPEN },
	["}"] = { operators.BRACE_CLOSE },
};

local to_byte = string.byte;

--- @class tok_base
--- @field loc string
--- @field end_loc string
--- @field comments string[]
--- @field raw string

--- @class tok_id: tok_base
--- @field type 1
--- @field val string

--- @class tok_op: tok_base
--- @field type 2
--- @field val integer

--- @class tok_str: tok_base
--- @field type 3
--- @field val string

--- @class tok_num: tok_base
--- @field type 4
--- @field val number

---@param base tok_base
---@param id string
---@return tok_id
local function tok_id(base, id)
	base = base or { loc = "", comments = {} };
	return {
		loc = base.loc,
		comments = base.comments,
		type = TOK_ID,
		val = id,
	}
end

---@param base tok_base
---@param op integer
---@return tok_str
local function tok_op(base, op)
	base = base or { loc = "", comments = {} };
	return {
		loc = base.loc,
		comments = base.comments,
		type = TOK_OP,
		val = op,
	}
end

---@param base tok_base?
---@param data string
---@return tok_str
local function tok_str(base, data)
	base = base or { loc = "", comments = {} };
	return {
		loc = base.loc,
		comments = base.comments,
		type = TOK_STR,
		val = data,
	};
end

---@param base tok_base
---@param num number
---@return tok_num
local function tok_num(base, num)
	base = base or { loc = "", comments = {} };
	return {
		loc = base.loc,
		comments = base.comments,
		type = TOK_NUM,
		val = num,
	};
end

--- @alias token
--- | tok_id
--- | tok_op
--- | tok_str
--- | tok_num

---@param loader string | fun(): string
---@return fun(): string?
local function char_supplier(loader)
	if type(loader) == "string" then
		local i = 0;

		return function ()
			i = i + 1;
			local res = string.sub(loader, i, i);
			if #res == 1 then return res end
		end
	else
		local curr_str;
		local i = 0;

		return function ()
			if curr_str == "" then return nil end

			i = i + 1;
			if curr_str == nil or i > #curr_str then
				curr_str = loader();
				if curr_str == false or curr_str == nil or curr_str == "" then
					curr_str = "";
					return nil;
				end
				i = 1;
			end

			return string.sub(curr_str, i, i);
		end
	end
end

---@param filename string
---@param chars fun(): string | nil
---@return fun(): token?
local function token_supplier(filename, chars, get_comments)
	local line = 1;
	local start = 1;

	local _chars = chars;
	chars = function ()
		local c = _chars();
		if c == "\n" then
			line = line + 1;
			start = 1;
		else
			start = start + 1;
		end
		return c;
	end

	local function unconsume(c)
		if c == nil then return end

		local old_chars = chars;

		start = start - 1;
		chars = function ()
			chars = old_chars;
			start = start + 1;
			return c;
		end
	end

	local consume_white;

	if get_comments then
		local function consume_comment()
			-- local data = {};
			-- local c = chars();

			-- if c == "[" then
			-- 	while true do
			-- 		if c == nil then
			-- 			return nil, "Unclosed comment";
			-- 		elseif c == "]" and chars() == "#" then
			-- 			break;
			-- 		end
			-- 		data[#data + 1] = c;
			-- 		c = chars();
			-- 	end
			-- else
			-- 	while true do
			-- 		if c == "\n" or c == nil then break end
			-- 		data[#data + 1] = c;
			-- 		c = chars();
			-- 	end
			-- end

			-- return table.concat(data);

			local data = array {};

			local function singleline(c)
				while true do
					if c == "\n" or c == nil then break end
					data:push(c);
					c = chars();
				end

				return data:join "";
			end
			local function multiline_end()
				if chars() ~= "]" then return false end
				if chars() ~= "-" then return false end
				if chars() ~= "-" then return false end

				return true
			end
			local function multiline()
				while true do
					local c = chars()
					if c == "]" and multiline_end() then
						break;
					elseif c == nil then
						return nil, "Missing ]]";
					end

					data:push(c);
				end

				return data:join "";
			end

			local c = chars()

			if c == "[" then
				c = chars()
				if c == "[" then
					return multiline();
				else
					return singleline(c);
				end
			else singleline(c) end

			return data:join "";
		end
		---@return false | string[]?, string?
		function consume_white()
			local comments = {};

			while true do
				local c = chars();

				if c == nil then
					chars = function () return nil end
					break;
				elseif start == 2 and line == 1 and c == "#" then
					local c2 = chars();

					if c2 == "!" then
						while c ~= "\n" do
							c = chars();
						end
					else
						unconsume(c2);
						unconsume(c);
					end
				elseif c == "-" then
					local c2 = chars()

					if c2 == "-" then
						local res, err = consume_comment();
						if res == nil then return nil, err end
						comments[#comments + 1] = res;
					else
						unconsume(c2)
						unconsume(c)
						break
					end
				elseif not string.find(c, "%s") then
					unconsume(c);
					break;
				end
			end

			return comments;
		end
	else
		---@return string?
		local function consume_comment()
			local c = chars();

			if c == "[" then
				while true do
					c = chars();
					if c == nil then
						return "Unclosed comment";
					elseif c == "]" and chars() == "#" then break end
				end
			else
				while true do
					if c == "\n" or c == nil then break end
					c = chars();
				end
			end
		end
		---@return false | string[]?, string?
		function consume_white()
			while true do
				local c = chars();

				if c == nil then
					chars = function () return nil end
					break;
				elseif c == "#" then
					local err = consume_comment();
					if err ~= nil then return nil, err end
				elseif not string.find(c, "%s") then
					unconsume(c);
					break;
				end
			end

			return false;
		end
	end

	local function hex_one(c)
		local b = to_byte(c)
		if b >= 48 and b <= 57 then
			return b - 48
		elseif b >= 97 and b <= 102 then
			return b - 97 + 10
		elseif b >= 65 and b <= 70 then
			return b - 65 + 10
		else
			return -1
		end
	end
	local function hex(base)
		local res = 0
		local any = false

		while true do
			local c = chars()
			if c == nil then break end

			local digit = hex_one(c)
			if digit == -1 then
				unconsume(c)
				break
			else
				res = res * 16 + digit
			end

			any = true
		end

		if not any then return end

		return tok_num(base, res)
	end
	local function decimal(res, float, mult)
		local any = true
		local fract_mult = .1

		if type(res) == "string" then
			local b = to_byte(res)

			if b >= 48 and b <= 57 then
				res = b - 48
			else
				return nil
			end
		elseif res == nil then
			res, any = 0, false
		end

		if mult == nil then mult = 1 end

		local c

		while true do
			c = chars()
			if c == nil then break end

			local b = to_byte(c)
			if b >= 48 and b <= 57 then
				any = true
				if float then
					res = res + (b - 48) * fract_mult
					fract_mult = fract_mult * .1
				else
					res = res * 10 + (b - 48)
				end
			else
				break
			end
		end

		if any then
			return mult * res, c
		else
			return nil, c
		end
	end
	local function number(base, res)
		local fract, e
		local whole, next = decimal(res, false)

		if next == "." then
			fract, next = decimal(nil, true)
		end
		if next == "e" then
			local c = chars()
			if c == "-" then
				e, next = decimal(nil, false, -1)
			else
				e, next = decimal(c)
			end

			if e == nil then
				return nil, "Expected number after 'e'"
			end
		end

		if fract == nil then fract = 0 end
		if e == nil then
			e = 1
		else
			e = 10 ^ e
		end

		unconsume(next)
		return tok_num(base, (whole + fract) * e)
	end
	local function zero(base)
		local c = chars()
		if c == nil then return tok_num(base, 0) end

		local b = to_byte(c)

		if c == "x" then
			local res = hex(base)
			if res == nil then return nil, "Expected a hex literal"
			else return res end
		else
			unconsume(c)
			return number(base, 0)
		end
	end
	local function id(base, c)
		local res = c

		while true do
			c = chars()
			if c == nil then break end

			local b = to_byte(c)
			if
				b >= 65 and b <= 90 or -- A-Z
				b >= 97 and b <= 122 or -- a-z
				b >= 48 and b <= 57 or -- 0-9
				c == "_"
			then
				res = res .. c
			else
				unconsume(c)
				break
			end
		end

		base.raw = res

		return tok_id(base, res)
	end
	local function dot(base)
		local e, fract, next = nil, decimal(nil, true)

		if fract == nil then
			if next == "." then
				local c = chars()

				if c == "." then
					return tok_op(base, operators.SPREAD)
				else
					unconsume(c)
					return tok_op(base, operators.CONCAT)
				end
			else
				unconsume(next)
				return tok_op(base, operators.DOT)
			end

			return base
		end

		if next == "e" then
			local c = chars()
			if c == "-" then
				e, next = decimal(nil, false, -1)
			else
				e, next = decimal(c)
			end

			if e == nil then
				return nil, "Expected number after 'e'"
			end
		end

		if fract == nil then fract = 0 end
		if e == nil then
			e = 1
		else
			e = 10 ^ e
		end

		unconsume(next)
		return tok_num(base, fract * e)
	end
	local function char(c, allow_newline)
		if c == nil then return nil
		elseif c == "\\" then
			c = chars()
			if c == "a" then return "\a"
			elseif c == "b" then return "\b"
			elseif c == "f" then return "\f"
			elseif c == "n" then return "\n"
			elseif c == "r" then return "\r"
			elseif c == "t" then return "\t"
			elseif c == "v" then return "\v"
			elseif c == "z" then
				repeat
					c = chars()
				until c == " " or c == "\n" or c == "\r" or c == "\t" or c == "\v"
				return char(c)
			elseif c == "x" then
				local ca, cb = chars(), chars()
				if ca == nil or cb == nil then return nil, "Expected a hex number" end

				local a, b = hex_one(ca), hex_one(cb)
				if a == -1 or b == -1 then return nil, "Expected a hex number" end

				return string.char(a * 16 + b)
			else return c end
		else return c end
	end
	local function quote_str(base, first)
		local res = {};

		while true do
			local c, err;

			c = chars()
			if c == first then break end
			if c == nil then return nil, "Unterminated string literal" end

			c, err = char(c)
			if c == nil then
				return nil, err or "Unterminated string literal";
			else
				res[#res + 1] = c;
			end
		end

		return tok_str(base, table.concat(res));
	end
	local function quote_char(base, first)
		local res = 0;

		while true do
			local c, err;

			c = chars();
			if c == first then break end
			if c == nil then return nil, "Unterminated string literal" end

			c, err = char(c);
			if c == nil then
				return nil, err or "Unterminated string literal";
			else
				for _, v in ipairs { string.byte(c, 1, #c) } do
					res = res * 256 + v;
				end
			end
		end

		return tok_num(base, res);
	end

	return function ()
		-- local comments = consume_white()
		local comments, err = consume_white();
		if comments == nil then
			error(table.concat({ filename, line, start }, ":") .. ": " .. err);
		elseif comments == false then
			comments = nil;
		end

		local loc = table.concat({ filename, line, start }, ":");
		--- @type table | nil
		local base = { loc = loc, comments = comments, raw = "" };

		local c = chars()
		if c == nil then return nil end
		local b = to_byte(c)

		if c == "." then base, err = dot(base)
		elseif c == "0" then base, err = zero(base)
		elseif b >= 49 and b <= 57 then base, err = number(base, b - 48) -- 1-9
		elseif
			b >= 65 and b <= 90 or -- A-Z
			b >= 97 and b <= 122 or -- a-z
			c == "_"
		then
			base, err = id(base, c)
		elseif c == "\"" then
			base, err = quote_str(base, c);
		elseif c == "\'" then
			base, err = quote_char(base, c);
		else
			local res = op_map;

			while true do
				local next = res[c];
				if next == nil then
					unconsume(c);
					res = res[1];
					break;
				else
					c = chars();
					res = next;
				end
			end

			if res == nil then
				base, err = nil, string.format("Unexpected char '%s'", c)
			else
				base.type = TOK_OP;
				base.val = res;
			end
		end

		if base == nil then
			return error(loc .. ": " .. err);
		else
			base.end_loc = table.concat({ filename, line, start }, ":");
			return base;
		end
	end
end

---@param ... fun(): token?, string?
local function concat_tokens(...)
	local arr = {...};
	local i = 1;

	return function ()
		while true do
			local el = arr[i];

			if el == nil then
				return nil;
			elseif type(el) == "function" then
				local buff = el();
				if buff ~= "" then
					return buff;
				else
					i = i + 1;
				end
			end
		end
	end
end

---@param first token
---@param second token
local function can_go_after(first, second)
	if first.type == TOK_OP and second.type == TOK_OP then
		if (
			first.val == operators.ASSIGN or
			first.val == operators.EQ or
			first.val == operators.LESS or
			first.val == operators.GR or
			first.val == operators.B_XOR
		) and (
			second.val == operators.ASSIGN or
			second.val == operators.EQ
		) then return false end
		if (
			first.val == operators.LESS or
			first.val == operators.GR
		) and (
			second.val == operators.LESS or
			second.val == operators.GR
		) then return false end
		if (
			first.val == operators.DOT or
			first.val == operators.CONCAT or
			first.val == operators.SPREAD
		) and
		(
			second.val == operators.DOT or
			second.val == operators.CONCAT or
			second.val == operators.SPREAD
		) then return false end
		if (
			first.val == operators.LABEL or
			first.val == operators.COLON
		) and (
			second.val == operators.LABEL or
			second.val == operators.COLON
		) then return false end
		if (
			first.val == operators.DIV or
			first.val == operators.IDIV
		) and (
			second.val == operators.DIV or
			second.val == operators.IDIV
		) then return false end

		return true;
	elseif first.type == TOK_NUM and second.type == TOK_ID then
		return false
	elseif first.type == TOK_ID and second.type == TOK_NUM then
		return false
	elseif first.type == TOK_ID and second.type == TOK_ID then
		return false
	elseif first.type == TOK_NUM and second.type == TOK_OP then
		return (
			second.val ~= operators.DOT and
			second.val ~= operators.CONCAT and
			second.val ~= operators.SPREAD
		);
	elseif first.type == TOK_OP and second.type == TOK_NUM then
		return (
			first.val ~= operators.DOT and
			first.val ~= operators.CONCAT and
			first.val ~= operators.SPREAD
		);
	elseif first.type == TOK_ID and second.type == TOK_ID then
		return true;
	elseif first.type == TOK_NUM and second.type == TOK_NUM then
		return false;
	elseif first.type == TOK_STR and second.type == TOK_STR then
		return false;
	else
		return true;
	end
end

---@param tokens fun(): token?, string?
---@return fun(): string?, string?
local function token_stringifier(tokens)
	local last_tok

	return function ()
		if tokens == nil then return nil end

		local tok, err = tokens()
		if tok == nil then
			--- @diagnostic disable-next-line: cast-local-type
			tokens = nil
			return nil, err
		end

		if last_tok ~= nil and not can_go_after(last_tok, tok) then
			last_tok = tok
			return " " .. tok.raw
		else
			last_tok = tok
			return tok.raw
		end
	end
end

return {
	TOK_ID = TOK_ID,
	TOK_OP = TOK_OP,
	TOK_STR = TOK_STR,
	TOK_NUM = TOK_NUM,

	operators = operators,

	char_supplier = char_supplier,
	token_supplier = token_supplier,
	concat_tokens = concat_tokens,
	token_stringifier = token_stringifier,

	tok_id = tok_id,
	tok_op = tok_op,
	tok_num = tok_num,
	tok_str = tok_str,
}

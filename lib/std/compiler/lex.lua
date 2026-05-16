local buffer = require "string.buffer";
local ffi = require "ffi";
local libc = require "nat.libc";
local lexer = {};

lexer.operators = {
	AND = 1,
	OR = 2,
	NOT = 3,

	CONCAT = 10,
	LENGTH = 11,

	ADD = 20,
	SUB = 21,
	MUL = 22,
	DIV = 23,
	IDIV = 24,
	MOD = 25,
	POW = 26,

	B_AND = 30,
	B_OR = 31,
	B_XOR = 32,
	B_SHL = 34,
	B_SHR = 35,

	EQ = 40,
	NEQ = 41,
	LEQ = 42,
	GREQ = 43,
	LE = 44,
	GR = 45,

	PAREN_OPEN = 50,
	PAREN_CLOSE = 51,
	BRACKET_OPEN = 52,
	BRACKET_CLOSE = 53,
	BRACE_OPEN = 54,
	BRACE_CLOSE = 55,

	SEMICOLON = 60,
	COLON = 61,
	LABEL = 63,
	COMMA = 64,
	DOT = 65,
	SPREAD = 66,

	ASSIGN = 70,
	ASSIGN_ADD = 71,
	ASSIGN_SUB = 72,
	ASSIGN_MUL = 73,
	ASSIGN_DIV = 74,
	ASSIGN_IDIV = 75,
	ASSIGN_MOD = 76,

	ASSIGN_BAND = 80,
	ASSIGN_BOR = 81,
	ASSIGN_BXOR = 82,
	ASSIGN_SHL = 83,
	ASSIGN_SHR = 83,

	END = 99,

	WHILE = 100,
	DO = 101,
	FOR = 102,
	IN = 103,
	REPEAT = 104,
	UNTIL = 105,
	IF = 106,
	ELSEIF = 107,
	ELSE = 108,
	THEN = 109,

	BREAK = 110,
	CONTINUE = 111,
	GOTO = 112,
	RETURN = 113,
	LOCAL = 114,
	FUNCTION = 115,
	BEGIN = 116,

	TRUE = 120,
	FALSE = 121,
	NIL = 122,
};

lexer.kw_map = {
	["and"] = lexer.operators.AND,
	["or"] = lexer.operators.OR,
	["not"] = lexer.operators.NOT,

	["end"] = lexer.operators.END,

	["while"] = lexer.operators.WHILE,
	["do"] = lexer.operators.DO,
	["for"] = lexer.operators.FOR,
	["in"] = lexer.operators.IN,
	["repeat"] = lexer.operators.REPEAT,
	["until"] = lexer.operators.UNTIL,
	["if"] = lexer.operators.IF,
	["elseif"] = lexer.operators.ELSEIF,
	["else"] = lexer.operators.ELSE,
	["then"] = lexer.operators.THEN,

	["break"] = lexer.operators.BREAK,
	["continue"] = lexer.operators.CONTINUE,
	["goto"] = lexer.operators.GOTO,
	["return"] = lexer.operators.RETURN,
	["local"] = lexer.operators.LOCAL,
	["function"] = lexer.operators.FUNCTION,
	["begin"] = lexer.operators.BEGIN,

	["true"] = lexer.operators.TRUE,
	["false"] = lexer.operators.FALSE,
	["nil"] = lexer.operators.NIL,
};

local chars = {
	backtick = string.byte "`",
	tilde = string.byte "~",
	bang = string.byte "!",
	at = string.byte "@",
	hash = string.byte "#",
	dollar = string.byte "$",
	percent = string.byte "%",
	caret = string.byte "^",
	amp = string.byte "&",
	star = string.byte "*",
	paren_open = string.byte "(",
	paren_close = string.byte ")",
	dash = string.byte "-",
	underscore = string.byte "_",
	equals = string.byte "=",
	plus = string.byte "+",
	backslash = string.byte "\\",
	pipe = string.byte "|",
	semicolon = string.byte ";",
	colon = string.byte ":",
	quote = string.byte "'",
	dbquote = string.byte "\"",
	comma = string.byte ",",
	dot = string.byte ".",
	lt = string.byte "<",
	gt = string.byte ">",
	slash = string.byte "/",
	question = string.byte "?",
	bracket_open = string.byte "[",
	bracket_close = string.byte "]",
	brace_open = string.byte "{",
	brace_close = string.byte "}",

	newl = string.byte "\n",
	bad_newl = string.byte "\r",
	space = string.byte " ",
	tab = string.byte "\t",

	a = string.byte "a",
	b = string.byte "b",
	e = string.byte "e",
	f = string.byte "f",
	n = string.byte "n",
	r = string.byte "r",
	t = string.byte "t",
	v = string.byte "v",
	x = string.byte "x",
	u = string.byte "u",
	z = string.byte "z",

	A = string.byte "A",
	F = string.byte "F",
	Z = string.byte "Z",
	B = string.byte "B",
	X = string.byte "X",

	zero = string.byte "0",
	one = string.byte "1",
	nine = string.byte "9",
};

local op_map = {
	[chars.plus] = {
		{ "+=", lexer.operators.ASSIGN_ADD },
		{ "+", lexer.operators.ADD },
	},
	[chars.dash] = {
		{ "-=", lexer.operators.ASSIGN_SUB },
		{ "-", lexer.operators.SUB },
	},
	[chars.star] = {
		{ "*=", lexer.operators.ASSIGN_MUL },
		{ "**", lexer.operators.POW },
		{ "*", lexer.operators.MUL },
	},
	[chars.slash] = {
		{ "//=", lexer.operators.ASSIGN_IDIV },
		{ "//", lexer.operators.IDIV },

		{ "/=", lexer.operators.ASSIGN_DIV },
		{ "/", lexer.operators.DIV },
	},
	[chars.percent] = {
		{ "%=", lexer.operators.ASSIGN_MOD },
		{ "%", lexer.operators.MOD },
	},
	[chars.amp] = {
		{ "&&", lexer.operators.AND },

		{ "&=", lexer.operators.ASSIGN_BAND },
		{ "&", lexer.operators.B_AND },
	},
	[chars.pipe] = {
		{ "||", lexer.operators.OR },

		{ "|=", lexer.operators.ASSIGN_BOR },
		{ "|", lexer.operators.B_OR },
	},

	[chars.caret] = {
		{ "^=", lexer.operators.ASSIGN_BXOR },
		{ "^", lexer.operators.POW },
	},

	[chars.lt] = {
		{ "<<=", lexer.operators.ASSIGN_SHL },
		{ "<<", lexer.operators.B_SHL },

		{ "<=", lexer.operators.LEQ },
		{ "<",  lexer.operators.LE },
	},

	[chars.gt] = {
		{ ">>=", lexer.operators.ASSIGN_SHR },
		{ ">>", lexer.operators.B_SHR },

		{ ">=", lexer.operators.GREQ },
		{ ">",  lexer.operators.GR },
	},

	[chars.equals] = {
		{ "==", lexer.operators.EQ },
		{ "=",  lexer.operators.ASSIGN },
	},

	[chars.tilde] = {
		{ "~=", lexer.operators.NEQ },
		{ "~", lexer.operators.B_XOR },
	},

	[chars.bang] = {
		{ "!=", lexer.operators.NEQ },
		{ "!", lexer.operators.NOT },
	},

	[chars.dot] = {
		{ "...",  lexer.operators.SPREAD },
		{ "..",  lexer.operators.CONCAT },
		{ ".",  lexer.operators.DOT },
	},

	[chars.colon] = {
		{ "::", lexer.operators.LABEL },
		{ ":", lexer.operators.COLON },
	},

	[chars.hash] = lexer.operators.LENGTH,
	[chars.comma] = lexer.operators.COMMA,
	[chars.semicolon] = lexer.operators.SEMICOLON,

	[chars.paren_open] = lexer.operators.PAREN_OPEN,
	[chars.paren_close] = lexer.operators.PAREN_CLOSE,
	[chars.bracket_open] = lexer.operators.BRACKET_OPEN,
	[chars.bracket_close] = lexer.operators.BRACKET_CLOSE,
	[chars.brace_open] = lexer.operators.BRACE_OPEN,
	[chars.brace_close] = lexer.operators.BRACE_CLOSE,
};
local tag = {};

local pprint = require "std.printing".pprint;

--- @param loc node.loc
--- @param msg string
local function lex_error(loc, msg)
	error({ [tag] = true, msg = msg, loc = loc }, 0);
end
local function lex_pcall_fin(ok, ...)
	if ok then return true, ... end
	local err = ...;
	if type(err) == "table" and err[tag] then return false, err end
	error(err, 0);
end
local function lex_pcall(f, ...)
	return lex_pcall_fin(xpcall(f, function (err)
		if type(err) == "string" then
			return debug.traceback(err, 2);
		else
			return err;
		end
	end, ...));
end

--- @class lex.str: lex.tok_base
--- @field type 'str'
--- @field val string

--- @class lex.int: lex.tok_base
--- @field type 'int'
--- @field val integer

--- @class lex.fl: lex.tok_base
--- @field type 'fl'
--- @field val number

--- @class lex.op: lex.tok_base
--- @field type 'op'
--- @field val integer

--- @class lex.id: lex.tok_base
--- @field type 'id'
--- @field val string

--- @alias lex.tok lex.str | lex.int | lex.fl | lex.op | lex.id

--- @class lex.tok_base
--- @field loc node.loc
local token_meta = {};
token_meta.__index = token_meta;

--- @param self lex.tok
--- @param val? integer
function token_meta:is_op(val)
	if self.type ~= "op" then return false end
	if val and self.val ~= val then return false end

	return true;
end
--- @param self lex.tok
function token_meta:is_assign_op()
	if self.type ~= "op" then return false end
	return self.val >= lexer.operators.ASSIGN and self.val <= lexer.operators.ASSIGN_SHR;
end
--- @param self lex.tok
--- @param val? string
function token_meta:is_id(val)
	if self.type ~= "id" then return false end
	if val and self.val ~= val then return false end

	return true;
end
--- @param self lex.tok
--- @param val? string
function token_meta:is_str(val)
	if self.type ~= "str" then return false end
	if val and self.val ~= val then return false end

	return true;
end

--- @class lex.ctx
--- @field lines integer[]
--- @field src ffi.cdata*
--- @field n integer

--- @param ctx lex.ctx
--- @param i integer
local function find_loc(ctx, i)
	return {
		lines = ctx.lines,
		i = i + 1,
		get = function (self)
			local low = 1;
			local high = #self.lines;
			local row = 1;

			while low <= high do
				local mid = math.floor((low + high) / 2)
				if self.lines[mid] < self.i then
					row = mid;
					low = mid + 1;
				else
					high = mid - 1;
				end
			end

			local col = self.i - self.lines[row];
			self.row = row;
			self.col = col;
			self.get = nil;
		end
	};
end

--- @param ctx lex.ctx
--- @param i integer
--- @return integer, ffi.cdata*?, integer?
local function read_longlit(ctx, i)
	local j = i;

	if ctx.src[j] ~= chars.bracket_open then return j end
	j = j + 1;

	local eq = ctx.src + j;
	local eq_n = 0;

	while ctx.src[j] == chars.equals do
		j = j + 1;
		eq_n = eq_n + 1;
	end

	if ctx.src[j] ~= chars.bracket_open then return j end
	j = j + 1;

	local first = ctx.src + j;

	while true do
		local find_i = libc.strchr(ctx.src + j, chars.bracket_close);
		if not find_i then lex_error(find_loc(ctx, ctx.n), "expected ']]'") end

		j = j + find_i;
		local n = ctx.src + j - first;
		j = j + 1;

		if libc.strncmp(ctx.src + j, eq, eq_n) == 0 then
			j = j + eq_n;

			if ctx.src[j] == chars.bracket_close then
				j = j + 1;
				return j, first, n;
			end
		end
	end
end

--- @param ctx lex.ctx
--- @param i integer
--- @return integer
local function skip_white(ctx, i)
	while true do
		local c = ctx.src[i];

		if
			c == chars.space or
			c == chars.tab or
			c == chars.newl or
			c == chars.bad_newl
		then
			i = i + 1;
		elseif
			c == chars.hash and
			libc.strncmp(ctx.src + i, "--", 2) == 0 or
			i == 0 and libc.strncmp(ctx.src, "#!", 2) == 0
		then
			local find_i = libc.strchr(ctx.src + i + 2, chars.newl);
			if not find_i then return ctx.n end
			i = i + 2 + find_i;
		elseif c == chars.dash then
			if libc.strncmp(ctx.src + i, "--[[", 4) == 0 then
				i = read_longlit(ctx, i + 2);
			elseif libc.strncmp(ctx.src + i, "--", 2) == 0 then
				local find_i = libc.strchr(ctx.src + i + 2, chars.newl);
				if not find_i then return ctx.n end
				i = i + 2 + find_i;
			else
				return i;
			end
		else
			return i;
		end
	end
end

--- @param i integer
local function read_hex(ctx, i)
	local j = i;
	local res = 0;
	local any = false;

	while true do
		local c = ctx.src[j];
		if c >= chars.zero and c <= chars.nine then
			res = res * 16 + c - chars.zero;
			any = true;
		elseif c >= chars.a and c <= chars.f then
			res = res * 16 + c - chars.a + 10;
			any = true;
		elseif c >= chars.A and c <= chars.F then
			res = res * 16 + c - chars.A + 10;
			any = true;
		elseif c ~= chars.underscore then
			break;
		end

		j = j + 1;
	end

	if not any then return i end
	return j, res;
end
--- @param i integer
local function read_dec(ctx, i)
	local j = i;
	local res = 0;
	local any = false;

	while true do
		local c = ctx.src[j];
		if c >= chars.zero and c <= chars.nine then
			res = res * 10 + c - chars.zero;
			any = true;
		elseif c ~= chars.underscore then
			break;
		end

		j = j + 1;
	end

	if not any then return i end
	return j, res;
end
--- @param i integer
local function read_fract(ctx, i)
	local j = i;
	local res = 0.;
	local any = false;

	while true do
		local c = ctx.src[j];
		if c >= chars.zero and c <= chars.nine then
			res = (res + c - chars.zero) / 10;
			any = true;
		elseif c ~= chars.underscore then
			break;
		end

		j = j + 1;
	end

	if not any then return i end
	return j, res;
end
--- @param i integer
local function read_bin(ctx, i)
	local j = i;
	local res = 0;
	local any = false;

	while true do
		local c = ctx.src[j];
		if c == chars.zero or c == chars.one then
			res = res * 2 + c - chars.zero;
			any = true;
		elseif c ~= chars.underscore then
			break;
		end

		j = j + 1;
	end

	if not any then return i end
	return j, res;
end

--- @param i integer
local function read_escape_char(ctx, i, buff)
	if ctx.src[i] == chars.a then
		buff:put "\a";
		return i + 1;
	elseif ctx.src[i] == chars.b then
		buff:put "\b";
		return i + 1;
	elseif ctx.src[i] == chars.f then
		buff:put "\f";
		return i + 1;
	elseif ctx.src[i] == chars.n then
		buff:put "\n";
		return i + 1;
	elseif ctx.src[i] == chars.r then
		buff:put "\r";
		return i + 1;
	elseif ctx.src[i] == chars.t then
		buff:put "\t";
		return i + 1;
	elseif ctx.src[i] == chars.v then
		buff:put "\v";
		return i + 1;
	elseif ctx.src[i] == chars.quote then
		buff:put "\'";
		return i + 1;
	elseif ctx.src[i] == chars.dbquote then
		buff:put "\"";
		return i + 1;
	elseif ctx.src[i] == chars.x then
		local i, val = read_hex(ctx, i + 1);
		if not val then lex_error(find_loc(ctx, i), "invalid \\x escape sequence") end
		buff:put(string.char(val));
		return i;
	elseif ctx.src[i] == chars.u then
		i = i + 1;

		if ctx.src[i] ~= chars.brace_open then lex_error(find_loc(ctx, i), "expected '{'") end

		local i, val = read_hex(ctx, i);
		if not val then lex_error(find_loc(ctx, i), "expected a hex number") end

		if ctx.src[i] ~= chars.brace_open then lex_error(find_loc(ctx, i), "expected '}'") end
		i = i + 1;

		if val < 128 then
			buff:put(string.char(val));
			return i;
		end

		lex_error(find_loc(ctx, i), "unicode escape sequences not supported yet");
		-- return j, utf8.char(tonumber(val, 16));
	elseif ctx.src[i] >= chars.zero and ctx.src[i] <= chars.nine then
		local i, val = read_dec(ctx, i);
		assert(val);

		if val >= 256 then lex_error(find_loc(ctx, i), "decimal escape too large") end
		buff:put(string.char(val));
		return i;
	elseif ctx.src[i] == chars.z then
		while true do
			if
				ctx.src[i] ~= chars.space and
				ctx.src[i] ~= chars.tab and
				ctx.src[i] ~= chars.newl and
				ctx.src[i] ~= chars.bad_newl
			then return i end

			i = i + 1;
		end
	else
		buff:put(string.char(ctx.src[i]));
		return i + 1;
	-- else
	-- 	lex_error(find_loc(ctx, i), "illegal escape sequence in string");
	end
end
--- @param i integer
local function read_string(ctx, i)
	local ll_i, ll, ll_n = read_longlit(ctx, i);
	if ll then return ll_i, ffi.string(ll, ll_n) end

	if
		ctx.src[i] ~= chars.quote and
		ctx.src[i] ~= chars.dbquote
	then
		return i;
	end

	local quote = ctx.src[i];
	if not quote then return i end

	i = i + 1;

	local res = buffer.new();

	while true do
		if ctx.src[i] == quote then
			i = i + 1;
			return i, res:tostring();
		elseif ctx.src[i] == chars.backslash then
			i = read_escape_char(ctx, i + 1, res);
		elseif ctx.src[i] then
			res:put(string.char(ctx.src[i]));
			i = i + 1;
		else
			lex_error(find_loc(ctx, i), "unterminated string literal");
		end
	end
end
--- @param i integer
local function read_number(ctx, i)
	local j = i;

	if ctx.src[j] == chars.zero then
		if ctx.src[j + 1] == chars.x or ctx.src[j + 1] == chars.x then
			j = j + 2;
			local j, hex = read_hex(ctx, j);
			if not hex then lex_error(find_loc(ctx, j), "expected a hex number") end

			return j, "int", hex;
		end

		if ctx.src[j + 1] == chars.b or ctx.src[j + 1] == chars.B then
			j = j + 2;
			local j, hex = read_bin(ctx, j);
			if not hex then lex_error(find_loc(ctx, j), "expected a binary number") end

			return j, "int", hex;
		end
	end


	local whole, fract, e, e_neg;

	j, whole = read_dec(ctx, j);

	if ctx.src[j] == chars.dot then
		j = j + 1;
		j, fract = read_fract(ctx, j);
	end

	if (whole or fract) and ctx.src[j] == chars.e then
		if ctx.src[j] == chars.plus then
			j = j + 1;
		elseif ctx.src[j] == chars.dash then
			e_neg = true;
			j = j + 1;
		end

		j = j + 1;
		j, e = read_dec(ctx, j);
		if not e then lex_error(find_loc(ctx, j), "malformed number") end
	end

	if not whole and not fract then return i end

	local res = (whole or 0) + (fract or 0);
	local exp = 1;
	local a = 10;

	if e then
		while e > 0 do
			if e % 2 == 1 then
				exp = exp * a;
			end
			a = a * 10;
		end
	end

	if e_neg then
		res = res / exp;
	else
		res = res * exp;
	end

	if not fract and not e_neg then
		return j, "int", res;
	else
		return j, "fl", res;
	end
end
--- @param i integer
local function read_id(ctx, i)
	local start = ctx.src + i;
	local n = 0;

	local first = true;
	while true do
		local c = ctx.src[i];
		if not (
			c >= chars.a and c <= chars.z or
			c >= chars.A and c <= chars.Z or
			c == chars.underscore or
			(not first and c >= chars.zero and c <= chars.nine)
		) then break end

		n = n + 1;
		i = i + 1;
		first = false;
	end

	if n == 0 then return i end

	return i, ffi.string(start, n);
end

--- @param i integer
local function read_op(ctx, i)
	local res = op_map[ctx.src[i]];
	if not res then return i end

	if type(res) == "number" then return i + 1, res --[[@as number]] end

	for j = 1, #res do
		if libc.strncmp(ctx.src + i, res[j][1], #res[j][1]) == 0 then
			return i + #res[j][1], res[j][2] --[[@as number]];
		end
	end

	return i;
end

local function mktok(type, loc, val)
	return setmetatable({ type = type, loc = loc, val = val }, token_meta);
end

local function parse_one(ctx, i, strip)
	local val, kind;
	local start_i = i;

	i, val = read_string(ctx, i);
	if val then return i, mktok("str", not strip and find_loc(ctx, start_i) or nil, val) end

	i, kind, val = read_number(ctx, i);
	if val then return i, mktok(kind, not strip and find_loc(ctx, start_i) or nil, val) end

	i, val = read_id(ctx, i);
	if val then
		if lexer.kw_map[val] then
			return i, mktok("op", not strip and find_loc(ctx, start_i) or nil, lexer.kw_map[val]);
		else
			return i, mktok("id", not strip and find_loc(ctx, start_i) or nil, val);
		end
	end

	i, val = read_op(ctx, i);
	if val then return i, mktok("op", not strip and find_loc(ctx, start_i) or nil, val) end

	lex_error(find_loc(ctx, i), "unknown syntax");
end

--- @param src string
--- @param strip? boolean
--- @return lex.tok[]?
--- @return string? err
--- @return node.loc? err_loc
function lexer.parse(src, strip)
	local ok, res = lex_pcall(function ()
		--- @type lex.ctx
		local ctx = { lines = { 0 }, n = #src, src = ffi.cast("const unsigned char*", src) };
		local res = {};
		local i = 0;

		for line_i in src:gmatch "()\n" do
			table.insert(ctx.lines, line_i);
		end

		while true do
			i = skip_white(ctx, i);
			if i >= ctx.n then break end

			local val;
			i, val = parse_one(ctx, i, strip);
			table.insert(res, val);
		end

		return res;
	end);

	if not ok then return nil, res.msg, res.loc end
	return res;
end

return lexer;

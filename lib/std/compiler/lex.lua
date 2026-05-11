local node = require "std.compiler.node";
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

local op_map = {
	["+"] = { lexer.operators.ADD, ["="] = { lexer.operators.ASSIGN_ADD } },
	["-"] = { lexer.operators.SUB, ["="] = { lexer.operators.ASSIGN_SUB } },

	["*"] = { lexer.operators.MUL, ["="] = { lexer.operators.ASSIGN_MUL } },
	["/"] = {
		lexer.operators.DIV,
		["="] = { lexer.operators.ASSIGN_DIV },
		["/"] = { lexer.operators.IDIV },
	},
	["%"] = { lexer.operators.MOD, ["="] = { lexer.operators.ASSIGN_MOD } },

	["&"] = { lexer.operators.B_AND, ["&"] = { lexer.operators.AND }, ["="] = { lexer.operators.ASSIGN_BAND } },
	["|"] = { lexer.operators.B_OR, ["|"] = { lexer.operators.OR }, ["="] = { lexer.operators.ASSIGN_BOR } },

	["^"] = { lexer.operators.POW, ["="] = { lexer.operators.ASSIGN_XOR } },
	["~"] = {
		lexer.operators.B_XOR,
		["="] = { lexer.operators.NEQ },
	},
	["#"] = { lexer.operators.LENGTH },

	[">"] = {
		lexer.operators.GR,
		[">"] = { lexer.operators.B_SHR, ["="] = { lexer.operators.ASSIGN_SHR } },
		["="] = { lexer.operators.GREQ },
	},
	["<"] = {
		lexer.operators.LE,
		["<"] = { lexer.operators.B_SHL, ["="] = { lexer.operators.ASSIGN_SHL } },
		["="] = { lexer.operators.LEQ },
	},

	["="] = {
		lexer.operators.ASSIGN,
		["="] = { lexer.operators.EQ },
	},
	["!"] = {
		lexer.operators.NOT,
		["="] = { lexer.operators.NEQ },
	},

	[","] = { lexer.operators.COMMA },
	["."] = {
		lexer.operators.DOT,
		["."] = {
			lexer.operators.CONCAT,
			["."] = {
				lexer.operators.SPREAD,
			},
		},
	},
	[";"] = { lexer.operators.SEMICOLON },
	[":"] = {
		lexer.operators.COLON,
		[":"] = lexer.operators.LABEL,
	},

	["("] = { lexer.operators.PAREN_OPEN },
	[")"] = { lexer.operators.PAREN_CLOSE },
	["["] = { lexer.operators.BRACKET_OPEN },
	["]"] = { lexer.operators.BRACKET_CLOSE },
	["{"] = { lexer.operators.BRACE_OPEN },
	["}"] = { lexer.operators.BRACE_CLOSE },
};

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
--- @field src string

--- @param ctx lex.ctx
--- @param i integer
local function find_loc(ctx, i)
	local low = 1;
	local high = #ctx.lines;
	local line = 1;

	while low <= high do
		local mid = math.floor((low + high) / 2)
		if ctx.lines[mid] < i then
			line = mid; -- mid is a candidate
			low = mid + 1; -- try to find a larger one
		else
			high = mid - 1; -- need smaller values
		end
	end

	local col = i - ctx.lines[line];
	return node.loc(line, col);
end

--- @param ctx lex.ctx
--- @param i integer
--- @return integer, string?
local function read_longlit(ctx, i)
	local _, res, j = ctx.src:match("^%[(=-)%[(.-)%]%1%]()", i);
	if not _ then return i end
	return j, res;
end

--- @param ctx lex.ctx
--- @param i integer
--- @return integer, string?
local function read_comment(ctx, i)
	local j = ctx.src:match("^%-%-()", i);
	if not j then return i end

	if ctx.src:find("^%[", j) then
		local j, res = read_longlit(ctx, j);
		if res then return j, res end
	end

	local n_i = ctx.src:find("\n", j);
	if not n_i then
		n_i = #ctx.src + 1;
	end

	return n_i, ctx.src:sub(j, n_i - 1);
end

--- @param ctx lex.ctx
--- @param i integer
--- @return integer, string?
local function skip_white(ctx, i)
	if i == 1 then
		local j = ctx.src:match "^#!.-\n()";
		if j then i = j end
	end

	while true do
		local _, n_i = ctx.src:find("^%s+", i);
		if n_i then i = n_i + 1 end

		local c_i, msg = read_comment(ctx, i);
		if msg then i = c_i end

		if not n_i and not msg then return i end
	end
end

--- @param ctx lex.ctx
--- @param i integer
--- @return integer?, string?
local function read_escape_char(ctx, i)
	if ctx.src:match("^a", i) then
		return i + 1, "\a";
	elseif ctx.src:match("^b", i) then
		return i + 1, "\b";
	elseif ctx.src:match("^f", i) then
		return i + 1, "\f";
	elseif ctx.src:match("^n", i) then
		return i + 1, "\n";
	elseif ctx.src:match("^r", i) then
		return i + 1, "\r";
	elseif ctx.src:match("^t", i) then
		return i + 1, "\t";
	elseif ctx.src:match("^v", i) then
		return i + 1, "\v";
	elseif ctx.src:match("^\'", i) then
		return i + 1, "\'";
	elseif ctx.src:match("^\"", i) then
		return i + 1, "\"";
	elseif ctx.src:match("^n", i) then
		return ctx.src:match("^%s*()", i), "";
	elseif ctx.src:match("^x", i) then
		local val, j = ctx.src:match("^x([0-9a-fA-F][0-9a-fA-F])()", i);
		if not val then return nil, "invalid \\x escape sequence" end
		return j, string.char(tonumber(val, 16));
	elseif ctx.src:match("^z", i) then
		local j = ctx.src:match("^z%s*()", i);
		return j, "";
	elseif ctx.src:match("^u", i) then
		local val, j = ctx.src:match("^u{([0-9a-fA-F]+)}()", i);
		if not val then return nil, "invalid \\u escape sequence" end
		return nil, "unicode escape sequences not supported yet", find_loc(ctx, i - 1);
		-- return j, utf8.char(tonumber(val, 16));
	elseif ctx.src:match("^[0-9]", i) then
		local val, j = ctx.src:match("^([0-9][0-9]?[0-9]?)()", i);
		local c = tonumber(val);
		if not c or c >= 256 then return nil, "decimal escape too large" end
		return j, string.char(c);
	elseif ctx.src:match("^.", i) then
		return i + 1, ctx.src:sub(i, i);
	else
		return nil, "illegal escape sequence in string";
	end
end

--- @param ctx lex.ctx
--- @param i integer
--- @return integer?, string?, node.loc?
local function read_string(ctx, i)
	local j, longlit = read_longlit(ctx, i);
	if longlit then return j, longlit end

	local quote = ctx.src:match("^[\'\"]", j);
	if not quote then return i end

	j = j + 1;

	local parts = {};

	while true do
		local part, p_i = ctx.src:match("^([^%" .. quote .. "%\\]+)()", j);
		if part then
			table.insert(parts, part);
			j = p_i;
		end

		if ctx.src:match("^" .. quote, j) then
			j = j + 1;
			return j, table.concat(parts);
		elseif ctx.src:match("^\\", j) then
			local _j, c = read_escape_char(ctx, j + 1);
			if not _j then return nil, c, find_loc(ctx, j) end
			table.insert(parts, c);
			j = _j;
		else
			return nil, "unterminated string literal", find_loc(ctx, j);
		end
	end
end

--- @param ctx lex.ctx
--- @param i integer
--- @return integer?, ("int" | "fl")?, number?
local function read_number(ctx, i)
	local j = i;

	local hex = ctx.src:match("^0[xX]([a-fA-F0-9_]+)", j);
	if hex then
		return j + #hex + 2, "int", tonumber(hex:gsub("_", ""), 16);
	end

	local bin = ctx.src:match("^0[bB]([01_]+)", j);
	if bin then
		return j + #bin + 2, "int", tonumber(bin:gsub("_", ""), 2);
	end

	local val, dot, e_sign, e;
	val = ctx.src:match("^%d[%d_]*", j);
	if val then
		j = j + #val;
		val = val:gsub("_", "");

		dot = ctx.src:match("^%.([%d_]*)", j);
		if dot then
			j = j + #dot + 1;
			if #dot == 0 then dot = nil end
			dot = dot:gsub("_", "");
		end
	else
		dot = ctx.src:match("^%.(%d[%d_]*)", j);
		if not dot then return i end

		j = j + #dot + 1;
		dot = dot:gsub("_", "");
	end

	e_sign, e = ctx.src:match("^[eE]([+-]?)([%d_]+)", j);
	if e then j = j + #e + 1 end

	if dot or e_sign == "-" then
		return j, "fl", tonumber((val or "") .. "." .. (dot or "") .. (e and "e" .. e or ""));
	end

	e = e and tonumber(e:gsub("_", ""), 10) or 0;
	val = tonumber(val, 10);

	local a = 10;
	local exp = 1;

	while e > 0 do
		if e % 1 == 1 then
			exp = exp * a;
		end
		a = a * 10;
	end

	return j, "int", val * exp;
end

--- @param ctx lex.ctx
--- @param i integer
--- @return integer?, string?
local function read_id(ctx, i)
	local id = ctx.src:match("^([a-zA-Z_][a-zA-Z0-9_]*)", i);
	if id then
		return i + #id, id;
	else
		return i;
	end
end

--- @param ctx lex.ctx
--- @param i integer
--- @return integer?, string?
local function read_op(ctx, i)
	local res = op_map;
	local j = i;

	while true do
		local c = ctx.src:sub(j, j);
		if not res[c] then
			if #res == 1 then
				return j, res[1];
			else
				return i;
			end
			break;
		else
			res = res[c];
			j = j + 1;
		end
	end
end

--- @param ctx lex.ctx
--- @param i integer?
function lexer.next_token(ctx, i)
	if not i or i > #ctx.src then return nil end
	i = skip_white(ctx, i);
	if i > #ctx.src then return nil end

	local loc = find_loc(ctx, i);

	local j, res, err_loc = read_string(ctx, i);
	if not j then return nil, res, err_loc end
	if res then return j, loc, "str", res end

	local j, kind, res = read_number(ctx, i);
	if kind then return j, loc, kind, res end

	local j, res = read_id(ctx, i);
	if res then
		if lexer.kw_map[res] then
			return j, loc, "op", lexer.kw_map[res];
		else
			return j, loc, "id", res;
		end
	end

	local j, res = read_op(ctx, i);
	if res then return j, loc, "op", res end

	return nil, "unknown syntax", loc;
end

--- @param src string
function lexer.stream_tokens(src)
	local ctx = { lines = { 0 }, src = src };

	for i in src:gmatch "()\n" do
		table.insert(ctx.lines, i);
	end

	return lexer.next_token, ctx, 1;
end

--- @param src string
--- @param strip? boolean
--- @return lex.tok[]?
--- @return string? err
--- @return node.loc? err_loc
function lexer.parse(src, strip)
	--- @type lex.ctx
	local ctx = { lines = { 0 }, src = src };
	local i, loc, type, val;
	local res = {};

	for i in src:gmatch "()\n" do
		table.insert(ctx.lines, i);
	end

	i = 1;
	while true do
		i, loc, type, val = lexer.next_token(ctx, i);
		if not i and loc then
			return nil, loc --[[@as string]], type --[[@as node.loc]];
		elseif not i then
			break;
		else
			table.insert(res, setmetatable({ type = type, loc = (not strip) and loc or nil, val = val }, token_meta));
		end
	end

	return res;
end

return lexer;

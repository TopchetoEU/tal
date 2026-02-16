local lex = require "tal.compiler.lex";
local node = require "tal.compiler.node";

local OP_AND = lex.operators.AND;
local OP_OR = lex.operators.OR;
local OP_NOT = lex.operators.NOT;
local OP_CONCAT = lex.operators.CONCAT;
local OP_LENGTH = lex.operators.LENGTH;
local OP_ADD = lex.operators.ADD;
local OP_SUB = lex.operators.SUB;
local OP_MUL = lex.operators.MUL;
local OP_DIV = lex.operators.DIV;
local OP_IDIV = lex.operators.IDIV;
local OP_MOD = lex.operators.MOD;
local OP_POW = lex.operators.POW;
local OP_B_AND = lex.operators.B_AND;
local OP_B_OR = lex.operators.B_OR;
local OP_B_XOR = lex.operators.B_XOR;
local OP_B_SHL = lex.operators.B_SHL;
local OP_B_SHR = lex.operators.B_SHR;
local OP_EQ = lex.operators.EQ;
local OP_NEQ = lex.operators.NEQ;
local OP_LEQ = lex.operators.LEQ;
local OP_GREQ = lex.operators.GREQ;
local OP_LE = lex.operators.LE;
local OP_GR = lex.operators.GR;
local OP_PAREN_OPEN = lex.operators.PAREN_OPEN;
local OP_PAREN_CLOSE = lex.operators.PAREN_CLOSE;
local OP_BRACKET_OPEN = lex.operators.BRACKET_OPEN;
local OP_BRACKET_CLOSE = lex.operators.BRACKET_CLOSE;
local OP_BRACE_OPEN = lex.operators.BRACE_OPEN;
local OP_BRACE_CLOSE = lex.operators.BRACE_CLOSE;
local OP_SEMICOLON = lex.operators.SEMICOLON;
local OP_COLON = lex.operators.COLON;
local OP_ARROW = lex.operators.ARROW;
local OP_LABEL = lex.operators.LABEL;
local OP_COMMA = lex.operators.COMMA;
local OP_DOT = lex.operators.DOT;
local OP_SPREAD = lex.operators.SPREAD;
local OP_ASSIGN = lex.operators.ASSIGN;
local OP_END = lex.operators.END;
local OP_WHILE = lex.operators.WHILE;
local OP_DO = lex.operators.DO;
local OP_FOR = lex.operators.FOR;
local OP_IN = lex.operators.IN;
local OP_REPEAT = lex.operators.REPEAT;
local OP_UNTIL = lex.operators.UNTIL;
local OP_IF = lex.operators.IF;
local OP_ELSEIF = lex.operators.ELSEIF;
local OP_ELSE = lex.operators.ELSE;
local OP_THEN = lex.operators.THEN;
local OP_BREAK = lex.operators.BREAK;
local OP_CONTINUE = lex.operators.CONTINUE;
local OP_GOTO = lex.operators.GOTO;
local OP_RETURN = lex.operators.RETURN;
local OP_LOCAL = lex.operators.LOCAL;
local OP_FUNCTION = lex.operators.FUNCTION;
local OP_BEGIN = lex.operators.BEGIN;
local OP_TRUE = lex.operators.TRUE;
local OP_FALSE = lex.operators.FALSE;
local OP_NIL = lex.operators.NIL;

local bin_op_map = {
	[OP_POW] = node.ops.POW,

	[OP_ADD] = node.ops.ADD,
	[OP_SUB] = node.ops.SUB,
	[OP_MUL] = node.ops.MUL,
	[OP_DIV] = node.ops.DIV,
	[OP_MOD] = node.ops.MOD,
	[OP_IDIV] = node.ops.IDIV,

	[OP_CONCAT] = node.ops.CAT,

	[OP_GREQ] = node.ops.GREQ,

	[OP_B_SHL] = node.ops.B_SHL,
	[OP_B_SHR] = node.ops.B_SHR,
	[OP_B_AND] = node.ops.B_AND,
	[OP_B_OR] = node.ops.B_OR,
	[OP_B_XOR] = node.ops.B_XOR,

	[OP_EQ] = node.ops.EQ,
	[OP_NEQ] = node.ops.NEQ,
	[OP_LE] = node.ops.LE,
	[OP_GR] = node.ops.GR,
	[OP_LEQ] = node.ops.LEQ,
	[OP_GREQ] = node.ops.GREQ,

	[OP_AND] = node.ops.AND,
	[OP_OR] = node.ops.OR,
};

local un_op_map = {
	[OP_LENGTH] = node.ops.LEN,
	[OP_SUB] = node.ops.NEG,
	[OP_B_XOR] = node.ops.B_NEG,
	[OP_NOT] = node.ops.NOT,
};

--- @alias syntax.exp
--- | integer

--- @class syntax.local
--- @field type "local"
--- @field name string

local err_marker = {};


--- @param toks lex.tok[]
--- @param i integer
--- @param msg string
--- @return integer, ...
local function syntax_error(toks, i, msg)
	local line;
	if i > #toks then
		line = toks[#toks].loc;
	else
		line = toks[i].loc;
	end

	error({
		line = line,
		msg = msg,
		[err_marker] = true,
	}, 0);
end

local parse_stm, parse_stm_list;
local parse_exp, parse_exp_list;

local function parse_name_list(toks, i)
	local j = i;
	--- @type string[]
	local res = {};

	while true do
		if not toks[j] or not toks[j]:is_id() then
			if #res == 0 then return i end
			return syntax_error(toks, j, "expected identifier");
		end

		table.insert(res, toks[j].val);
		j = j + 1;

		if not toks[j] or not toks[j]:is_op(OP_COMMA) then break end
		j = j + 1;
	end

	return j, res;
end

local function parse_func_body(toks, i, args)
	local j = i;
	args = args or {};
	local var = false;
	local body;

	if not toks[j] or not toks[j]:is_op(OP_PAREN_OPEN) then
		return syntax_error(toks, j, "expected open paren");
	end
	j = j + 1;

	if toks[j] and toks[j]:is_op(OP_PAREN_CLOSE) then
		j = j + 1;
	else
		while true do
			if toks[j] and toks[j]:is_id() then
				table.insert(args, toks[j].val);
				j = j + 1;

				if toks[j] and toks[j]:is_op(OP_PAREN_CLOSE) then
					j = j + 1;
					break;
				elseif toks[j] and toks[j]:is_op(OP_COMMA) then
					j = j + 1;
				else
					return syntax_error(toks, j, "expected paren or comma");
				end
			elseif toks[j] and toks[j]:is_op(OP_SPREAD) then
				var = true;
				j = j + 1;

				if toks[j] and toks[j]:is_op(OP_PAREN_CLOSE) then
					j = j + 1;
					break;
				elseif toks[j] and toks[j]:is_op(OP_COMMA) then
					return syntax_error(toks, j, "comma not allowed after '...'");
				else
					return syntax_error(toks, j, "expected paren or comma");
				end
			end
		end
	end

	j, body = parse_stm_list(toks, j, { OP_END });
	if not body then return syntax_error(toks, j, "expected function body") end

	return j, node.func(toks[i].loc, args, var, body);
end

------------ EXPRESSIONS ------------

local function parse_exp_func(toks, i)
	local j = i;
	local res;

	if not toks[j] or not toks[j]:is_op(OP_FUNCTION) then return i end
	j = j + 1;

	j, res = parse_func_body(toks, j);
	if not res then return syntax_error(toks, j, "expected function body") end

	return j, res;
end
local function parse_exp_table(toks, i)
	local j = i;

	local keys = {};
	local values = {};
	local array = {};

	local key, val;

	if not toks[j] or not toks[j]:is_op(OP_BRACE_OPEN) then return i end
	j = j + 1;

	while true do
		if toks[j] and toks[j]:is_op(OP_BRACE_CLOSE) then
			j = j + 1;
			break;
		end

		if
			toks[j] and toks[j]:is_id() and
			toks[j + 1] and toks[j + 1]:is_op(OP_ASSIGN)
		then
			table.insert(keys, node.str(toks[i].loc, toks[j].val --[[@as string]]));

			j = j + 2;

			j, val = parse_exp(toks, j);
			if not val then return syntax_error(toks, j, "expected expression") end

			table.insert(values, val);
		elseif toks[j] and toks[j]:is_op(OP_BRACKET_OPEN) then
			j = j + 1;

			j, key = parse_exp(toks, j);
			if not key then return syntax_error(toks, j, "expected expression") end

			if not toks[j] or not toks[j]:is_op(OP_BRACKET_CLOSE) then
				return syntax_error(toks, j, "expected ']'");
			end
			j = j + 1;

			if not toks[j] or not toks[j]:is_op(OP_ASSIGN) then
				return syntax_error(toks, j, "expected '='");
			end
			j = j + 1;

			j, val = parse_exp(toks, j);
			if not val then return syntax_error(toks, j, "expected expression") end

			table.insert(values, val);
		else
			j, val = parse_exp(toks, j);
			if not val then return syntax_error(toks, j, "expected expression") end

			table.insert(array, val);
		end

		local any = false;
		local eof = false;

		while true do
			if toks[j] and toks[j]:is_op(OP_BRACE_CLOSE) then
				j = j + 1;
				eof = true;
				break;
			elseif toks[j] and (toks[j]:is_op(OP_COMMA) or toks[j]:is_op(OP_SEMICOLON)) then
				j = j + 1;
				any = true;
			else
				break;
			end
		end

		if eof then
			break;
		elseif not any then
			return syntax_error(toks, j, "expected ',', ';' or '}'");
		end
	end

	return j, node.table(toks[i].loc, keys, values, array);
end

--- @param i integer
local function parse_exp_call_suffix(toks, i, prev)
	local j = i;
	local name;

	if toks[j] and toks[j]:is_op(OP_COLON) then
		j = j + 1;
		if not toks[j] or not toks[j]:is_id() then
			return syntax_error(toks, j, "expected identifier");
		end

		name = toks[j].val --[[@as string]];
		j = j + 1;
	end

	local args = {};

	if toks[j] and toks[j]:is_str() then
		table.insert(args, node.str(toks[i].loc, toks[j].val --[[@as string]]));
		j = j + 1;
	elseif toks[j] and toks[j]:is_op(OP_BRACE_OPEN) then
		local arg;
		j, arg = parse_exp_table(toks, j);
		if not arg then return syntax_error(toks, j, "expected table literal") end

		table.insert(args, arg);
	elseif toks[j] and toks[j]:is_op(OP_PAREN_OPEN) then
		j = j + 1;

		if toks[j] and toks[j]:is_op(OP_PAREN_CLOSE) then
			j = j + 1;
		else
			while true do
				local exp;
				j, exp = parse_exp(toks, j);
				if not exp then syntax_error(toks, j, "expected expression") end

				table.insert(args, exp);

				if toks[j] and toks[j]:is_op(OP_PAREN_CLOSE) then
					j = j + 1;
					break;
				elseif toks[j] and toks[j]:is_op(OP_COMMA) then
					j = j + 1;
				else
					return syntax_error(toks, j, "expected paren or comma");
				end
			end
		end
	else
		if name then
			return syntax_error(toks, j, "expected method call");
		else
			return i;
		end
	end

	if name then
		return j, node.method(toks[i].loc, prev, name, table.unpack(args));
	else
		return j, node.call(toks[i].loc, prev, table.unpack(args));
	end
end
local function parse_exp_index_suffix(toks, i, prev)
	local j = i;

	if toks[j] and toks[j]:is_op(OP_DOT) then
		j = j + 1;

		if not toks[j] or not toks[j]:is_id() then
			return syntax_error(toks, j, "expected identifier");
		end

		local name = toks[j].val --[[@as string]];
		j = j + 1;

		return j, node.index(toks[i].loc, prev, node.str(toks[i].loc, name));
	end

	if toks[j] and toks[j]:is_op(OP_BRACKET_OPEN) then
		j = j + 1;

		local key;
		j, key = parse_exp(toks, j);
		if not key then return syntax_error(toks, j, "expected expression") end

		if not toks[j] or not toks[j]:is_op(OP_BRACKET_CLOSE) then
			return syntax_error(toks, j, "expected ']'");
		end
		j = j + 1;

		return j, node.index(toks[i].loc, prev, key);
	end

	return i;
end
local function parse_exp_prefix(toks, i, no_call)
	local j = i;
	local res;

	if toks[j] and toks[j]:is_id() then
		j = j + 1;
		res = node.var(toks[i].loc, toks[i].val --[[@as string]]);
	elseif toks[j] and toks[i]:is_op(OP_PAREN_OPEN) then
		j, res = parse_exp(toks, j + 1);
		if not res then return syntax_error(toks, j, "expected expression") end

		if not toks[j] or not toks[j]:is_op(OP_PAREN_CLOSE) then
			return syntax_error(toks, j, "expected ')'");
		end

		j = j + 1;

		if res.type ~= "paren" then
			res = node.paren(toks[i].loc, res);
		end
	else
		return i;
	end

	while true do
		local new_call, new_index;

		if not no_call then
			j, new_call = parse_exp_call_suffix(toks, j, res);
			if new_call then res = new_call end
		end

		j, new_index = parse_exp_index_suffix(toks, j, res);
		if new_index then res = new_index end

		if not new_call and not new_index then break end
	end

	return j, res;
end

local function parse_exp_single(toks, i)
	local j = i;

	if toks[j] then
		if toks[j]:is_op(OP_TRUE) then
			return j + 1, node.bool(toks[i].loc, true);
		elseif toks[j]:is_op(OP_FALSE) then
			return j + 1, node.bool(toks[i].loc, false);
		elseif toks[j]:is_op(OP_NIL) then
			return j + 1, node._nil(toks[i].loc);
		elseif toks[j].type == "int" then
			return j + 1, node.int(toks[i].loc, toks[j].val --[[@as integer]]);
		elseif toks[j].type == "fl" then
			return j + 1, node.fl(toks[i].loc, toks[j].val --[[@as number]]);
		elseif toks[j].type == "str" then
			return j + 1, node.str(toks[i].loc, toks[j].val --[[@as string]]);
		elseif toks[j]:is_op(OP_SPREAD) then
			return j + 1, node.args(toks[i].loc);
		elseif toks[j]:is_op(OP_FUNCTION) then
			return parse_exp_func(toks, j);
		elseif toks[j]:is_op(OP_BRACE_OPEN) then
			return parse_exp_table(toks, j);
		else
			return parse_exp_prefix(toks, j);
		end
	end
end
--- @return integer, node.exp?
local function parse_exp_part(toks, i)
	local j = i;
	local prefix_ops = {};
	local res;

	while toks[j] and toks[j]:is_op() do
		local op = un_op_map[toks[j].val];
		if not op then break end

		table.insert(prefix_ops, op);
		j = j + 1;
	end

	if #prefix_ops == 0 then
		return parse_exp_single(toks, j);
	else
		j, res = parse_exp(toks, j, node.ops.POW);
		if not res then return syntax_error(toks, j, "expected expression") end

		for k = #prefix_ops, 1, -1 do
			res = node.op(toks[i].loc, prefix_ops[k], res);
		end

		return j, res;
	end
end

--- @param toks lex.tok[]
--- @param i integer
--- @param a node.exp
--- @param max_op? integer
local function parse_exp_op(toks, i, a, max_op)
	local j = i;

	if not toks[j] or not toks[j]:is_op() then return i end

	local op = bin_op_map[toks[j].val];
	if not op then return i end

	j = j + 1;

	if max_op and op > max_op then return i end
	if op == node.ops.POW or op == node.ops.CAT then
		max_op = op;
	else
		max_op = op - 1;
	end

	local b;
	j, b = parse_exp(toks, j, max_op);
	if not b then return syntax_error(toks, j, "expected expression") end

	return j, node.op(toks[i].loc, op, a, b);
end

--- @param toks lex.tok[]
--- @param i integer
--- @param max_op? integer
--- @return integer
--- @return node.exp?
function parse_exp(toks, i, max_op)
	local j = i;
	local res;

	j, res = parse_exp_part(toks, j);
	if not res then return i end

	while true do
		local new;
		j, new = parse_exp_op(toks, j, res, max_op);
		if not new then break end

		res = new;
	end

	return j, res;
end

--- @param toks lex.tok[]
--- @param i integer
function parse_exp_list(toks, i)
	local j = i;
	--- @type node.exp[]
	local res = {};

	while true do
		local exp;
		j, exp = parse_exp(toks, j);
		if not exp then
			if #res == 0 then return i end
			return syntax_error(toks, j, "expected expression");
		end
		table.insert(res, exp);

		if not toks[j] or not toks[j]:is_op(OP_COMMA) then break end
		j = j + 1;
	end

	return j, res;
end

------------ STATEMENTS ------------

local function parse_if(toks, i)
	local j = i;

	local conds = {};
	local bodies = {};
	local default;
	local start_op = OP_IF;

	if not toks[j] or not toks[j]:is_op(OP_IF) then return i end
	j = j + 1;

	while start_op ~= OP_END do
		if start_op == OP_IF or start_op == OP_ELSEIF then
			local cond, body;

			j, cond = parse_exp(toks, j);
			if not cond then return syntax_error(toks, j, "expected expression") end

			if not toks[j] or not toks[j]:is_op(OP_THEN) then
				return syntax_error(toks, j, "expected 'then'");
			end
			j = j + 1;

			j, body, start_op = parse_stm_list(toks, j, { OP_ELSEIF, OP_ELSE, OP_END });
			if not body then return syntax_error(toks, j, "expected if body") end

			table.insert(conds, cond);
			table.insert(bodies, body);
		elseif start_op == OP_ELSE then
			local body;

			j, body, start_op = parse_stm_list(toks, j, { OP_END });
			if not body then return syntax_error(toks, j, "expected if body") end

			default = body;
			break;
		end
	end

	return j, node._if(toks[i].loc, conds, bodies, default);
end
local function parse_while(toks, i)
	local j = i;

	local cond, body;

	if not toks[j] or not toks[j]:is_op(OP_WHILE) then return i end
	j = j + 1;

	j, cond = parse_exp(toks, j);
	if not cond then return syntax_error(toks, j, "expected expression") end

	if not toks[j] or not toks[j]:is_op(OP_DO) then
		return syntax_error(toks, j, "expected 'do'")
	end
	j = j + 1;

	j, body = parse_stm_list(toks, j, { OP_END });
	if not body then return syntax_error(toks, j, "expected while body") end

	return j, node._while(toks[i].loc, cond, body);
end
local function parse_repeat(toks, i)
	local j = i;

	local cond, body;

	if not toks[j] or not toks[j]:is_op(OP_REPEAT) then return i end
	j = j + 1;

	j, body = parse_stm_list(toks, j, { OP_UNTIL });
	if not body then return syntax_error(toks, j, "expected repeat body") end

	j, cond = parse_exp(toks, j);
	if not cond then return syntax_error(toks, j, "expected expression") end

	return j, node._repeat(toks[i].loc, cond, body);
end
local function parse_for(toks, i)
	local j = i;

	local name, init, last, step, body;

	if not toks[j] or not toks[j]:is_op(OP_FOR) then return i end
	j = j + 1;

	if not toks[j] or not toks[j]:is_id() then
		return syntax_error(toks, j, "expected for loop name");
	end
	name = toks[j].val --[[@as string]];
	j = j + 1;

	if not toks[j] or not toks[j]:is_op(OP_ASSIGN) then
		return syntax_error(toks, j, "expected for loop name");
	end
	j = j + 1;

	j, init = parse_exp(toks, j);
	if not init then return syntax_error(toks, j, "expected init expression") end

	if not toks[j] or not toks[j]:is_op(OP_COMMA) then
		return syntax_error(toks, j, "expected ','");
	end
	j = j + 1;

	j, last = parse_exp(toks, j);
	if not last then return syntax_error(toks, j, "expected last expression") end

	if toks[j] and toks[j]:is_op(OP_COMMA) then
		j = j + 1;

		j, step = parse_exp(toks, j);
		if not step then return syntax_error(toks, j, "expected step expression") end
	end

	if not toks[j] or not toks[j]:is_op(OP_DO) then
		return syntax_error(toks, j, step and "expected 'do'" or "expected ',' or 'do'");
	end
	j = j + 1;

	j, body = parse_stm_list(toks, j, { OP_END });

	return j, node._for(toks[i].loc, name, init, last, step, body);
end
local function parse_for_in(toks, i)
	local j = i;

	local names, values, last, step, body;

	if not toks[j] or not toks[j]:is_op(OP_FOR) then return i end
	j = j + 1;

	j, names = parse_name_list(toks, j);
	if not names then return syntax_error(toks, j, "expected identifier list") end

	if not toks[j] or not toks[j]:is_op(OP_IN) then
		if #names > 1 then
			return syntax_error(toks, j, "expected 'in'");
		else
			return i;
		end
	end
	j = j + 1;

	j, values = parse_exp_list(toks, j);
	if not values then return syntax_error(toks, j, "expected value list") end

	if not toks[j] or not toks[j]:is_op(OP_DO) then
		return syntax_error(toks, j, "expected 'do'");
	end
	j = j + 1;

	j, body = parse_stm_list(toks, j, { OP_END });

	return j, node.for_in(toks[i].loc, names, values, body);
end
local function parse_scope(toks, i)
	local j = i;

	local cond, body;

	if not toks[j] or not toks[j]:is_op(OP_DO) then return i end
	j = j + 1;

	j, body = parse_stm_list(toks, j, { OP_END });
	if not body then return syntax_error(toks, j, "expected do body") end

	return j, node.scope(toks[i].loc, body);
end
local function parse_return(toks, i)
	local j = i;

	local vals;

	if not toks[j] or not toks[j]:is_op(OP_RETURN) then return i end
	j = j + 1;

	j, vals = parse_exp_list(toks, j);
	vals = vals or {};

	return j, node._return(toks[i].loc, table.unpack(vals));
end
local function parse_break(toks, i)
	local j = i;

	if not toks[j] or not toks[j]:is_op(OP_BREAK) then return i end
	j = j + 1;

	return j, node._break(toks[i].loc);
end

local function parse_assign(toks, i)
	local j = i;
	--- @type node.assign_target[]
	local targets = {};
	local values;

	local err_i = nil;

	while true do
		local exp;
		local exp_i = j;
		j, exp = parse_exp(toks, j);
		if not exp then
			if #targets == 0 then return i end
			if #targets > 1 then
				return syntax_error(toks, j, "expected assign target");
			else
				return i;
			end
		elseif not err_i and (exp.type ~= "index" and exp.type ~= "var") then
			err_i = exp_i;
		end


		table.insert(targets, exp);

		if toks[j] then
			if toks[j]:is_op(OP_COMMA) then
				j = j + 1;
			elseif toks[j]:is_op(OP_ASSIGN) then
				j = j + 1;
				break;
			elseif #targets == 1 then
				return j, targets[1];
			else
				return syntax_error(toks, j, "expected ',' or '='");
			end
		end
	end

	if err_i then return syntax_error(toks, err_i, "assign target must be an index or a var") end

	j, values = parse_exp_list(toks, j);
	if not values then return syntax_error(toks, j, "expected value list") end

	return j, node.assign(toks[i].loc, targets, values);
end

local function parse_local(toks, i)
	local j = i;
	local names, values;

	if not toks[j] or not toks[j]:is_op(OP_LOCAL) then return i end
	j = j + 1;

	j, names = parse_name_list(toks, j);
	if not names then
		return syntax_error(toks, j, "expected name list");
	end

	if toks[j] and toks[j]:is_op(OP_ASSIGN) then
		j = j + 1;

		j, values = parse_exp_list(toks, j);
		if not values then
			return syntax_error(toks, j, "expected exp list");
		end
	end

	return j, node.decl(toks[i].loc, false, names, values);
end
local function parse_local_func(toks, i)
	local j = i;
	local name, func;

	if not toks[j] or not toks[j]:is_op(OP_LOCAL) then return i end
	j = j + 1;

	if not toks[j] or not toks[j]:is_op(OP_FUNCTION) then return i end
	j = j + 1;

	if not toks[j] or not toks[j]:is_id() then return i end
	name = toks[j].val;
	j = j + 1;

	j, func = parse_func_body(toks, j);
	if not func then return syntax_error(toks, j, "expected function body") end

	return j, node.decl(toks[i].loc, true, { name }, { func });
end
local function parse_assign_func(toks, i)
	local j = i;
	local target, func;

	if not toks[j] or not toks[j]:is_op(OP_FUNCTION) then return i end
	j = j + 1;

	j, target = parse_exp_prefix(toks, j, true);
	if not target then return syntax_error(toks, j, "expected function assign target") end

	local args;
	if toks[j] and toks[j]:is_op(OP_COLON) then
		local index_loc = toks[j].loc;
		j = j + 1;

		local name_loc = toks[j].loc;
		if not toks[j] or not toks[j]:is_id() then
			return syntax_error(toks, j, "expected identifier");
		end
		j = j + 1;

		args = { "self" };
		target = node.index(index_loc, target, node.str(name_loc, toks[j - 1].val --[[@as string]]));
	end

	--- @cast target node.assign_target
	j, func = parse_func_body(toks, j, args);
	if not func then return syntax_error(toks, j, "expected function body") end

	return j, node.assign(toks[i].loc, { target }, { func });
end

--- @param toks lex.tok[]
--- @param i integer
function parse_stm(toks, i)
	local j = i;
	local res;

	j, res = parse_if(toks, i);
	if res then return j, res end

	j, res = parse_while(toks, i);
	if res then return j, res end

	j, res = parse_repeat(toks, i);
	if res then return j, res end

	j, res = parse_for_in(toks, i);
	if res then return j, res end

	j, res = parse_for(toks, i);
	if res then return j, res end

	j, res = parse_scope(toks, i);
	if res then return j, res end

	j, res = parse_return(toks, i);
	if res then return j, res end

	j, res = parse_break(toks, i);
	if res then return j, res end

	j, res = parse_local_func(toks, i);
	if res then return j, res end

	j, res = parse_local(toks, i);
	if res then return j, res end

	j, res = parse_assign_func(toks, i);
	if res then return j, res end

	j, res = parse_assign(toks, i);
	if res then return j, res end

	j, res = parse_exp_prefix(toks, i);
	if res and res.type == "call" then return j, res end

	return i;
end


--- @param toks lex.tok[]
--- @param i integer
--- @param eof? integer[]
--- @return integer
--- @return node.stm[]
--- @return integer
function parse_stm_list(toks, i, eof)
	local j = i;
	local res = {};

	while true do
		while toks[j] and toks[j]:is_op(OP_SEMICOLON) do
			j = j + 1;
		end

		if j > #toks then
			if eof then return syntax_error(toks, j, "expected statement or <EOF>") end
			return j, res, OP_END;
		end

		if eof then
			for k = 1, #eof do
				if toks[j]:is_op(eof[k]) then
					return j + 1, res, toks[j].val --[[@as integer]];
				end
			end
		end

		if #res > 0 and res[#res].type == "return" then
			return syntax_error(toks, j, "expected <EOF> after return");
		end

		local stm;
		j, stm = parse_stm(toks, j);
		if not stm then
			return syntax_error(toks, j, "bad syntax");
		end

		table.insert(res, stm);
	end
end

--- @param src lex.tok[] | string
--- @param strip? boolean
--- @return node.stm[]?
--- @return string? msg
--- @return node.loc? msg_loc
local function parse_stm_wrap(src, strip)
	if type(src) == "string" then
		local toks, err, loc = lex.parse(src, strip);
		if not toks then return nil, err, loc end
		src = toks;
	end

	local ok, i, res = pcall(parse_stm_list, src, 1, nil);
	if not ok then
		if type(i) == "table" and i[err_marker] then
			return nil, i.msg, i.line;
		else
			error(i, 0);
		end
	end

	return res;
end
--- @param src lex.tok[] | string
--- @param strip? boolean
--- @return node.stm[]?
--- @return string? msg
--- @return node.loc? msg_loc
local function parse_exp_wrap(src, strip)
	if type(src) == "string" then
		local toks, err, loc = lex.parse(src, strip);
		if not toks then return nil, err, loc end
		src = toks;
	end

	local ok, i, res = pcall(parse_exp, src, 1, nil);
	if not ok then
		if type(i) == "table" and i[err_marker] then
			return nil, i.msg, i.line;
		else
			error(i, 0);
		end
	end

	if i <= #src then
		return nil, "unexpected syntax", src[i].loc;
	end

	return res;
end

return {
	parse_exp = parse_exp_wrap,
	parse = parse_stm_wrap,
}

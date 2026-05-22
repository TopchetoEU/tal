local lex = require "std.compiler.lex";
local node = require "std.compiler.node";

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
local OP_ASSIGN_ADD = lex.operators.ASSIGN_ADD;
local OP_ASSIGN_SUB = lex.operators.ASSIGN_SUB;
local OP_ASSIGN_MUL = lex.operators.ASSIGN_MUL;
local OP_ASSIGN_DIV = lex.operators.ASSIGN_DIV;
local OP_ASSIGN_IDIV = lex.operators.ASSIGN_IDIV;
local OP_ASSIGN_MOD = lex.operators.ASSIGN_MOD;
local OP_ASSIGN_BAND = lex.operators.ASSIGN_BAND;
local OP_ASSIGN_BOR = lex.operators.ASSIGN_BOR;
local OP_ASSIGN_BXOR = lex.operators.ASSIGN_BXOR;
local OP_ASSIGN_SHL = lex.operators.ASSIGN_SHL;
local OP_ASSIGN_SHR = lex.operators.ASSIGN_SHR;
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

--- @class syntax.scope
--- @field gotos table<node.goto, string>
--- @field labels table<string, node.label>
--- @field vars table<string, node.name>
--- @field parent? syntax.scope

--- @class syntax.ctx
--- @field toks lex.tok[]
--- @field errs { msg: string, loc: node.loc }[]
--- @field scope? syntax.scope
--- @field glob syntax.scope

--- @param ctx syntax.ctx
--- @param i integer
--- @param msg string
local function syntax_error(ctx, i, msg)
	local loc;
	if i > #ctx.toks then
		loc = ctx.toks[#ctx.toks].loc;
		msg = "unexpected eof: " .. msg;
	else
		loc = ctx.toks[i].loc;
	end

	table.insert(ctx.errs, { msg = msg, loc = loc });
end

local function syntax_loc(ctx, i)
	if i > #ctx.toks then
		return ctx.toks[#ctx.toks].loc;
	else
		return ctx.toks[i].loc;
	end
end

local parse_stm, parse_stm_list;
local parse_exp, parse_exp_list;

--- @param ctx syntax.ctx
local function scope_begin(ctx)
	ctx.scope = {
		parent = ctx.scope,
		gotos = ctx.scope.gotos,
		labels = ctx.scope.labels,
		vars = ctx.scope.vars,
	};
end
--- @param ctx syntax.ctx
local function scope_end(ctx)
	local res = ctx.scope;
	ctx.scope = ctx.scope.parent;
	return res;
end
--- @param ctx syntax.ctx
--- @param name string
local function scope_declare(ctx, loc, name)
	local res = node.name(loc, name, false);
	ctx.scope.vars[name] = res;
	return res;
end
--- @param ctx syntax.ctx
--- @param name string
local function scope_lookup(ctx, name)
	if ctx.scope.vars[name] then
		return ctx.scope.vars[name];
	end
	if not ctx.glob.vars[name] then
		local var = node.name(nil, name, true);
		ctx.glob.vars[name] = var;
		return var;
	end

	return ctx.glob.vars[name];
end

local function parse_name_list(ctx, i)
	local j = i;
	--- @type node.name[]
	local res = {};

	while true do
		if not ctx.toks[j] or not ctx.toks[j]:is_id() then
			if #res == 0 then return i end
			syntax_error(ctx, j, "expected identifier");
			break;
		end

		local name = ctx.toks[j].val --[[@as string]];
		table.insert(res, scope_declare(ctx, syntax_loc(ctx, j), name));
		j = j + 1;

		if not ctx.toks[j] or not ctx.toks[j]:is_op(OP_COMMA) then break end
		j = j + 1;
	end

	return j, res;
end

--- @param ctx syntax.ctx
local function finish_labels(ctx)
	for gt, gt_name in pairs(ctx.scope.gotos) do
		local target = ctx.scope.labels[gt_name];
		if target then
			gt.target = target;
		else
			table.insert(ctx.errs, { msg = "no visible label '" .. gt_name .. "'", loc = gt.loc });
		end
	end
end

--- @param init_args? string[]
local function parse_func_body(ctx, i, def_start, init_args, no_args)
	local j = i;
	local args = {};
	local first = false;
	local var = false;
	local body;

	scope_begin(ctx);
	ctx.scope.gotos = {};
	ctx.scope.labels = {};

	if init_args then
		for i = 1, #init_args do
			table.insert(args, scope_declare(ctx, syntax_loc(ctx, j), init_args[i]));
		end
	end

	if not no_args then
		if not ctx.toks[j] or not ctx.toks[j]:is_op(OP_PAREN_OPEN) then
			syntax_error(ctx, j, "expected open paren");
		else
			j = j + 1;
		end

		if ctx.toks[j] and ctx.toks[j]:is_op(OP_PAREN_CLOSE) then
			j = j + 1;
		else
			while true do
				if ctx.toks[j] and ctx.toks[j]:is_id() then
					table.insert(args, scope_declare(ctx, syntax_loc(ctx, j), ctx.toks[j].val --[[@as string]]));
					first = true;
					j = j + 1;

					if ctx.toks[j] and ctx.toks[j]:is_op(OP_PAREN_CLOSE) then
						j = j + 1;
						break;
					elseif ctx.toks[j] and ctx.toks[j]:is_op(OP_COMMA) then
						j = j + 1;
					else
						syntax_error(ctx, j, "expected ',' or ')'");
					end
				elseif ctx.toks[j] and ctx.toks[j]:is_op(OP_SPREAD) then
					var = true;
					first = true;
					j = j + 1;

					if ctx.toks[j] and ctx.toks[j]:is_op(OP_PAREN_CLOSE) then
						j = j + 1;
						break;
					elseif ctx.toks[j] and ctx.toks[j]:is_op(OP_COMMA) then
						j = j + 1;
						syntax_error(ctx, j, "no arguments allowed after '...'");
					else
						syntax_error(ctx, j, "expected ',' or ')'");
					end
				elseif first then
					syntax_error(ctx, j, "expected identifier, '...' or ')'");
					break;
				else
					syntax_error(ctx, j, "expected identifier or '...'");
					break;
				end
			end
		end
	else
		var = true;
	end

	j, body = parse_stm_list(ctx, j, "'end'", { OP_END });

	finish_labels(ctx);
	scope_end(ctx);

	return j, node.func(def_start, syntax_loc(ctx, j - 1), args, var, body);
end

------------ EXPRESSIONS ------------

local function parse_exp_func(ctx, i)
	local j = i;
	local res;

	if ctx.toks[j] and ctx.toks[j]:is_op(OP_FUNCTION) then
		j = j + 1;
		j, res = parse_func_body(ctx, j, syntax_loc(ctx, j));
		if not res then syntax_error(ctx, j, "expected function body") end
		return j, res;
	end

	if ctx.toks[j] and ctx.toks[j]:is_op(OP_BEGIN) then
		j = j + 1;
		j, res = parse_func_body(ctx, j, syntax_loc(ctx, j), nil, true);
		if not res then syntax_error(ctx, j, "expected statement list") end
		return j, res;
	end

	return i;
end
local function parse_exp_table(ctx, i)
	local j = i;

	local keys = {};
	local values = {};
	local array = {};

	local key, val;

	if not ctx.toks[j] or not ctx.toks[j]:is_op(OP_BRACE_OPEN) then return i end
	j = j + 1;

	while true do
		if ctx.toks[j] and ctx.toks[j]:is_op(OP_BRACE_CLOSE) then
			j = j + 1;
			break;
		end

		if
			ctx.toks[j] and ctx.toks[j]:is_id() and
			ctx.toks[j + 1] and ctx.toks[j + 1]:is_op(OP_ASSIGN)
		then
			table.insert(keys, node.str(syntax_loc(ctx, j), ctx.toks[j].val --[[@as string]]));
			j = j + 2;

			j, val = parse_exp(ctx, j);
			if not val then
				syntax_error(ctx, j, "expected expression");
				val = node.error(syntax_loc(ctx, j));
			end
			table.insert(values, val);
		elseif ctx.toks[j] and ctx.toks[j]:is_op(OP_BRACKET_OPEN) then
			j = j + 1;

			j, key = parse_exp(ctx, j);
			if not key then
				syntax_error(ctx, j, "expected expression");
				key = node.error(syntax_loc(ctx, j));
			end

			if not ctx.toks[j] or not ctx.toks[j]:is_op(OP_BRACKET_CLOSE) then
				syntax_error(ctx, j, "expected ']'");
			else
				j = j + 1;
			end

			if not ctx.toks[j] or not ctx.toks[j]:is_op(OP_ASSIGN) then
				syntax_error(ctx, j, "expected '='");
			else
				j = j + 1;
			end

			j, val = parse_exp(ctx, j);
			if not val then
				syntax_error(ctx, j, "expected expression");
				val = node.error(syntax_loc(ctx, j));
			end

			table.insert(keys, key);
			table.insert(values, val);
		else
			j, val = parse_exp(ctx, j);
			if not val then
				syntax_error(ctx, j, "expected expression or '}'");
				break;
			else
				table.insert(array, val);
			end
		end

		local any = false;
		local eof = false;

		while true do
			if ctx.toks[j] and ctx.toks[j]:is_op(OP_BRACE_CLOSE) then
				j = j + 1;
				eof = true;
				break;
			elseif ctx.toks[j] and (ctx.toks[j]:is_op(OP_COMMA) or ctx.toks[j]:is_op(OP_SEMICOLON)) then
				j = j + 1;
				any = true;
			else
				break;
			end
		end

		if eof then
			break;
		elseif not any then
			syntax_error(ctx, j, "expected ',', ';' or '}'");
		end
	end

	return j, node.table(syntax_loc(ctx, i), keys, values, array);
end

--- @param i integer
local function parse_exp_call_suffix(ctx, i, prev)
	local j = i;
	local name;
	local has_method = false;

	if ctx.toks[j] and ctx.toks[j]:is_op(OP_COLON) then
		j = j + 1;
		has_method = true;
		if not ctx.toks[j] or not ctx.toks[j]:is_id() then
			syntax_error(ctx, j, "expected method name");
			name = "<error>";
		else
			name = ctx.toks[j].val --[[@as string]];
			j = j + 1;
		end
	end

	local args = {};

	if ctx.toks[j] and ctx.toks[j]:is_str() then
		table.insert(args, node.str(syntax_loc(ctx, i), ctx.toks[j].val --[[@as string]]));
		j = j + 1;
	elseif ctx.toks[j] and ctx.toks[j]:is_op(OP_BRACE_OPEN) then
		local arg;
		j, arg = parse_exp_table(ctx, j);
		table.insert(args, arg);
	elseif ctx.toks[j] and ctx.toks[j]:is_op(OP_BEGIN) then
		local arg;
		j, arg = parse_exp_func(ctx, j);
		table.insert(args, arg);
	elseif ctx.toks[j] and ctx.toks[j]:is_op(OP_PAREN_OPEN) then
		j = j + 1;

		if ctx.toks[j] and ctx.toks[j]:is_op(OP_PAREN_CLOSE) then
			j = j + 1;
		else
			while true do
				local exp;
				j, exp = parse_exp(ctx, j);
				if not exp then
					syntax_error(ctx, j, "expected expression or ')'");
					break;
				else
					table.insert(args, exp);
				end

				if ctx.toks[j] and ctx.toks[j]:is_op(OP_PAREN_CLOSE) then
					j = j + 1;
					break;
				elseif ctx.toks[j] and ctx.toks[j]:is_op(OP_COMMA) then
					j = j + 1;
				else
					syntax_error(ctx, j, "expected paren or comma");
				end
			end
		end
	elseif has_method then
		syntax_error(ctx, j, "expected '(', '{' or string literal");
	else
		return i;
	end

	if has_method then
		return j, node.method(syntax_loc(ctx, i), prev, name, args);
	else
		return j, node.call(syntax_loc(ctx, i), prev, args);
	end
end
local function parse_exp_index_suffix(ctx, i, prev)
	local j = i;

	local key;

 	if ctx.toks[j] and ctx.toks[j]:is_op(OP_DOT) then
		j = j + 1;

		if not ctx.toks[j] or not ctx.toks[j]:is_id() then
			if ctx.toks[j] and ctx.toks[j]:is_str() then
				syntax_error(ctx, j, "indexing with a string literal requires the bracket indexing syntax (obj['myprop'])");
				key = node.str(syntax_loc(ctx, j), ctx.toks[j].val --[[@as string]]);
				j = j + 1;
			else
				syntax_error(ctx, j, "expected identifier");
				key = node.error(syntax_loc(ctx, j));
			end
		else
			key = node.str(syntax_loc(ctx, j), ctx.toks[j].val --[[@as string]]);
			j = j + 1;
		end
	elseif ctx.toks[j] and ctx.toks[j]:is_op(OP_BRACKET_OPEN) then
		j = j + 1;

		j, key = parse_exp(ctx, j);
		if not key then
			syntax_error(ctx, j, "expected expression");
			key = node.error(syntax_loc(ctx, j));
		end

		if not ctx.toks[j] or not ctx.toks[j]:is_op(OP_BRACKET_CLOSE) then
			syntax_error(ctx, j, "expected ']'");
		else
			j = j + 1;
		end
	else
		return i;
	end

	if key then
		return j, node.index(syntax_loc(ctx, i), prev, key);
	else
		return j, prev;
	end
end
local function parse_exp_prefix(ctx, i, no_call)
	local j = i;
	local res;

	if ctx.toks[j] and ctx.toks[j]:is_id() then
		j = j + 1;
		res = node.var(syntax_loc(ctx, i), scope_lookup(ctx, ctx.toks[i].val --[[@as string]]));
	elseif ctx.toks[j] and ctx.toks[i]:is_op(OP_PAREN_OPEN) then
		j, res = parse_exp(ctx, j + 1);
		if not res then
			syntax_error(ctx, j, "expected expression");
			res = node.error(syntax_loc(ctx, j));
		end

		if not ctx.toks[j] or not ctx.toks[j]:is_op(OP_PAREN_CLOSE) then
			syntax_error(ctx, j, "expected ')'");
		end

		j = j + 1;

		if res.type ~= "paren" then
			res = node.paren(syntax_loc(ctx, i), res);
		end
	else
		return i;
	end

	while true do
		local new_call, new_index;

		if not no_call then
			j, new_call = parse_exp_call_suffix(ctx, j, res);
			if new_call then res = new_call end
		end

		j, new_index = parse_exp_index_suffix(ctx, j, res);
		if new_index then res = new_index end

		if not new_call and not new_index then break end
	end

	return j, res;
end

local function parse_exp_single(ctx, i)
	local j = i;

	if ctx.toks[j] then
		if ctx.toks[j]:is_op(OP_TRUE) then
			return j + 1, node.bool(syntax_loc(ctx, i), true);
		elseif ctx.toks[j]:is_op(OP_FALSE) then
			return j + 1, node.bool(syntax_loc(ctx, i), false);
		elseif ctx.toks[j]:is_op(OP_NIL) then
			return j + 1, node._nil(syntax_loc(ctx, i));
		elseif ctx.toks[j].type == "int" then
			return j + 1, node.int(syntax_loc(ctx, i), ctx.toks[j].val --[[@as integer]]);
		elseif ctx.toks[j].type == "fl" then
			return j + 1, node.fl(syntax_loc(ctx, i), ctx.toks[j].val --[[@as number]]);
		elseif ctx.toks[j].type == "str" then
			return j + 1, node.str(syntax_loc(ctx, i), ctx.toks[j].val --[[@as string]]);
		elseif ctx.toks[j]:is_op(OP_SPREAD) then
			return j + 1, node.args(syntax_loc(ctx, i));
		elseif ctx.toks[j]:is_op(OP_FUNCTION) then
			return parse_exp_func(ctx, j);
		elseif ctx.toks[j]:is_op(OP_BEGIN) then
			return parse_exp_func(ctx, j);
		elseif ctx.toks[j]:is_op(OP_BRACE_OPEN) then
			return parse_exp_table(ctx, j);
		else
			return parse_exp_prefix(ctx, j);
		end
	end
end
--- @return integer, node.exp?
local function parse_exp_part(ctx, i)
	local j = i;
	local prefix_ops = {};
	local res;

	while ctx.toks[j] and ctx.toks[j]:is_op() do
		local op = un_op_map[ctx.toks[j].val];
		if not op then break end

		table.insert(prefix_ops, op);
		j = j + 1;
	end

	if #prefix_ops == 0 then
		return parse_exp_single(ctx, j);
	else
		j, res = parse_exp(ctx, j, node.ops.POW);
		if not res then
			syntax_error(ctx, j, "expected expression");
			res = node.error(syntax_loc(ctx, j));
		end

		for k = #prefix_ops, 1, -1 do
			res = node.op(syntax_loc(ctx, i), prefix_ops[k], res);
		end

		return j, res;
	end
end

--- @param ctx syntax.ctx
--- @param i integer
--- @param a node.exp
--- @param max_op? integer
local function parse_exp_op(ctx, i, a, max_op)
	local j = i;

	if not ctx.toks[j] or not ctx.toks[j]:is_op() then return i end

	local op = bin_op_map[ctx.toks[j].val];
	if not op then return i end

	j = j + 1;

	if max_op and op > max_op then return i end
	if op == node.ops.POW or op == node.ops.CAT then
		max_op = op;
	else
		max_op = op - 1;
	end

	local b;
	j, b = parse_exp(ctx, j, max_op);
	if not b then
		syntax_error(ctx, j, "expected expression");
		b = node.error(syntax_loc(ctx, j));
	end

	return j, node.op(syntax_loc(ctx, i), op, a, b);
end

--- @param ctx syntax.ctx
--- @param i integer
--- @param max_op? integer
--- @return integer
--- @return node.exp?
function parse_exp(ctx, i, max_op)
	local j = i;
	local res;

	j, res = parse_exp_part(ctx, j);
	if not res then return i end

	while true do
		local new;
		j, new = parse_exp_op(ctx, j, res, max_op);
		if not new then break end

		res = new;
	end

	return j, res;
end

--- @param ctx syntax.ctx
--- @param i integer
function parse_exp_list(ctx, i)
	local j = i;
	--- @type node.exp[]
	local res = {};

	while true do
		local exp;
		j, exp = parse_exp(ctx, j);
		if not exp then
			if #res == 0 then return i end
			syntax_error(ctx, j, "expected expression");
			break;
		end
		table.insert(res, exp);

		if not ctx.toks[j] or not ctx.toks[j]:is_op(OP_COMMA) then break end
		j = j + 1;
	end

	return j, res;
end

------------ STATEMENTS ------------

--- @type table<integer, fun(ctx: syntax.ctx, i: integer): integer, node.stm>
local map_stm_parsers = {
	[OP_IF] = function (ctx, i)
		local j = i;

		local conds = {};
		local bodies = {};
		local default;
		local start_op = OP_IF;

		while start_op ~= OP_END do
			if start_op == OP_IF or start_op == OP_ELSEIF then
				local cond, body;

				j, cond = parse_exp(ctx, j);
				if not cond then
					syntax_error(ctx, j, "expected expression");
					cond = node.error(syntax_loc(ctx, j));
				end

				if not ctx.toks[j] or not ctx.toks[j]:is_op(OP_THEN) then
					syntax_error(ctx, j, "expected 'then'");
				else
					j = j + 1;
				end

				scope_begin(ctx);
				j, body, start_op = parse_stm_list(ctx, j, "'elseif', 'else' or 'end'", { OP_ELSEIF, OP_ELSE, OP_END });
				scope_end(ctx);

				table.insert(conds, cond);
				table.insert(bodies, body);
			elseif start_op == OP_ELSE then
				scope_begin(ctx);
				j, default, start_op = parse_stm_list(ctx, j, "'end'", { OP_END });
				scope_end(ctx);
				if not default then syntax_error(ctx, j, "expected else body") end
				break;
			end
		end

		return j, node._if(syntax_loc(ctx, i - 1), conds, bodies, default);
	end,
	[OP_WHILE] = function (ctx, i)
		local j = i;

		local cond, body;

		j, cond = parse_exp(ctx, j);
		if not cond then
			syntax_error(ctx, j, "expected expression");
			cond = node.error(syntax_loc(ctx, j));
		end

		if not ctx.toks[j] or not ctx.toks[j]:is_op(OP_DO) then
			syntax_error(ctx, j, "expected 'do'");
		end
		j = j + 1;

		scope_begin(ctx);
		j, body = parse_stm_list(ctx, j, "'end'", { OP_END });
		scope_end(ctx);

		return j, node._while(syntax_loc(ctx, i - 1), cond, body);
	end,
	[OP_REPEAT] = function (ctx, i)
		local j = i;

		local cond, body;

		scope_begin(ctx);
		j, body = parse_stm_list(ctx, j, "'until'", { OP_UNTIL });

		j, cond = parse_exp(ctx, j);
		if not cond then
			syntax_error(ctx, j, "expected expression");
			cond = node.error(syntax_loc(ctx, j));
		end
		scope_end(ctx);

		return j, node._repeat(syntax_loc(ctx, i - 1), cond, body);
	end,
	[OP_FOR] = function (ctx, i)
		local j = i;

		local names, values, init, last, step, body;

		scope_begin(ctx);
		j, names = parse_name_list(ctx, j);
		if not names then
			syntax_error(ctx, j, "expected identifier, then '=', or an identifier list, then 'in'");
			names = { node.error(syntax_loc(ctx, j)) };
		end

		if ctx.toks[j] and ctx.toks[j]:is_op(OP_ASSIGN) then
			j = j + 1;

			if #names ~= 1 then
				syntax_error(ctx, j, "exactly one variable name must be specified before '='");
			end

			j, init = parse_exp(ctx, j);
			if not init then
				syntax_error(ctx, j, "expected init expression");
				init = node.error(syntax_loc(ctx, j));
			end

			if not ctx.toks[j] or not ctx.toks[j]:is_op(OP_COMMA) then
				syntax_error(ctx, j, "expected ','");
			else
				j = j + 1;
			end

			j, last = parse_exp(ctx, j);
			if not last then
				syntax_error(ctx, j, "expected last expression");
				last = node.error(syntax_loc(ctx, j));
			end

			if ctx.toks[j] and ctx.toks[j]:is_op(OP_COMMA) then
				j = j + 1;

				j, step = parse_exp(ctx, j);
				if not step then
					syntax_error(ctx, j, "expected step expression");
					step = node.error(syntax_loc(ctx, j));
				end
			end
		else
			if not ctx.toks[j] and not ctx.toks[j]:is_op(OP_IN) then
				syntax_error(ctx, j, "expected '=' or 'in'");
			else
				j = j + 1;
			end

			j, values = parse_exp_list(ctx, j);
			if not values then
				syntax_error(ctx, j, "expected value list");
				values = {};
			end
		end

		if not ctx.toks[j] or not ctx.toks[j]:is_op(OP_DO) then
			syntax_error(ctx, j, step and "expected 'do'" or "expected ',' or 'do'");
		else
			j = j + 1;
		end

		j, body = parse_stm_list(ctx, j, "'end'", { OP_END });
		scope_end(ctx);

		if values then
			return j, node.for_in(syntax_loc(ctx, i - 1), names, values, body);
		else
			return j, node._for(syntax_loc(ctx, i - 1), names[1], init, last, step, body);
		end
	end,
	[OP_DO] = function (ctx, i)
		local j = i;
		local body;

		scope_begin(ctx);
		j, body = parse_stm_list(ctx, j, "'end'", { OP_END });
		scope_end(ctx);

		return j, node.scope(syntax_loc(ctx, i - 1), body);
	end,
	[OP_RETURN] = function (ctx, i)
		local j = i;

		local vals;
		j, vals = parse_exp_list(ctx, j);
		vals = vals or {};

		return j, node._return(syntax_loc(ctx, i - 1), vals);
	end,
	[OP_BREAK] = function (ctx, i)
		return i, node._break(syntax_loc(ctx, i - 1));
	end,
	-- [OP_CONTINUE] = function (ctx, i)
	-- 	return i, node._continue(syntax_loc(ctx, i - 1));
	-- end,
	[OP_LOCAL] = function (ctx, i)
		local j = i;

		if ctx.toks[j]:is_op(OP_FUNCTION) then
			local name, func;

			local def_start = syntax_loc(ctx, i);
			j = j + 1;

			if not ctx.toks[j] or not ctx.toks[j]:is_id() then
				name = node.error(syntax_loc(ctx, j));
				syntax_error(ctx, j, "expected function name after 'local function'");
			end

			name = scope_declare(ctx, syntax_loc(ctx, j), ctx.toks[j].val --[[@as string]]);
			j = j + 1;

			j, func = parse_func_body(ctx, j, def_start);

			return j, node.decl(syntax_loc(ctx, i - 1), true, { name }, { func });
		end

		local names, values;

		j, names = parse_name_list(ctx, j);
		if not names then
			syntax_error(ctx, j, "expected name list");
			names = {};
		end

		if ctx.toks[j] and ctx.toks[j]:is_op(OP_ASSIGN) then
			j = j + 1;

			j, values = parse_exp_list(ctx, j);
			if not values then
				syntax_error(ctx, j, "expected value list");
				values = {};
			end
		end

		return j, node.decl(syntax_loc(ctx, i - 1), false, names, values);
	end,
	[OP_FUNCTION] = function (ctx, i)
		local j = i;
		local target, func;

		j, target = parse_exp_prefix(ctx, j, true);
		if not target then
			syntax_error(ctx, j, "expected function assign target");
			target = node.error(syntax_loc(ctx, j));
		end

		local args;
		if ctx.toks[j] and ctx.toks[j]:is_op(OP_COLON) then
			local index_loc = ctx.toks[j].loc;
			args = { "self" };
			j = j + 1;

			local name_loc = ctx.toks[j].loc;
			local name;
			if not ctx.toks[j] or not ctx.toks[j]:is_id() then
				syntax_error(ctx, j, "expected identifier");
			else
				name = ctx.toks[j].val --[[@as string]];
				j = j + 1;
			end
			if name then
				target = node.index(index_loc, target, node.str(name_loc, name));
			end
		end

		--- @cast target node.assign_target
		j, func = parse_func_body(ctx, j, syntax_loc(ctx, i - 1), args);

		return j, node.assign(syntax_loc(ctx, i - 1), { target }, { func });
	end,

	[OP_LABEL] = function (ctx, i)
		local j = i;

		local name;
		if not ctx.toks[j] or not ctx.toks[j]:is_id() then
			syntax_error(ctx, j, "expected label name");
		else
			name = ctx.toks[j].val --[[@as string]];
			j = j + 1;
		end

		if not ctx.toks[j] or not ctx.toks[j]:is_op(OP_LABEL) then
			syntax_error(ctx, j, "expected closing '::'");
		else
			j = j + 1;
		end

		if not name then return j, node.error(syntax_loc(ctx, i)) --[[@as node.stm]] end

		local lbl = node.label(syntax_loc(ctx, i), name);

		if ctx.scope.labels[name] then
			syntax_error(ctx, j, "label '" .. name .. "' already defined");
		else
			ctx.scope.labels[name] = lbl;
		end

		return j, lbl;
	end,
	[OP_GOTO] = function (ctx, i)
		local j = i;

		local name;
		if not ctx.toks[j] or not ctx.toks[j]:is_id() then
			syntax_error(ctx, j, "expected goto target label name");
		else
			name = ctx.toks[j].val --[[@as string]];
			j = j + 1;
		end

		if not name then return j, node.error(syntax_loc(ctx, i)) --[[@as node.stm]] end

		if ctx.scope.labels[name] then
			return j, node._goto(syntax_loc(ctx, i), ctx.scope.labels[name]);
		else
			local gt = node._goto(syntax_loc(ctx, i), nil);
			ctx.scope.gotos[gt] = name;
			return j, gt;
		end
	end
};

--- @type table<integer, integer>
local map_assign_ops = {
	[OP_ASSIGN_ADD] = node.ops.ADD,
	[OP_ASSIGN_SUB] = node.ops.SUB,
	[OP_ASSIGN_MUL] = node.ops.MUL,
	[OP_ASSIGN_DIV] = node.ops.DIV,
	[OP_ASSIGN_IDIV] = node.ops.IDIV,
	[OP_ASSIGN_MOD] = node.ops.MOD,
	[OP_ASSIGN_BAND] = node.ops.B_AND,
	[OP_ASSIGN_BOR] = node.ops.B_OR,
	[OP_ASSIGN_BXOR] = node.ops.B_XOR,
	[OP_ASSIGN_SHL] = node.ops.B_SHL,
	[OP_ASSIGN_SHR] = node.ops.B_SHR,
};

local function finish_assign_values(ctx, i, targets)
	local j = i;
	local values;

	j, values = parse_exp_list(ctx, j);
	if not values then
		syntax_error(ctx, j, "expected value list");
		values = {};
	end

	return j, node.assign(syntax_loc(ctx, i), targets, values);
end
local function finish_assign_targets(ctx, i, target)
	local j = i;

	--- @type node.assign_target[]
	local targets = { target };

	while true do
		j, target = parse_exp_prefix(ctx, j);
		if not target then
			syntax_error(ctx, j, "expected member expression or variable name");
			target = node.error(syntax_loc(ctx, j));
		end
		if target.type ~= "var" and target.type ~= "index" then
			syntax_error(ctx, j, "expected member expression or variable name");
		end

		table.insert(targets, target);

		if ctx.toks[j] and ctx.toks[j]:is_op(OP_COMMA) then
			j = j + 1;
		elseif ctx.toks[j] and ctx.toks[j]:is_op(OP_ASSIGN) then
			j = j + 1;
			return finish_assign_values(ctx, j, targets);
		else
			syntax_error(ctx, j, "expected ',' or '='");
		end
	end
end

--- @param ctx syntax.ctx
--- @param i integer
function parse_stm(ctx, i)
	local j = i;

	if not ctx.toks[i] then return i end

	if ctx.toks[j]:is_op() then
		local cb = map_stm_parsers[ctx.toks[j].val];
		if cb then return cb(ctx, j + 1) end
	end

	local target;
	local exp_i = j;

	j, target = parse_exp_prefix(ctx, j);
	if not target then return i end

	if ctx.toks[j] and ctx.toks[j]:is_op(OP_ASSIGN) then
		j = j + 1;

		if target.type ~= "var" and target.type ~= "index" then
			syntax_error(ctx, exp_i, "expected assign target");
		end

		return finish_assign_values(ctx, j, { target --[[@as node.assign_target]] });
	elseif ctx.toks[j] and ctx.toks[j]:is_op() and map_assign_ops[ctx.toks[j].val] then
		local assign_op = map_assign_ops[ctx.toks[j].val];
		local val;

		j = j + 1;

		if target.type ~= "var" and target.type ~= "index" then
			syntax_error(ctx, exp_i, "expected assign target");
		end

		j, val = parse_exp(ctx, j);
		if not val then
			syntax_error(ctx, j, "expected value");
			val = node.error(syntax_loc(ctx, j));
		end

		return j, node.assign(syntax_loc(ctx, i),
			{ target --[[@as node.assign_target]] },
			{ node.op(syntax_loc(ctx, i), assign_op, target, val) }
		);
	elseif ctx.toks[j] and ctx.toks[j]:is_op(OP_COMMA) then
		j = j + 1;

		if target.type ~= "var" and target.type ~= "index" then
			syntax_error(ctx, i, "expected assign target");
		end

		return finish_assign_targets(ctx, j, target --[[@as node.assign_target]]);
	else
		if target.type ~= "call" and target.type ~= "method" then
			syntax_error(ctx, exp_i, "unexpected standalone non-call expression");
		end
		return j, target;
	end
end

--- @param ctx syntax.ctx
--- @param i integer
--- @param eof_name string
--- @param eof? integer[]
--- @return integer
--- @return node.stm[]
--- @return integer
function parse_stm_list(ctx, i, eof_name, eof)
	local j = i;
	local res = {};

	local last_bad = false;

	while true do
		while ctx.toks[j] and ctx.toks[j]:is_op(OP_SEMICOLON) do
			j = j + 1;
		end

		if j > #ctx.toks then
			if eof then
				syntax_error(ctx, j, "expected statement or " .. eof_name)
			end
			return j, res, OP_END;
		end

		if eof then
			for k = 1, #eof do
				if ctx.toks[j]:is_op(eof[k]) then
					return j + 1, res, ctx.toks[j].val --[[@as integer]];
				end
			end
		end

		if #res > 0 and res[#res].type == "return" then
			syntax_error(ctx, j, "expected " .. eof_name .. " after return");
		end

		local stm;
		j, stm = parse_stm(ctx, j);
		if not stm then
			if not last_bad then
				syntax_error(ctx, j, "bad syntax");
			end
			last_bad = true;
			j = j + 1;
		else
			last_bad = false;
		end

		table.insert(res, stm);
	end
end

--- @param src syntax.ctx | string
--- @param strip? boolean
local function parse_stm_wrap(src, strip)
	if type(src) == "string" then
		local toks, err, loc = lex.parse(src, strip);
		if not toks then return {}, { { msg = err, loc = loc } } end
		src = {
			toks = toks, errs = {},
			glob = { gotos = {}, labels = {}, vars = {} },
			scope = { gotos = {}, labels = {}, vars = {} }
		};
	end

	scope_begin(src);
	local i, res = parse_stm_list(src, 1, "end of file", nil);
	finish_labels(src);
	scope_end(src);
	return res, src.errs;
end
--- @param src syntax.ctx | string
--- @param strip? boolean
local function parse_exp_wrap(src, strip)
	if type(src) == "string" then
		local toks, err, loc = lex.parse(src, strip);
		if not toks then return node.error(), { { msg = err, loc = loc } } end
		src = {
			toks = toks, errs = {},
			glob = { gotos = {}, labels = {}, vars = {} },
			scope = { gotos = {}, labels = {}, vars = {} }
		};
	end

	local i, res = parse_exp(src, 1, nil);
	if i <= #src then
		table.insert(src.errs, { msg = "unexpected syntax", src[i].loc });
	end

	return res, src.errs;
end

return {
	parse_exp = parse_exp_wrap,
	parse = parse_stm_wrap,
};

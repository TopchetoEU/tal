local node = {};

--- @class node.base
--- @field loc? node.loc

--- @class node.error: node.base
--- @field type "error"

--- @class node.decl: node.base
--- @field type "decl"
--- @field pre boolean
--- @field names node.name[]
--- @field values? node.exp[]

--- @class node.assign: node.base
--- @field type "assign"
--- @field targets node.assign_target[]
--- @field values node.exp[]

--- @class node.if: node.base
--- @field type "if"
--- @field conds node.exp[]
--- @field bodies node.body[]
--- @field default? node.body

--- @class node.while: node.base
--- @field type "while"
--- @field cond node.exp
--- @field body node.body

--- @class node.for: node.base
--- @field type "for"
--- @field name node.name
--- @field first node.exp
--- @field last node.exp
--- @field step? node.exp
--- @field body node.body

--- @class node.for_in: node.base
--- @field type "for_in"
--- @field names node.name[]
--- @field values node.exp[]
--- @field body node.body

--- @class node.repeat: node.base
--- @field type "repeat"
--- @field cond node.exp
--- @field body node.body

--- @class node.scope: node.base
--- @field type "scope"
--- @field body node.body

--- @class node.return: node.base
--- @field type "return"
--- @field vals node.exp[]

--- @class node.break: node.base
--- @field type "break"

--- @class node.continue: node.base
--- @field type "continue"

--- @class node.goto: node.base
--- @field type "goto"
--- @field target node.label

--- @class node.label: node.base
--- @field type "label"
--- @field name string

--- @class node.call: node.base
--- @field type "call"
--- @field func node.exp
--- @field args node.exp[]

--- @class node.method: node.base
--- @field type "method"
--- @field obj node.exp
--- @field name string
--- @field args node.exp[]

--- @class node.index: node.base
--- @field type "index"
--- @field obj node.exp
--- @field key node.exp

--- @class node.op: node.base
--- @field type "op"
--- @field op integer
--- @field a node.exp
--- @field b? node.exp

--- @class node.paren: node.base
--- @field type "paren"
--- @field val node.exp


--- @class node.func: node.base
--- @field type "func"
--- @field def_end? node.loc
--- @field args node.name[]
--- @field var boolean
--- @field body node.body

--- @class node.table: node.base
--- @field type "table"
--- @field keys node.exp[]
--- @field vals node.exp[]
--- @field arr node.exp[]

--- @class node.name: node.base
--- @field type "name"
--- @field name string
--- @field global boolean

--- @class node.var: node.base
--- @field type "var"
--- @field name node.name

--- @class node.nil: node.base
--- @field type "nil"

--- @class node.args: node.base
--- @field type "args"

--- @class node.str: node.base
--- @field type "str"
--- @field val string

--- @class node.bool: node.base
--- @field type "bool"
--- @field val boolean

--- @class node.int: node.base
--- @field type "int"
--- @field val integer

--- @class node.fl: node.base
--- @field type "fl"
--- @field val number

--- @alias node.exp node.func | node.call | node.method | node.index | node.op | node.table | node.var | node.args | node.nil | node.str | node.bool | node.fl | node.int | node.paren | node.error
--- @alias node.assign_target node.index | node.name
--- @alias node.stm node.decl | node.assign | node.if | node.while | node.repeat | node.for | node.for_in | node.scope | node.return | node.break | node.continue | node.call | node.goto | node.label
--- @alias node node.stm | node.exp | node.name

--- @alias node.body node.stm[]

node.ops = {
	PREC_PAREN = -100,
	PREC_CONST = -50,

	POW = 1,

	NOT = 2,
	NEG = 3,
	LEN = 4,
	B_NEG = 5,

	MUL = 10,
	DIV = 11,
	MOD = 12,
	IDIV = 13,

	ADD = 14,
	SUB = 15,

	CAT = 16,

	B_SHL = 21,
	B_SHR = 22,
	B_AND = 23,
	B_OR = 24,
	B_XOR = 25,

	EQ = 30,
	NEQ = 31,
	LE = 32,
	GR = 33,
	LEQ = 34,
	GREQ = 35,

	AND = 36,
	OR = 37,

	PREC_NONE = 100,
};

--- @class node.loc
--- @field _cb? fun(): integer, integer
--- @field row? integer
--- @field col? integer
local loc_index = {};
loc_index.__index = loc_index;

function loc_index:get()
	if not self.row or not self.col then
		self.row, self.col = self._cb();
		self._cb = nil;
	end

	return self;
end

function loc_index:__tostring()
	local r, c = self:get();
	return r .. ":" .. c;
end

--- @param cb fun(self: node.loc)
--- @return node.loc
function node.lazy_loc(cb)
	return { get = cb };
end
--- @param row integer
--- @param col integer
--- @return node.loc
function node.loc(row, col)
	return { row = row, col = col };
end

--- @param arr node.stm[]
function node.body(arr)
	return arr --[[@as node.body]];
end

--- @param line? node.loc
function node.error(line)
	return { type = "error", loc = line } --[[@as node.error]];
end
--- @param line? node.loc
--- @param pre? boolean If the variables are declared before or after the values
--- @param values? node.exp[]
function node.decl(line, pre, names, values)
	return { type = "decl", loc = line, pre = pre or false, names = names, values = values } --[[@as node.decl]];
end
--- @param line? node.loc
--- @param targets node.assign_target[]
--- @param values node.exp[]
function node.assign(line, targets, values)
	return { type = "assign", loc = line, targets = targets, values = values } --[[@as node.assign]];
end

--- @param line? node.loc
--- @param conds node.exp[]
--- @param bodies node.body[]
--- @param default? node.body
function node._if(line, conds, bodies, default)
	return { type = "if", loc = line, conds = conds, bodies = bodies, default = default } --[[@as node.if]];
end
--- @param line? node.loc
--- @param cond node.exp
--- @param body node.body
function node._while(line, cond, body)
	return { type = "while", loc = line, cond = cond, body = body } --[[@as node.while]];
end
--- @param line? node.loc
--- @param cond node.exp
--- @param body node.body
function node._repeat(line, cond, body)
	return { type = "repeat", loc = line, cond = cond, body = body } --[[@as node.repeat]];
end
--- @param line? node.loc
--- @param name node.name
--- @param first node.exp
--- @param last node.exp
--- @param step? node.exp
--- @param body node.body
function node._for(line, name, first, last, step, body)
	return { type = "for", loc = line, name = name, first = first, last = last, step = step, body = body } --[[@as node.for]];
end
--- @param line? node.loc
--- @param names node.name[]
--- @param values node.exp[]
--- @param body node.body
function node.for_in(line, names, values, body)
	return { type = "for_in", loc = line, names = names, values = values, body = body } --[[@as node.for_in]];
end
--- @param line? node.loc
--- @param body node.body
function node.scope(line, body)
	return { type = "scope", loc = line, body = body } --[[@as node.scope]];
end
--- @param line? node.loc
--- @param vals node.exp
function node._return(line, vals)
	return { type = "return", loc = line, vals = vals } --[[@as node.return]];
end
--- @param line? node.loc
function node._break(line)
	return { type = "break", loc = line } --[[@as node.break]];
end
--- @param line? node.loc
function node._continue(line)
	return { type = "continue", loc = line } --[[@as node.continue]];
end
--- @param line? node.loc
function node._goto(line, target)
	return { type = "goto", target = target, loc = line } --[[@as node.goto]];
end
--- @param line? node.loc
--- @param name string
function node.label(line, name)
	return { type = "label", name = name, loc = line } --[[@as node.label]];
end

--- @param name string
--- @param global boolean
function node.name(line, name, global)
	return { type = "name", loc = line, name = name, global = global } --[[@as node.name]];
end
--- @param name node.name
function node.var(line, name)
	return { type = "var", loc = line, name = name } --[[@as node.var]];
end
--- @param line? node.loc
function node.args(line)
	return { type = "args", loc = line } --[[@as node.args]];
end
--- @param line? node.loc
function node._nil(line)
	return { type = "nil", loc = line } --[[@as node.nil]];
end
--- @param line? node.loc
--- @param val boolean
function node.bool(line, val)
	return { type = "bool", loc = line, val = val } --[[@as node.bool]];
end
--- @param line? node.loc
--- @param val string
function node.str(line, val)
	return { type = "str", loc = line, val = val } --[[@as node.str]];
end
--- @param line? node.loc
--- @param val integer
function node.int(line, val)
	return { type = "int", loc = line, val = val } --[[@as node.int]];
end
--- @param line? node.loc
--- @param val number
function node.fl(line, val)
	return { type = "fl", loc = line, val = val } --[[@as node.fl]];
end
--- @param line? node.loc
--- @param op integer
--- @param a node.exp
--- @param b? node.exp
function node.op(line, op, a, b)
	return { type = "op", loc = line, op = op, a = a, b = b } --[[@as node.op]];
end

--- @param line? node.loc
--- @param val node.exp
function node.paren(line, val)
	return { type = "paren", loc = line, val = val } --[[@as node.paren]];
end
--- @param line? node.loc
--- @param def_end? node.loc
--- @param args node.name[]
--- @param var boolean
--- @param body node.body
function node.func(line, def_end, args, var, body)
	return { type = "func", loc = line, def_end = def_end, args = args, var = var, body = body } --[[@as node.func]];
end

--- @param line? node.loc
--- @param func node.exp
--- @param args node.exp[]
function node.call(line, func, args)
	return { type = "call", loc = line, func = func, args = args } --[[@as node.call]];
end
--- @param line? node.loc
--- @param obj node.exp
--- @param name string
--- @param args node.exp[]
function node.method(line, obj, name, args)
	return { type = "method", loc = line, obj = obj, name = name, args = args } --[[@as node.method]];
end
--- @param line? node.loc
--- @param keys node.exp[]
--- @param vals node.exp[]
--- @param arr node.exp[]
function node.table(line, keys, vals, arr)
	return { type = "table", loc = line, keys = keys, vals = vals, arr = arr } --[[@as node.table]];
end

--- @param line? node.loc
--- @param obj node.exp
--- @param key node.exp
function node.index(line, obj, key)
	return { type = "index", loc = line, obj = obj, key = key } --[[@as node.index]];
end

return node;

local node = {};

--- @class node.loc
--- @field row integer
--- @field col integer

--- @class node.base
--- @field loc node.loc

--- @class node.decl: node.base
--- @field type "decl"
--- @field pre boolean
--- @field names string[]
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
--- @field name string
--- @field first node.exp
--- @field last node.exp
--- @field step? node.exp
--- @field body node.body

--- @class node.for_in: node.base
--- @field type "for_in"
--- @field names string[]
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
--- @field [integer] node.exp

--- @class node.break: node.base
--- @field type "break"


--- @class node.call: node.base
--- @field type "call"
--- @field func node.exp
--- @field [integer] node.exp

--- @class node.method: node.base
--- @field type "method"
--- @field obj node.method
--- @field name string
--- @field [integer] node.exp

--- @class node.index: node.base
--- @field type "index"
--- @field obj node.exp
--- @field key node.exp

--- @class node.op: node.base
--- @field type "op"
--- @field op node.op
--- @field a node.exp
--- @field b? node.exp
--- @field [integer] node.exp

--- @class node.paren: node.base
--- @field type "paren"
--- @field val node.exp


--- @class node.func: node.base
--- @field type "func"
--- @field args string[]
--- @field var boolean
--- @field body node.body

--- @class node.table: node.base
--- @field type "table"
--- @field keys node.exp[]
--- @field vals node.exp[]
--- @field arr node.exp[]

--- @class node.var: node.base
--- @field type "var"
--- @field name string

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

--- @alias node.exp node.func | node.call | node.method | node.index | node.op | node.table | node.var | node.args | node.nil | node.str | node.bool | node.fl | node.int | node.paren
--- @alias node.assign_target node.index | node.var
--- @alias node.stm node.decl | node.assign | node.if | node.while | node.repeat | node.for | node.for_in | node.scope | node.return | node.break | node.call
--- @alias node node.stm | node.exp

--- @alias node.body node.stm[]

node.ops = {
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
};

--- @param row integer
--- @param col integer
--- @return node.loc
function node.loc(row, col)
	return { row = row, col = col };
end

if jit then
	local ffi = require "ffi";
	ffi.cdef [[
		typedef struct {
			uint32_t row;
			uint32_t col;
		} node_loc_t;
	]];

	node.loc = ffi.metatype("node_loc_t", {
		__tostring = function (self)
			return ("%d:%d"):format(self.row, self.col);
		end,
	}) --[[@as fun(row: integer, col: integer): node.loc]];
end


--- @param line? node.loc
--- @param pre? boolean If the variables are declared before or after the values
--- @param values? node.exp[]
--- @return node.decl
function node.decl(line, pre, names, values)
	return { type = "decl", loc = line, pre = pre or false, names = names, values = values };
end
--- @param line? node.loc
--- @param targets? node.assign_target[]
--- @param values? node.exp[]
--- @return node.assign
function node.assign(line, targets, values)
	return { type = "assign", loc = line, targets = targets, values = values };
end

--- @param line? node.loc
--- @param conds node.exp[]
--- @param bodies node.body[]
--- @param default? node.body
--- @return node.if
function node._if(line, conds, bodies, default)
	return { type = "if", loc = line, conds = conds, bodies = bodies, default = default };
end
--- @param line? node.loc
--- @param cond node.exp
--- @param body node.body
--- @return node.while
function node._while(line, cond, body)
	return { type = "while", loc = line, cond = cond, body = body };
end
--- @param line? node.loc
--- @param cond node.exp
--- @param body node.body
--- @return node.repeat
function node._repeat(line, cond, body)
	return { type = "repeat", loc = line, cond = cond, body = body };
end
--- @param line? node.loc
--- @param name string
--- @param first node.exp
--- @param last node.exp
--- @param step? node.exp
--- @param body node.body
--- @return node.for
function node._for(line, name, first, last, step, body)
	return { type = "for", loc = line, name = name, first = first, last = last, step = step, body = body };
end
--- @param line? node.loc
--- @param names string[]
--- @param values node.exp[]
--- @param body node.body
--- @return node.for
function node.for_in(line, names, values, body)
	return { type = "for_in", loc = line, names = names, values = values, body = body };
end
--- @param line? node.loc
--- @param body node.body
--- @return node.scope
function node.scope(line, body)
	return { type = "scope", loc = line, body = body };
end
--- @param line? node.loc
--- @param ... node.exp
--- @return node.return
function node._return(line, ...)
	return { type = "return", loc = line, ... };
end
--- @param line? node.loc
--- @return node.break
function node._break(line, ...)
	return { type = "break", loc = line };
end

--- @param name string
--- @return node.var
function node.var(line, name)
	return { type = "var", loc = line, name = name };
end
--- @param line? node.loc
--- @return node.args
function node.args(line)
	return { type = "args", loc = line };
end
--- @param line? node.loc
--- @return node.nil
function node._nil(line)
	return { type = "nil", loc = line };
end
--- @param line? node.loc
--- @param val boolean
--- @return node.bool
function node.bool(line, val)
	return { type = "bool", loc = line, val = val };
end
--- @param line? node.loc
--- @param val string
--- @return node.str
function node.str(line, val)
	return { type = "str", loc = line, val = val };
end
--- @param line? node.loc
--- @param val integer
--- @return node.int
function node.int(line, val)
	return { type = "int", loc = line, val = val };
end
--- @param line? node.loc
--- @param val number
--- @return node.fl
function node.fl(line, val)
	return { type = "fl", loc = line, val = val };
end
--- @param line? node.loc
--- @param op integer
--- @param a node.exp
--- @param b? node.exp
--- @return node.op
function node.op(line, op, a, b)
	return { type = "op", loc = line, op = op, a = a, b = b };
end

--- @param line? node.loc
--- @param val node.exp
--- @return node.paren
function node.paren(line, val)
	return { type = "paren", loc = line, val = val };
end
--- @param line? node.loc
--- @param args string[]
--- @param var boolean
--- @param body node.body
--- @return node.func
function node.func(line, args, var, body)
	return { type = "func", loc = line, args = args, var = var, body = body };
end

--- @param line? node.loc
--- @param func node.exp
--- @param ... node.exp
--- @return node.call
function node.call(line, func, ...)
	return { type = "call", loc = line, func = func, ... };
end
--- @param line? node.loc
--- @param obj node.exp
--- @param name string
--- @param ... node.exp
--- @return node.method
function node.method(line, obj, name, ...)
	return { type = "method", loc = line, obj = obj, name = name, ... };
end
--- @param line? node.loc
--- @param keys node.exp[]
--- @param vals node.exp[]
--- @param arr node.exp[]
--- @return node.table
function node.table(line, keys, vals, arr)
	return { type = "table", loc = line, keys = keys, vals = vals, arr = arr };
end

--- @param line? node.loc
--- @param obj node.exp
--- @param key node.exp
--- @return node.index
function node.index(line, obj, key)
	return { type = "index", loc = line, obj = obj, key = key };
end

return node;

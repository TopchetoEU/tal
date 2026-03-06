local nodes = require "tal.compiler.node";
--- @class stringify.ctx
--- @field parts string[]
--- @field map table<integer, node.loc>

--- @type table<string, fun(self: stringify.ctx, node: node)>
local walkers = {};

local op_str_map = {
	[nodes.ops.POW] = "^",

	[nodes.ops.NOT] = "not",
	[nodes.ops.NEG] = "-",
	[nodes.ops.LEN] = "#",
	[nodes.ops.B_NEG] = "~",

	[nodes.ops.MUL] = "*",
	[nodes.ops.DIV] = "/",
	[nodes.ops.MOD] = "%",
	[nodes.ops.IDIV] = "//",

	[nodes.ops.ADD] = "+",
	[nodes.ops.SUB] = "-",

	[nodes.ops.CAT] = "..",

	[nodes.ops.B_SHL] = "<<",
	[nodes.ops.B_SHR] = ">>",
	[nodes.ops.B_AND] = "&",
	[nodes.ops.B_OR] = "|",
	[nodes.ops.B_XOR] = "~",

	[nodes.ops.EQ] = "==",
	[nodes.ops.NEQ] = "~=",
	[nodes.ops.LE] = "<",
	[nodes.ops.GR] = ">",
	[nodes.ops.LEQ] = "<=",
	[nodes.ops.GREQ] = ">=",

	[nodes.ops.AND] = "and",
	[nodes.ops.OR] = "or",
}

--- @param self stringify.ctx
--- @param loc node | node.loc
--- @param str string
local function emit(self, loc, str)
	table.insert(self.parts, str);
	if loc.loc then
		self.map[#self.parts] = loc.loc;
	else
		self.map[#self.parts] = loc --[[@as node.loc]];
	end
end
--- @param self stringify.ctx
--- @param str string
local function suffix(self, str)
	if #self.parts == 0 then error "can't suffix now" end
	self.parts[#self.parts] = self.parts[#self.parts] .. str;
end

--- @param self stringify.ctx
--- @param node node
local function walk(self, node)
	local res = walkers[node.type];
	if not res then error("node '" .. node.type .. "' not walkable", 2) end

	return res(self, node);
end

--- @param self stringify.ctx
--- @param nodes node[]
--- @param sep? string
local function walk_all(self, nodes, sep)
	sep = sep or ";";
	for i = 1, #nodes do
		if i > 1 then suffix(self, sep) end
		walk(self, nodes[i]);
	end
end

--- @param node node.var
function walkers.var(self, node)
	emit(self, node, node.name);
end
--- @param node node.str
function walkers.str(self, node)
	emit(self, node, node.val:quote());
end
--- @param node node.nil
walkers["nil"] = function(self, node)
	emit(self, node, "nil");
end
--- @param node node.str
function walkers.bool(self, node)
	emit(self, node, tostring(node.val));
end
--- @param node node.int
function walkers.int(self, node)
	emit(self, node, ("%d"):format(node.val));
end
--- @param node node.fl
function walkers.fl(self, node)
	emit(self, node, tostring(node.val));
end
--- @param node node.args
function walkers.args(self, node)
	emit(self, node, "...");
end
--- @param node node.paren
function walkers.paren(self, node)
	emit(self, node, "(");
	walk(self, node.val);
	suffix(self, ")");
end
--- @param node node.table
function walkers.table(self, node)
	emit(self, node, "{");

	for i = 1, #node.keys do
		local key, val = node.keys[i], node.vals[i];

		-- TODO: use simple keys when possible, check for keywords

		-- if key.type == "str" and key.val:match "^[a-zA-Z_][a-zA-Z0-9_]*$" then
		-- 	emit(self, key, key.val);
		-- else
			suffix(self, "[");
			walk(self, key);
			suffix(self, "]");
		-- end

		suffix(self, "=");
		walk(self, val);
		suffix(self, ",");
	end

	for i = 1, #node.arr do
		local val = node.arr[i];

		walk(self, val);
		suffix(self, ",");
	end

	suffix(self, "}");
end
--- @param node node.func
function walkers.func(self, node)
	emit(self, node, "function (");
	for i = 1, #node.args do
		if i > 1 then suffix(self, ",") end
		suffix(self, node.args[i]);
	end

	if node.var then
		if #node.args > 0 then suffix(self, ",") end
		suffix(self, "...");
	end

	suffix(self, ")");

	walk_all(self, node.body, ";");

	suffix(self, " end");
end
--- @param node node.op
function walkers.op(self, node)
	if node.b then
		walk(self, node.a);
		emit(self, node, op_str_map[node.op]);
		walk(self, node.b);
	else
		emit(self, node, op_str_map[node.op]);
		walk(self, node.a);
	end
end

--- @param node node.call
function walkers.call(self, node)
	walk(self, node.func);
	suffix(self, "(");
	walk_all(self, node, ",");
	suffix(self, ")");
end
--- @param node node.method
function walkers.method(self, node)
	walk(self, node.obj);
	emit(self, node, ":" .. node.name .. "(");
	walk_all(self, node, ",");
	suffix(self, ")");
end
--- @param node node.index
function walkers.index(self, node)
	walk(self, node.obj);
	suffix(self, "[");
	walk(self, node.key);
	suffix(self, "]");
end

--- @param node node.decl
function walkers.decl(self, node)
	emit(self, node, "local ");
	for i = 1, #node.names do
		if i > 1 then suffix(self, ",") end
		suffix(self, node.names[i]);
	end

	if node.values then
		if node.pre then
			suffix(self, " ");
			for i = 1, #node.names do
				if i > 1 then suffix(self, ",") end
				suffix(self, node.names[i]);
			end
		end

		emit(self, node, "=");
		walk_all(self, node.values, ",");
	end
end
--- @param node node.assign
function walkers.assign(self, node)
	walk_all(self, node.targets, ", ");
	emit(self, node, "=");
	walk_all(self, node.values, ", ");
end
--- @param node node.if
walkers["if"] = function (self, node)
	for i = 1, #node.conds do
		local cond, body = node.conds[i], node.bodies[i];

		if i == 1 then
			emit(self, node, "if");
		else
			emit(self, node, "elseif");
		end

		walk(self, cond);

		suffix(self, " then");

		walk_all(self, body, ";");
	end

	if node.default then
		emit(self, node, "else");
		walk_all(self, node.default, ";");
	end
	suffix(self, " end");
end
--- @param node node.while
walkers["while"] = function (self, node)
	emit(self, node, "while");
	walk(self, node.cond);
	suffix(self, " do");
	walk_all(self, node.body, ";");
	suffix(self, " end");
end
--- @param node node.while
walkers["repeat"] = function (self, node)
	emit(self, node, "repeat");
	walk_all(self, node.body, ";");
	emit(self, node, "until");
	walk(self, node.cond);
end
--- @param node node.for
walkers["for"] = function (self, node)
	emit(self, node, "for " .. node.name .. " =");
	walk_all(self, { node.first, node.last, node.step }, ",");
	suffix(self, " do");
	walk_all(self, node.body, ";");
	suffix(self, " end");
end
--- @param node node.for_in
function walkers.for_in(self, node)
	emit(self, node, "for ");

	for i = 1, #node.names do
		if i > 1 then suffix(self, ",") end
		suffix(self, node.names[i]);
	end

	suffix(self, " in");
	walk_all(self, node.values, ",");
	suffix(self, " do");
	walk_all(self, node.body, ";");
	suffix(self, " end");
end
--- @param node node.scope
function walkers.scope(self, node)
	emit(self, node, "do ");
	walk_all(self, node.body, ";");
	suffix(self, " end");
end

--- @param node node.return
walkers["return"] = function (self, node)
	emit(self, node, "return");
	walk_all(self, node, ",");
end
--- @param node node.break
walkers["break"] = function (self, node)
	emit(self, node, "break");
end

--- @generic T
--- @param arg T
--- @param func fun(self: stringify.ctx, arg: T)
local function wrap(arg, func)
	--- @type stringify.ctx
	local self = { parts = {}, map = {} };
	func(self, arg);
	return table.concat(self.parts, "\n"), self.map;
end

return {
	--- @param node node
	one = function (node)
		return wrap(node, walk);
	end,
	--- @param nodes node[]
	all = function (nodes)
		return wrap(nodes, walk_all);
	end
};

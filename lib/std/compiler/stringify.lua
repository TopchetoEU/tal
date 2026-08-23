local nodes = require "std.compiler.node";
local buffer = require "string.buffer";

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

--- @class stringify.ctx
--- @field buff string.buffer
--- @field lines integer
--- @field map table<integer, node.loc>
local ctx_meta = {};
ctx_meta.__index = ctx_meta;
ctx_meta.__metatable = "compiler.stringify.ctx";

--- @param val string
function ctx_meta:suffix(val)
	self.buff:put(val);
	return self;
end
--- @param loc node | node.loc
--- @param val string
function ctx_meta:emit(loc, val)
	self.lines = self.lines + 1;
	if loc and loc.loc then
		if loc.loc.get then loc.loc:get() end
		self.map[self.lines] = loc.loc;
	else
		if loc and loc.get then loc:get() end
		self.map[self.lines] = loc --[[@as node.loc]];
	end

	if #self.buff == 0 then
		return self:suffix(val);
	else
		return self:suffix("\n" .. val);
	end
end

--- @param node node
function ctx_meta:walk(node)
	local res = walkers[node.type];
	if not res then error("node '" .. node.type .. "' not walkable", 2) end

	return res(self, node);
end
--- @param nodes node[]
--- @param sep? string
function ctx_meta:walk_all(nodes, sep)
	sep = sep or ";";
	for i = 1, #nodes do
		if i > 1 then self:suffix(sep) end
		self:walk(nodes[i]);
	end
end

function ctx_meta.new()
	return setmetatable({ buff = buffer.new(), lines = 0, map = {} }, ctx_meta);
end


--- @param self stringify.ctx
--- @param node node.var
function walkers.name(self, node)
	self:emit(node, node.name.name);
end
--- @param self stringify.ctx
--- @param node node.var
function walkers.var(self, node)
	self:emit(node, node.name.name);
end
--- @param self stringify.ctx
--- @param node node.str
function walkers.str(self, node)
	self:emit(node, node.val:quote());
end
--- @param self stringify.ctx
--- @param node node.nil
walkers["nil"] = function(self, node)
	self:emit(node, "nil");
end
--- @param self stringify.ctx
--- @param node node.str
function walkers.bool(self, node)
	self:emit(node, tostring(node.val));
end
--- @param self stringify.ctx
--- @param node node.int
function walkers.int(self, node)
	self:emit(node, ("%d"):format(node.val));
end
--- @param self stringify.ctx
--- @param node node.fl
function walkers.fl(self, node)
	self:emit(node, tostring(node.val));
end
--- @param self stringify.ctx
--- @param node node.args
function walkers.args(self, node)
	self:emit(node, "...");
end
--- @param self stringify.ctx
--- @param node node.paren
function walkers.paren(self, node)
	self:emit(node, "(");
	self:walk(node.val);
	self:suffix(")");
end
--- @param self stringify.ctx
--- @param node node.table
function walkers.table(self, node)
	self:emit(node, "{");

	for i = 1, #node.keys do
		local key, val = node.keys[i], node.vals[i];

		-- TODO: use simple keys when possible, check for keywords

		-- if key.type == "str" and key.val:match "^[a-zA-Z_][a-zA-Z0-9_]*$" then
		-- 	self:emit(key, key.val);
		-- else
			self:suffix("[");
			self:walk(key);
			self:suffix("]");
		-- end

		self:suffix("=");
		self:walk(val);
		self:suffix(",");
	end

	for i = 1, #node.arr do
		local val = node.arr[i];

		self:walk(val);
		self:suffix(",");
	end

	self:suffix("}");
end
--- @param self stringify.ctx
--- @param node node.func
function walkers.func(self, node)
	self:emit(node.loc, "function (");
	for i = 1, #node.args do
		if i > 1 then self:suffix(",") end
		self:suffix(node.args[i].name);
	end

	if node.var then
		if #node.args > 0 then self:suffix(",") end
		self:suffix("...");
	end

	self:suffix(")");

	self:walk_all(node.body, ";");

	self:emit(node.def_end, "end");
end
--- @param self stringify.ctx
--- @param node node.op
function walkers.op(self, node)
	if node.b then
		self:walk(node.a);
		self:emit(node, op_str_map[node.op]);
		self:walk(node.b);
	else
		self:emit(node, op_str_map[node.op]);
		self:walk(node.a);
	end
end

--- @param self stringify.ctx
--- @param node node.call
function walkers.call(self, node)
	self:walk(node.func);
	self:suffix("(");
	self:walk_all(node.args, ",");
	self:suffix(")");
end
--- @param self stringify.ctx
--- @param node node.method
function walkers.method(self, node)
	self:walk(node.obj);
	self:emit(node, ":" .. node.name .. "(");
	self:walk_all(node.args, ",");
	self:suffix(")");
end
--- @param self stringify.ctx
--- @param node node.index
function walkers.index(self, node)
	self:walk(node.obj);
	self:suffix("[");
	self:walk(node.key);
	self:suffix("]");
end

--- @param self stringify.ctx
--- @param node node.decl
function walkers.decl(self, node)
	self:emit(node, "local ");
	for i = 1, #node.names do
		if i > 1 then self:suffix(",") end
		self:suffix(node.names[i].name);
	end

	if node.values then
		if node.pre then
			self:suffix(" ");
			for i = 1, #node.names do
				if i > 1 then self:suffix(",") end
				self:suffix(node.names[i].name);
			end
		end

		self:emit(node, "=");
		self:walk_all(node.values, ",");
	end
end
--- @param self stringify.ctx
--- @param node node.assign
function walkers.assign(self, node)
	self:walk_all(node.targets, ", ");
	self:emit(node, "=");
	self:walk_all(node.values, ", ");
end
--- @param self stringify.ctx
--- @param node node.if
walkers["if"] = function (self, node)
	for i = 1, #node.conds do
		local cond, body = node.conds[i], node.bodies[i];

		if i == 1 then
			self:emit(node, "if");
		else
			self:emit(node, "elseif");
		end

		self:walk(cond);

		self:suffix(" then");

		self:walk_all(body, ";");
	end

	if node.default then
		self:emit(node, "else");
		self:walk_all(node.default, ";");
	end
	self:suffix(" end");
end
--- @param self stringify.ctx
--- @param node node.while
walkers["while"] = function (self, node)
	self:emit(node, "while");
	self:walk(node.cond);
	self:suffix(" do");
	self:walk_all(node.body, ";");
	self:suffix(" end");
end
--- @param self stringify.ctx
--- @param node node.while
walkers["repeat"] = function (self, node)
	self:emit(node, "repeat");
	self:walk_all(node.body, ";");
	self:emit(node, "until");
	self:walk(node.cond);
end
--- @param self stringify.ctx
--- @param node node.for
walkers["for"] = function (self, node)
	self:emit(node, "for " .. node.name.name .. " =");
	self:walk_all({ node.first, node.last, node.step }, ",");
	self:suffix(" do");
	self:walk_all(node.body, ";");
	self:suffix(" end");
end
--- @param self stringify.ctx
--- @param node node.for_in
function walkers.for_in(self, node)
	self:emit(node, "for ");

	for i = 1, #node.names do
		if i > 1 then self:suffix(",") end
		self:suffix(node.names[i].name);
	end

	self:suffix(" in");
	self:walk_all(node.values, ",");
	self:suffix(" do");
	self:walk_all(node.body, ";");
	self:suffix(" end");
end
--- @param self stringify.ctx
--- @param node node.scope
function walkers.scope(self, node)
	self:emit(node, "do ");
	self:walk_all(node.body, ";");
	self:suffix(" end");
end

--- @param self stringify.ctx
--- @param node node.return
walkers["return"] = function (self, node)
	self:emit(node, "return");
	self:walk_all(node.vals, ",");
end
--- @param self stringify.ctx
--- @param node node.break
walkers["break"] = function (self, node)
	self:emit(node, "break");
end
--- @param self stringify.ctx
--- @param node node.goto
walkers["goto"] = function (self, node)
	self:emit(node, "goto");
	self:suffix(" " ..node.target.name)
end
--- @param self stringify.ctx
--- @param node node.label
function walkers.label(self, node)
	self:emit(node, "::" .. node.name .. "::");
end

return {
	--- @param node node
	one = function (node)
		--- @type stringify.ctx
		local self = ctx_meta.new();
		self:walk(node);
		return self.buff:tostring(), self.map;
	end,
	--- @param nodes node[]
	all = function (nodes)
		--- @type stringify.ctx
		local self = ctx_meta.new();
		self:walk_all(nodes);
		return self.buff:tostring(), self.map;
	end
};

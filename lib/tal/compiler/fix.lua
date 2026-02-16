local nodes = require "tal.compiler.node";
local syntax = require "tal.compiler.syntax";

--- @class fix.ctx
--- @field parts node.stm[]
--- @field id_base string
--- @field next_id integer
--- @field polyfills table<string, string> A table polyfill name -> polyfill
--- @field scope fix.scope

--- @class fix.scope
--- @field prev fix.scope?
--- @field names table<string, boolean>
--- @field consts table<string, boolean>

--- @type table<string, fun(self: fix.ctx, node: node): node>
local walkers = {};

local interop_funcs = {
	[nodes.ops.POW] = syntax.parse_exp("math.pow", true),

	[nodes.ops.B_NEG] = syntax.parse_exp("bit.bnot", true),
	[nodes.ops.IDIV] = syntax.parse_exp([[function (a, b)
		return math.floor(a / b);
	end]], true), -- TODO: to be done

	[nodes.ops.B_SHL] = syntax.parse_exp("bit.lshift", true),
	[nodes.ops.B_SHR] = syntax.parse_exp("bit.rshift", true),
	[nodes.ops.B_AND] = syntax.parse_exp("bit.band", true),
	[nodes.ops.B_OR] = syntax.parse_exp("bit.bor", true),
	[nodes.ops.B_XOR] = syntax.parse_exp("bit.bxor", true),
};
local polyfills = {
	getfenv = syntax.parse_exp("getfenv", true),
	setfenv = syntax.parse_exp("setfenv", true),
};

--- @param self fix.ctx
--- @param name string
--- @param node node.exp
local function polyfill(self, name, node)
	if self.polyfills[name] then
		return self.polyfills[name];
	end

	local id = self.id_base .. "_" .. self.next_id;
	self.next_id = self.next_id + 1;

	table.insert(self.parts, nodes.decl(nil, false, { id }, { node }));

	return id;
end

--- @generic T: node
--- @param self fix.ctx
--- @param node T
--- @return T
local function walk(self, node)
	--- @cast node node
	local res = walkers[node.type];
	if not res then error("node '" .. node.type .. "' not walkable", 2) end

	return res(self, node);
end

--- @param self fix.ctx
--- @param nodes node[]
--- @return node[]
local function walk_all(self, nodes)
	for i = 1, #nodes do
		nodes[i] = walk(self, nodes[i]);
	end

	return nodes;
end

--- @param self fix.ctx
--- @param names string[]
local function walk_var_decls(self, names, is_const)
	for i = 1, #names do
		self.scope.names[names[i]] = true;
		self.scope.consts[names[i]] = is_const or false;
	end
end

--- @param self fix.ctx
--- @param cb fun()
local function scope_with(self, cb)
	local old = self.scope;
	self.scope = { prev = old, consts = {}, names = {} };
	cb();
	self.scope = old;
end

--- @param self fix.ctx
local function scope_find(self, name)
	local curr = self.scope;

	while curr do
		if curr.names[name] then
			return true, curr.consts[name];
		end

		curr = curr.prev;
	end

	return false;
end

--- @param self fix.ctx
local function scope_tmp(self)
	local i = 0;
	repeat
		i = i + 1;
	until not scope_find(self, "_" .. i);

	return "_" .. i;
end

--- @param node node.var
function walkers.var(self, node)
	if scope_find(self, node.name) then return node end

	if node.name == "_ENV" then
		return nodes.call(node.loc, nodes.var(node.loc, polyfill(self, "getfenv", polyfills.getfenv)));
	end

	if scope_find(self, "_ENV") then
		return nodes.index(node.loc, nodes.var(node.loc, "_ENV"), nodes.str(node.loc, node.name));
	else
		return node;
	end
end
function walkers.str(self, node) return node end
function walkers.bool(self, node) return node end
function walkers.int(self, node) return node end
function walkers.fl(self, node) return node end
function walkers.args(self, node) return node end
walkers["nil"] = function (self, node) return node end
--- @param node node.paren
function walkers.paren(self, node)
	node.val = walk(self, node.val);
	return node;
end
--- @param node node.table
function walkers.table(self, node)
	walk_all(self, node.arr);
	walk_all(self, node.keys);
	walk_all(self, node.vals);

	return node;
end
--- @param node node.func
function walkers.func(self, node)
	scope_with(self, function ()
		walk_var_decls(self, node.args, false);
		walk_all(self, node.body);
	end);
	return node;
end
--- @param node node.op
function walkers.op(self, node)
	node.a = walk(self, node.a);
	node.b = node.b and walk(self, node.b);

	local func = interop_funcs[node.op];
	if not func then return node end

	local id = polyfill(self, "operator_" .. node.op, func);

	return nodes.call(nil, nodes.var(nil, id), node.a, node.b);
end

--- @param node node.call
function walkers.call(self, node)
	node.func = walk(self, node.func);
	walk_all(self, node);

	return node;
end
--- @param node node.method
function walkers.method(self, node)
	node.obj = walk(self, node.obj);
	walk_all(self, node);
	return node;
end
--- @param node node.index
function walkers.index(self, node)
	node.obj = walk(self, node.obj);
	node.key = walk(self, node.key);
	return node;
end

--- @param node node.decl
function walkers.decl(self, node)
	if node.values then
		if node.pre then
			walk_var_decls(self, node.names, false);
		end
		walk_all(self, node.values);
		if not node.pre then
			walk_var_decls(self, node.names, false);
		end
	end

	return node;
end
--- @param node node.assign
function walkers.assign(self, node)
	local globs = {};

	for i = 1, #node.targets do
		local t = node.targets[i];
		if t.type == "var" and t.name == "_ENV" then
			table.insert(globs, t);
		end
	end

	if #globs > 0 and not scope_find(self, "_ENV") then
		local tmp = scope_tmp(self);

		for i = 1, #globs do
			globs[i].name = tmp;
		end

		walk_all(self, node.targets);
		walk_all(self, node.values);

		return nodes.scope(node.loc, {
			nodes.decl(node.loc, false, { tmp });
			node,
			nodes.call(node.loc,
				nodes.var(node.loc, polyfill(self, "setfenv", polyfills.setfenv)),
				nodes.int(node.loc, 0),
				nodes.var(node.loc, tmp)
			),
		});
	else
		walk_all(self, node.targets);
		walk_all(self, node.values);

		return node;
	end

end
--- @param node node.if
walkers["if"] = function (self, node)
	walk_all(self, node.conds);
	for i = 1, #node.bodies do
		scope_with(self, function ()
			walk_all(self, node.bodies[i]);
		end);
	end

	if node.default then
		scope_with(self, function ()
			walk_all(self, node.default);
		end);
	end

	return node;
end
--- @param node node.while
walkers["while"] = function (self, node)
	node.cond = walk(self, node.cond);
	scope_with(self, function ()
		walk_all(self, node.body);
	end);
	return node;
end
--- @param node node.while
walkers["repeat"] = function (self, node)
	scope_with(self, function ()
		walk_all(self, node.body);
		node.cond = walk(self, node.cond);
	end);
	return node;
end
--- @param node node.for
walkers["for"] = function (self, node)
	node.first = walk(self, node.first);
	node.last = walk(self, node.last);
	node.step = node.step and walk(self, node.step);
	scope_with(self, function ()
		walk_var_decls(self, { node.name }, false);
		walk_all(self, node.body);
	end);

	return node;
end
--- @param node node.for_in
function walkers.for_in(self, node)
	scope_with(self, function ()
		walk_var_decls(self, node.names, false);
		walk_all(self, node.values);
		walk_all(self, node.body);
	end);
	return node;
end
--- @param node node.scope
function walkers.scope(self, node)
	scope_with(self, function ()
		walk_all(self, node.body);
	end);
	return node;
end

--- @param node node.return
walkers["return"] = function (self, node)
	walk_all(self, node);
	return node;
end
--- @param node node.break
walkers["break"] = function (self, node)
	return node;
end

--- @param nodes node.stm[]
--- @return node.stm[]
return function (nodes)
	--- @type fix.ctx
	local ctx = {
		id_base = "_" .. math.random(1, 0x1000000),
		next_id = 1,
		parts = {},
		polyfills = {},
		scope = { prev = nil, consts = {}, names = {} },
	};

	nodes = walk_all(ctx, nodes);

	table.move(nodes, 1, #nodes, #ctx.parts + 1);
	table.move(ctx.parts, 1, #ctx.parts, 1, nodes);

	return nodes;
end

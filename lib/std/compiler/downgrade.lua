local nodes = require "std.compiler.node";
local syntax = require "std.compiler.syntax";
local walk   = require "std.compiler.walk"

--- @class compiler.downgrade.ctx
--- @field parts node.stm[]
--- @field id_base string
--- @field next_id integer
--- @field polyfills table<string, node.name> A table polyfill name -> polyfill

--- @class compiler.downgrade.scope
--- @field prev compiler.downgrade.scope?
--- @field names table<string, node.name>
--- @field consts table<string, boolean>

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

--- @param self compiler.downgrade.ctx
--- @param name string
--- @param node node.exp
local function polyfill(self, name, node)
	if self.polyfills[name] then
		return self.polyfills[name];
	end

	local id = self.id_base .. "_" .. self.next_id;
	self.next_id = self.next_id + 1;
	local res_name = node.name(nil, id, false);

	table.insert(self.parts, nodes.decl(nil, false, { res_name }, { node }));
	self.polyfills[name] = res_name;

	return res_name;
end

--- @param self compiler.downgrade.scope
--- @param names node.name[]
local function walk_var_decls(self, names, is_const)
	for i = 1, #names do
		self.names[names[i].name] = names[i];
		self.consts[names[i].name] = is_const or false;
	end
end

--- @param self compiler.downgrade.scope
local function scope_child(self)
	return {
		consts = {},
		names = {},
		prev = self,
	} --[[@as compiler.downgrade.scope]];
end

--- @param self compiler.downgrade.scope
--- @param name string
local function scope_find(self, name)
	local curr = self;

	while curr do
		if curr.names[name] then
			return curr.names[name], curr.consts[name];
		end

		curr = curr.prev;
	end

	return nil;
end

--- @param self compiler.downgrade.scope
local function scope_tmp(self)
	local i = 0;
	repeat
		i = i + 1;
	until not scope_find(self, "_" .. i);

	--- @cast i integer

	return nodes.name(nil, "_" .. i, false);
end

local walker = walk(
	--- @param ctx compiler.downgrade.ctx
	--- @param scope compiler.downgrade.scope
	function (self, node, target, ctx, scope)
		if node.type == "var" then
			if node.name == "_ENV" then
				return nodes.call(node.loc,
					nodes.var(node.loc, polyfill(ctx, "getfenv", polyfills.getfenv)),
					nodes.int(node.loc, 1)
				);
			end

			local env_var = scope_find(scope, "_ENV");
			if env_var then
				return nodes.index(node.loc, nodes.var(node.loc, env_var), nodes.str(node.loc, node.name.name));
			end
		elseif node.type == "op" then
			local func = interop_funcs[node.op];
			if func then
				node.a = self:walk_exp(node.a, "multi", ctx, scope);
				node.b = node.b and self:walk_exp(node.b, "multi", ctx, scope);

				local id = polyfill(ctx, "operator_" .. node.op, func);
				return nodes.call(node.loc, nodes.var(node.loc, id), node.a, node.b);
			end
		end

		if node.type == "func" then
			local child = scope_child(scope);
			walk_var_decls(child, node.args, false);
			node.body = self:walk_body(node.body, ctx, child);
			return node;
		end
	end,
	--- @param ctx compiler.downgrade.ctx
	--- @param scope compiler.downgrade.scope
	function (self, node, ctx, scope)
		if node.type == "assign" then
			--- @type integer[]
			local globs = {};

			for i = 1, #node.targets do
				local t = node.targets[i];
				if t.type == "name" and t.name == "_ENV" and t.global then
					table.insert(globs, t);
				end
			end

			local env_var = scope_find(scope, "_ENV");
			if #globs > 0 and env_var then
				local tmp = scope_tmp(scope);

				for i = 1, #globs do
					node.targets[globs[i]] = tmp;
				end

				node.targets = self:walk_multiexp(node.targets, #node.targets, ctx, scope);
				node.values = self:walk_multiexp(node.values, #node.targets, ctx, scope);

				return {
					nodes.decl(node.loc, false, { tmp });
					node,
					nodes.call(node.loc,
						nodes.var(node.loc, polyfill(ctx, "setfenv", polyfills.setfenv)),
						nodes.int(node.loc, 0),
						nodes.var(node.loc, tmp)
					),
				};
			end
		end

		if node.type == "decl" then
			if node.pre then
				walk_var_decls(scope, node.names, false);
			end
			if node.values then
				node.values = self:walk_multiexp(node.values, #node.names, ctx, scope);
			end
			if node.pre then
				walk_var_decls(scope, node.names, false);
			end

			return node;
		elseif node.type == "if" then
			for i = 1, #node.bodies do
				node.conds[i] = self:walk_exp(node.conds[i], "bool", ctx, scope);
				node.bodies[i] = self:walk_body(node.bodies[i], ctx, scope_child(scope));
			end

			if node.default then
				node.default = self:walk_body(node.default, ctx, scope);
			end

			return node;
		elseif node.type == "while" then
			node.cond = self:walk_exp(node.cond, "bool", ctx, scope);
			node.body = self:walk_body(node.body, ctx, scope_child(scope));
			return node;
		elseif node.type == "repeat" then
			local child = scope_child(scope);
			node.body = self:walk_body(node.body, ctx, child);
			node.cond = self:walk_exp(node.cond, "bool", ctx, child);
			return node;
		elseif node.type == "for" then
			node.first = self:walk_exp(node.first, "multi", ctx, scope);
			if node.last then
				node.last = self:walk_exp(node.last, "multi", ctx, scope);
			end
			if node.step then
				node.step = self:walk_exp(node.step, "multi", ctx, scope);
			end
			local child = scope_child(scope);
			walk_var_decls(child, { node.name }, false);
			node.body = self:walk_body(node.body, ctx, child);
			return node;
		elseif node.type == "for_in" then
			local child = scope_child(scope);
			walk_var_decls(child, node.names, false);
			node.values = self:walk_multiexp(node.values, #node.names);
			node.body = self:walk_body(node.body, ctx, child);
			return node;
		elseif node.type == "scope" then
			node.body = self:walk_body(node.body, ctx, scope_child(scope));
			return node;
		end
	end
);


return {
	--- @param body node.stm[]
	walk_body = function (body)
		return walker:walk_body(body,
			{
				id_base = "_" .. math.random(1, 0x1000000),
				next_id = 1,
				parts = {},
				polyfills = {},
			} --[[@as compiler.downgrade.ctx]],
			{ prev = nil, consts = {}, names = {} } --[[@as compiler.downgrade.scope]]
		);
	end,
	--- @param exp node.exp
	--- @param target compiler.walk.target
	walk_exp = function (exp, target)
		return walker:walk_exp(exp, target,
			{
				id_base = "_" .. math.random(1, 0x1000000),
				next_id = 1,
				parts = {},
				polyfills = {},
			} --[[@as compiler.downgrade.ctx]],
			{ prev = nil, consts = {}, names = {} } --[[@as compiler.downgrade.scope]]
		);
	end
};

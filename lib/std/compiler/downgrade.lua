local errors = require "std.errors";
local nodes = require "std.compiler.node";
local syntax = require "std.compiler.syntax";
local walk = require "std.compiler.walk";

--- @class compiler.downgrade.continue
--- @field used boolean
--- @field label node.label

--- @class compiler.downgrade.scope
--- @field cont? compiler.downgrade.continue
--- @field prev compiler.downgrade.scope?
--- @field names table<string, node.name>
--- @field consts table<string, boolean>
--- @field labels table<string, node.label>

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
	local res_name = nodes.name(nil, id, false);

	table.insert(self.parts, nodes.decl(nil, false, { res_name }, { node }));
	self.polyfills[name] = res_name;

	return res_name;
end

--- @class compiler.downgrade.ctx
--- @field parts node.stm[]
--- @field id_base string
--- @field next_id integer
--- @field polyfills table<string, node.name> A table polyfill name -> polyfill
--- @field scope compiler.downgrade.scope
local ctx_meta = {};
ctx_meta.__index = ctx_meta;
ctx_meta.__metatable = "compiler.downgrade";

--- @param names node.name[]
function ctx_meta:walk_var_decls(names, is_const)
	for i = 1, #names do
		self.scope.names[names[i].name] = names[i];
		self.scope.consts[names[i].name] = is_const or false;
	end
end

--- @param name string
--- @return node.label?
function ctx_meta:label_find(name)
	return self.scope.labels[name];
end
function ctx_meta:label_tmp()
	local i = 0;
	repeat
		i = i + 1;
	until not self:label_find("_" .. i);

	--- @cast i integer

	local res = nodes.label(nil, "_" .. i);
	self.scope.labels[res.name] = res;
	return res;
end

--- @param name string
function ctx_meta:scope_find(name)
	local curr = self.scope;

	while curr do
		if curr.names[name] then
			return curr.names[name], curr.consts[name];
		end

		curr = curr.prev;
	end

	return nil;
end
function ctx_meta:scope_tmp()
	local i = 0;
	repeat
		i = i + 1;
	until not self:scope_find("_" .. i);

	--- @cast i integer

	local res = nodes.name(nil, "_" .. i, false);
	self.scope.names["_" .. i] = res;
	return res;
end

--- @param cont? boolean
--- @return compiler.downgrade.ctx
function ctx_meta:scope_child(cont)
	return setmetatable({
		scope = {
			labels = self.scope and self.scope.labels,
			cont = cont and {
				used = false,
				label = self:label_tmp(),
			} or (self.scope and self.scope.cont),
			consts = {},
			names = {},
			prev = self.scope,
		} --[[@as compiler.downgrade.scope]],
	}, { __index = self });
end

--- @return compiler.downgrade.ctx
function ctx_meta.new()
	return setmetatable({
		id_base = "_" .. math.random(1, 0x1000000),
		next_id = 1,
		parts = {},
		polyfills = {},
		scope = { prev = nil, consts = {}, names = {}, labels = {} },
	} --[[@as compiler.downgrade.ctx]], ctx_meta);
end



local err_meta = { __metatable = "downgrade.error" };

local walker = walk(
	--- @param ctx compiler.downgrade.ctx
	function (self, node, target, ctx)
		if node.type == "var" then
			if node.name.name == "_ENV" then
				return nodes.call(node.loc,
					nodes.var(node.loc, polyfill(ctx, "getfenv", polyfills.getfenv)),
					nodes.int(node.loc, 1)
				);
			end


			if node.name.global then
				local env_var = ctx:scope_find "_ENV";
				if env_var then
					return nodes.index(node.loc, nodes.var(node.loc, env_var), nodes.str(node.loc, node.name.name));
				end
			end

		elseif node.type == "op" then
			local func = interop_funcs[node.op];
			if func then
				node.a = self:walk_exp(node.a, "multi", ctx);
				node.b = node.b and self:walk_exp(node.b, "multi", ctx);

				local id = polyfill(ctx, "operator_" .. node.op, func);
				return nodes.call(node.loc, nodes.var(node.loc, id), { node.a, node.b });
			end
		end

		if node.type == "func" then
			local child = ctx:scope_child();
			child.scope.cont = nil;
			child.scope.labels = {};
			child:walk_var_decls(node.args, false);
			node.body = self:walk_body(node.body, child);
			return node;
		end
	end,
	--- @param ctx compiler.downgrade.ctx
	function (self, node, ctx)
		if node.type == "assign" then
			--- @type integer[]
			local globs = {};

			for i = 1, #node.targets do
				local t = node.targets[i];
				if t.type == "name" and t.name == "_ENV" and t.global then
					table.insert(globs, t);
				end
			end

			local env_var = ctx:scope_find "_ENV";
			if #globs > 0 and env_var then
				local tmp = ctx:scope_tmp();

				for i = 1, #globs do
					node.targets[globs[i]] = tmp;
				end

				node.targets = self:walk_multiexp(node.targets, #node.targets, ctx);
				node.values = self:walk_multiexp(node.values, #node.targets, ctx);

				return {
					nodes.decl(node.loc, false, { tmp });
					node,
					nodes.call(node.loc,
						nodes.var(node.loc, polyfill(ctx, "setfenv", polyfills.setfenv)),
						{ nodes.int(node.loc, 0), nodes.var(node.loc, tmp) }
					),
				};
			end
		elseif node.type == "decl" then
			if node.pre then
				ctx:walk_var_decls(node.names, false);
			end
			if node.values then
				node.values = self:walk_multiexp(node.values, #node.names, ctx);
			end
			if not node.pre then
				ctx:walk_var_decls(node.names, false);
			end

			return node;
		elseif node.type == "if" then
			for i = 1, #node.bodies do
				node.conds[i] = self:walk_exp(node.conds[i], "bool", ctx);
				node.bodies[i] = self:walk_body(node.bodies[i], ctx:scope_child());
			end

			if node.default then
				node.default = self:walk_body(node.default, ctx:scope_child());
			end

			return node;
		elseif node.type == "while" then
			node.cond = self:walk_exp(node.cond, "bool", ctx);
			local child = ctx:scope_child(true);
			node.body = self:walk_body(node.body, child);

			if child.scope.cont.used then
				table.insert(node.body, child.scope.cont.label);
			end

			return node;
		elseif node.type == "repeat" then
			local child = ctx:scope_child(true);
			node.body = self:walk_body(node.body, child);
			node.cond = self:walk_exp(node.cond, "bool", child);

			if child.scope.cont.used then
				table.insert(node.body, child.scope.cont.label);
			end

			return node;
		elseif node.type == "for" then
			node.first = self:walk_exp(node.first, "multi", ctx);
			if node.last then
				node.last = self:walk_exp(node.last, "multi", ctx);
			end
			if node.step then
				node.step = self:walk_exp(node.step, "multi", ctx);
			end
			local child = ctx:scope_child(true);
			child:walk_var_decls({ node.name }, false);
			node.body = self:walk_body(node.body, child);

			if child.scope.cont.used then
				table.insert(node.body, child.scope.cont.label);
			end

			return node;
		elseif node.type == "for_in" then
			local child = ctx:scope_child(true);
			child:walk_var_decls(node.names, false);
			node.values = self:walk_multiexp(node.values, #node.names, ctx);
			node.body = self:walk_body(node.body, child);

			if child.scope.cont.used then
				table.insert(node.body, child.scope.cont.label);
			end

			return node;
		elseif node.type == "scope" then
			node.body = self:walk_body(node.body, ctx:scope_child());
			return node;
		elseif node.type == "continue" then
			if not ctx.scope.cont then
				error(setmetatable({
					msg = "continue used outside a loop",
					loc = node.loc,
				}, err_meta));
			end

			ctx.scope.cont.used = true;
			return nodes._goto(node.loc, ctx.scope.cont.label);
		elseif node.type == "label" then
			ctx.scope.labels[node.name] = node;
		end
	end
);


return {
	--- @param body node.stm[]
	walk_body = function (body)
		local ctx = ctx_meta.new();
		local ok, res, trace = errors.spcall(walker.walk_body, walker, body, ctx);

		if ok then
			return table.move(res, 1, #res, #ctx.parts + 1, ctx.parts);
		elseif getmetatable(res) == "downgrade.error" then
			--- @cast res table
			return nil, res.msg, res.loc;
		else
			errors.srethrow(res, trace);
		end
	end,
	--- @param exp node.exp
	--- @param target compiler.walk.target
	walk_exp = function (exp, target)
		local ok, res, trace = errors.spcall(walker.walk_exp, walker, exp, target, ctx_meta.new());

		if ok then
			return res;
		elseif getmetatable(res) == "downgrade.error" then
			--- @cast res table
			return nil, res.msg, res.loc;
		else
			errors.srethrow(res, trace);
		end
	end
};

local ops = require "std.compiler.node".ops;

--- @alias compiler.walk.target "multi" | "single" | "bool"

--- @class compiler.walk.ctx<Ctx>
--- @field walk_exp fun(self, node: node.exp, target: compiler.walk.target, ctx): node.exp
--- @field walk_multiexp fun(self, nodes: node.exp[], target?: integer, ctx): node.exp[]
--- @field walk_body fun(self, node: node.stm[], ctx): node.stm[]

--- @generic Ctx
--- @param exp_cb? fun(self: compiler.walk.ctx, node: node.exp, target: compiler.walk.target, ctx: Ctx): node.exp | false?
--- @param stm_cb? fun(self: compiler.walk.ctx, node: node.stm, ctx: Ctx): node.stm | node.stm[] | false?
return function (exp_cb, stm_cb)
	--- @type table<string, fun(self, node: node.exp, target: compiler.walk.target, ctx): node.exp>
	local exp_walkers = {};
	--- @type table<string, fun(self, node: node.stm, ctx): node.stm>
	local stm_walkers = {};

	--- @param res node.stm[]
	--- @param curr node.stm | node.stm[]
	local function push_to_res(res, curr)
		if curr.type then
			table.insert(res, curr);
		else
			table.move(curr, 1, #curr, #res + 1, res);
		end

		return res;
	end

	--- @type compiler.walk.ctx
	local self = {
		walk_exp = function (self, node, target, ctx)
			if exp_cb then
				local res = exp_cb(self, node, target, ctx)
				if res then return res end
			end

			return exp_walkers[node.type](self, node, target, ctx);
		end,
		walk_body = function (self, body, ctx)
			local res = {};

			for i = 1, #body do
				local raw = body[i];
				local curr_res;

				if stm_walkers[raw.type] then
					if stm_cb then
						curr_res = stm_cb(self, raw, ctx);
					end

					if not curr_res then
						curr_res = stm_walkers[raw.type](self, raw, ctx);
					end
				else
					if exp_cb then
						curr_res = exp_cb(self, raw --[[@as node.exp]], "multi", ctx) --[[@as node.stm]];
					end

					if not curr_res then
						curr_res = exp_walkers[raw.type](self, raw --[[@as node.exp]], "multi", ctx) --[[@as node.stm]];
					end
				end

				push_to_res(res, curr_res);
			end

			return res;
		end,
		walk_multiexp = function (self, nodes, target, ctx)
			-- We can safely omit the parens on the last expression, if we overflow or match the required expressions
			local multi_safe = target and #nodes >= target;

			for i = 1, #nodes do
				if i == #nodes and not multi_safe then
					nodes[i] = self:walk_exp(nodes[i], "single", ctx);
				else
					nodes[i] = self:walk_exp(nodes[i], "multi", ctx);
				end
			end

			return nodes;
		end,
	};

	-- function exp_walkers.name(self, node, target)
	-- 	return node;
	-- end
	function exp_walkers.var(self, node, target)
		return node;
	end
	function exp_walkers.str(self, node, target)
		return node;
	end
	exp_walkers["nil"] = function (self, node, target)
		return node;
	end
	function exp_walkers.bool(self, node, target)
		return node;
	end
	function exp_walkers.int(self, node, target)
		return node;
	end
	function exp_walkers.fl(self, node, target)
		return node;
	end
	function exp_walkers.args(self, node, target)
		return node;
	end
	--- @param self compiler.walk.ctx
	--- @param node node.paren
	function exp_walkers.paren(self, node, target, ctx)
		node.val = self:walk_exp(node.val, "multi", ctx);
		return node;
	end
	--- @param self compiler.walk.ctx
	--- @param node node.table
	function exp_walkers.table(self, node, target, ctx)
		self:walk_multiexp(node.keys, #node.keys, ctx);
		self:walk_multiexp(node.vals, #node.vals, ctx);
		self:walk_multiexp(node.arr, nil, ctx);
		return node;
	end
	--- @param self compiler.walk.ctx
	--- @param node node.func
	function exp_walkers.func(self, node, target, ctx)
		node.body = self:walk_body(node.body, ctx);
		return node;
	end
	--- @param self compiler.walk.ctx
	--- @param node node.op
	function exp_walkers.op(self, node, target, ctx)
		if
			node.op == ops.NOT or
			node.op == ops.AND or
			node.op == ops.OR
		then
			node.a = self:walk_exp(node.a, "bool", ctx);
			if node.b then
				node.b = self:walk_exp(node.b, "bool", ctx);
			end

			return node;
		else
			node.a = self:walk_exp(node.a, "multi", ctx);
			if node.b then
				node.b = self:walk_exp(node.b, "multi", ctx);
			end

			return node;
		end
	end
	--- @param self compiler.walk.ctx
	--- @param node node.call
	function exp_walkers.call(self, node, target, ctx)
		self:walk_multiexp(node.args, nil, ctx);
		node.func = self:walk_exp(node.func, "multi", ctx);
		return node;
	end
	--- @param self compiler.walk.ctx
	--- @param node node.method
	function exp_walkers.method(self, node, target, ctx)
		self:walk_multiexp(node.args, nil, ctx);
		node.obj = self:walk_exp(node.obj, "multi", ctx);
		return node;
	end
	--- @param self compiler.walk.ctx
	--- @param node node.index
	function exp_walkers.index(self, node, target, ctx)
		node.obj = self:walk_exp(node.obj, "multi", ctx);
		node.key = self:walk_exp(node.key, "multi", ctx);
		return node;
	end

	--- @param self compiler.walk.ctx
	--- @param node node.decl
	function stm_walkers.decl(self, node, ctx)
		if node.values then
			self:walk_multiexp(node.values, #node.names, ctx);
		end

		return node;
	end
	--- @param self compiler.walk.ctx
	--- @param node node.assign
	function stm_walkers.assign(self, node, ctx)
		self:walk_multiexp(node.targets, #node.targets, ctx);
		self:walk_multiexp(node.values, #node.targets, ctx);

		return node;
	end
	--- @param self compiler.walk.ctx
	--- @param node node.if
	stm_walkers["if"] = function (self, node, ctx)
		for i = 1, #node.bodies do
			node.conds[i] = self:walk_exp(node.conds[i], "bool", ctx);
			node.bodies[i] = self:walk_body(node.bodies[i], ctx);
		end

		if node.default then
			node.default = self:walk_body(node.default, ctx);
		end

		return node;
	end
	--- @param self compiler.walk.ctx
	--- @param node node.while
	stm_walkers["while"] = function (self, node, ctx)
		node.cond = self:walk_exp(node.cond, "bool", ctx);
		node.body = self:walk_body(node.body, ctx);
		return node;
	end
	--- @param self compiler.walk.ctx
	--- @param node node.while
	stm_walkers["repeat"] = function (self, node, ctx)
		node.body = self:walk_body(node.body, ctx);
		node.cond = self:walk_exp(node.cond, "bool", ctx);
		return node;
	end
	--- @param self compiler.walk.ctx
	--- @param node node.for
	stm_walkers["for"] = function (self, node, ctx)
		node.first = self:walk_exp(node.first, "single", ctx);
		if node.last then
			node.last = self:walk_exp(node.last, "single", ctx);
		end
		if node.step then
			node.step = self:walk_exp(node.step, "single", ctx);
		end
		node.body = self:walk_body(node.body, ctx);
		return node;
	end
	--- @param self compiler.walk.ctx
	--- @param node node.for_in
	function stm_walkers.for_in(self, node, ctx)
		self:walk_multiexp(node.values, #node.names, ctx);
		node.body = self:walk_body(node.body, ctx);
		return node;
	end
	--- @param self compiler.walk.ctx
	--- @param node node.scope
	function stm_walkers.scope(self, node, ctx)
		node.body = self:walk_body(node.body, ctx);
		return node;
	end

	--- @param self compiler.walk.ctx
	--- @param node node.return
	stm_walkers["return"] = function (self, node, ctx)
		self:walk_multiexp(node.vals, nil, ctx);
		return node;
	end
	--- @param self compiler.walk.ctx
	--- @param node node.break
	stm_walkers["break"] = function (self, node) return node end
	--- @param self compiler.walk.ctx
	--- @param node node.break
	stm_walkers["continue"] = function (self, node) return node end

	stm_walkers["goto"] = function (self, node) return node end
	stm_walkers["label"] = function (self, node) return node end

	return self;
end

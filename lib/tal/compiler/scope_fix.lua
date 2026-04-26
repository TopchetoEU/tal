local walk = require "tal.compiler.walk";

--- @class compiler.scope_fix.scope
--- @field parent? compiler.scope_fix.scope
--- @field [integer] node.name

--- @type table <node.name, { i: integer, name: string }>
local rename_data = {};

local function resolve(scope, name)
	local curr = scope;

	while curr do
		for i = #curr, 1, -1 do
			if curr[i].name == name then
				return curr[i], scope;
			end
		end
		curr = curr.parent;
	end

	return nil;
end

local function bump_var(var)
	if rename_data[var] then
		rename_data[var].i = rename_data[var].i + 1;
		var.name = rename_data[var].name .. "_" .. rename_data[var].i;
	else
		rename_data[var] = { name = var.name, i = 1 }
		var.name = rename_data[var].name .. "_1";
	end
end

local function fix_var(scope, var)
	if var.global then
		while true do
			local res_var, res_scope = resolve(scope, var.name);
			if not res_var or not res_scope then break end

			bump_var(res_var);
			fix_var(res_scope, res_var);
		end
	else
		while true do
			local res_var, res_scope = resolve(scope, var.name);
			-- assert(res_var and res_scope, "local resolved to a global, bailing");
			if not res_var or not res_scope then
				print "local resolved to a global, bailing";
				return;
			end
			if res_var == var then break end

			bump_var(res_var);
			fix_var(res_scope, res_var);
		end
	end
end

return function ()
	return walk(
		--- @param scope compiler.scope_fix.scope
		function (self, node, target, scope)
			if node.type == "func" then
				local child_scope = { parent = scope, table.unpack(node.args) };
				node.body = self:walk_body(node.body, child_scope);
				return node;
			elseif node.type == "var" then
				fix_var(scope, node.name);
				return node;
			end
		end,
		--- @param scope compiler.scope_fix.scope
		function (self, node, scope)
			if node.type == "if" then
				for i = 1, #node.bodies do
					node.bodies[i] = self:walk_body(node.bodies[i], { parent = scope });
					node.conds[i] = self:walk_exp(node.conds[i], "bool", scope);
				end

				if node.default then
					node.default = self:walk_body(node.default, { parent = scope });
				end

				return node;
			elseif node.type == "while" then
				node.cond = self:walk_exp(node.cond, "bool", scope);
				node.body = self:walk_body(node.body, { parent = scope });
				return node;
			elseif node.type == "repeat" then
				local child_scope = { parent = scope };
				node.body = self:walk_body(node.body, child_scope);
				node.cond = self:walk_exp(node.cond, "bool", child_scope);
				return node;
			elseif node.type == "for" then
				node.first = self:walk_exp(node.first, "bool", scope);
				if node.last then
					node.last = self:walk_exp(node.last, "bool", scope);
				end
				if node.step then
					node.step = self:walk_exp(node.step, "bool", scope);
				end

				node.body = self:walk_body(node.body, { parent = scope, node.name });
				return node;
			elseif node.type == "for_in" then
				node.values = self:walk_multiexp(node.values, #node.names, scope);
				node.body = self:walk_body(node.body, { parent = scope, table.unpack(node.names) });
				return node;
			elseif node.type == "scope" then
				node.body = self:walk_body(node.body, { parent = scope });
				return node;
			elseif node.type == "decl" then
				if node.pre then
					table.move(node.names, 1, #node.names, #scope + 1, scope);
				end
				if node.values then
					node.values = self:walk_multiexp(node.values, #node.names, scope);
				end
				if not node.pre then
					table.move(node.names, 1, #node.names, #scope + 1, scope);
				end
				return node;
			end
		end
	);
end

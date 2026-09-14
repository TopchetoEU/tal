local syntax = require "std.compiler.syntax";
local downgrade = require "std.compiler.downgrade";
local stringify = require "std.compiler.stringify";
local mapping = require "std.basic.debug.mapping";
local aggr = require "std.err.aggr";
local err = require "std.err";
local comp_err = require "std.compiler.comp_err";
local traced = require "std.err.traced";

local load_raw = load;

--- @param chunk string | fun(): string
--- @param name? string
--- @param mode? loadmode
--- @param env? table
--- @param no_map? boolean
return function (chunk, name, mode, env, no_map, force_no_raw)
	env = env or getfenv(2);
	-- if not force_no_raw then return load_raw(chunk, name, mode, env, no_map) end

	if type(chunk) == "function" then
		local res = {};

		for el in chunk do
			table.insert(res, el);
		end

		chunk = table.concat(res);
	end

	if name == nil then name = chunk end
	if mode == "b" or mode == "bt" then
		local fun, err = load_raw(chunk, name, "b", env);
		if fun then
			return fun;
		elseif mode == "b" then
			return nil, err;
		end
	end

	local ok, func = traced.spcall(function ()
		local ast = syntax.parse(chunk, name, false);
		ast = downgrade.walk_body(ast);
		local str, map = stringify.all(ast);

		local func, e = load_raw(str, name, "t", env);
		if not func then err.throw(mapping.err_map(e --[[@as string]], map)) end

		if not no_map then
			mapping.emit_map(name, map);
		end

		return func;
	end);
	if not ok then
		local e = err.find(func, aggr);
		if e then return nil, e.children --[[@as std.compiler.err[] ]] end

		local e = err.find(func, comp_err);
		if e then return nil, e end

		err.throw(func);
	end

	return func;
end

local syntax = require "std.compiler.syntax";
local downgrade = require "std.compiler.downgrade";
local stringify = require "std.compiler.stringify";
local mapping   = require "std.debug.mapping"
local loading = {};

local load_raw = load;

--- @param chunk string | fun(): string
--- @param name? string
--- @param mode? loadmode
--- @param env? table
--- @param no_map? boolean
return function (chunk, name, mode, env, no_map, force_no_raw)
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
		local fun, err = load_raw(chunk, name, "b", env or getfenv(2));
		if fun then
			return fun;
		elseif mode == "b" then
			return nil, err;
		end
	end

	local ast, errs = syntax.parse(chunk);
	if #errs > 0 then
		local parts = {};
		for i = 1, #errs do
			table.insert(parts, mapping.err_stringify(name, errs[i].loc, errs[i].msg));
		end
		return nil, table.concat(parts, "\n");
	end

	local downgrade_res, err, loc = downgrade.walk_body(ast);
	if not downgrade_res then return nil, mapping.err_stringify(name, loc --[[@as node.loc]], err --[[@as string]]) end

	ast = downgrade_res;

	local str, map = stringify.all(ast);

	local fun, err = load_raw(str, name, "t", env or getfenv(2));
	if not fun then return nil, mapping.err_map(err --[[@as string]], map) end

	if not no_map then
		mapping.emit_map(name, map);
	end

	return fun;
end

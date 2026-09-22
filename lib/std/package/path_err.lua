--- @class std.err: errbox
--- @field children any[]
--- @field name string
--- @field kind string
local path_err = {};
path_err.__index = path_err;
path_err.__metatable = "std.package.path_err";

function path_err:errors()
	return self.children;
end
function path_err:__tostring()
	local res = {};
	local prefix = self.kind .. " '" .. self.name .. "' not found";

	for i = 1, #self.children do
		table.insert(res, tostring(self.children[i]));
	end

	if #res == 0 then
		return prefix;
	else
		return prefix .. ":\n\t" .. table.concat(res, "\n\t");
	end
end
--- @param name string
--- @param kind string
--- @param errs any[]
function path_err.new(name, kind, errs)
	return setmetatable({ name = name, kind = kind, children = errors.flatten(errs) }, path_err);
end

return path_err;

--- @diagnostic disable: duplicate-set-field
local lex;

--- @param self string
--- @param sep? string
--- @return string[]
function string:splitarr(sep)
	local res = {};

	for _, el in self:split(sep) do
		table.insert(res, el);
	end

	return res;
end
--- @param self string
--- @param sep? string
function string:split(sep)
	sep = sep or "";

	--- @param self string
	--- @param i? integer
	local function splitter(self, i)
		if not i or i > #self then return nil end

		local sep_f, sep_l = self:find(sep, i + 1);
		if not sep_f then
			return #self + 1, self:sub(i + 1);
		else
			return sep_l, self:sub(i + 1, sep_f - 1);
		end
	end
	return splitter, self, 0;
end
--- @param self string
function string:at(i)
	return self:sub(i, i);
end

--- @param self string
function string:quote()
	return (("%q"):format(self):gsub("\\\n", "\\n"));
end
--- @param self string
function string:unquote()
	lex = lex or require "std.compiler.lex";
	-- Although we use the parser, this *should* be safe, as we don't execute any code
	-- However, the solution and hand is really stupid
	-- TODO: figure out something less stupid
	local toks, err = lex.parse(self);
	if not toks then error(err) end
	if toks[1].type ~= "str" then return error "not a string" end
	return toks[1].val --[[@as string]];
end

--- Might not be safe...
--- @param self string
function string:quotesh()
	return "'" .. self:gsub("[*?~$&|;<>%(%)%[%]%{%}\\\'\"`%z\x01-\x1F]", "\\%1") .. "'";
end

string.__metatable = "string";

return string;

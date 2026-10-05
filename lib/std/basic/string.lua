--- @diagnostic disable: duplicate-set-field
local lex;

--- @param self string
--- @param sep? string
function string:split(sep)
	sep = sep or "";

	local i = 1;

	--- @param self string
	local function splitter(self)
		if i > #self then return nil end

		local sep_f, sep_l = self:find(sep, i);
		if sep_f and sep_l then
			local res = self:sub(i, sep_f - 1);
			if sep_l < sep_f then
				i = sep_f + 1;
			else
				i = sep_l + 1;
			end
			return res;
		else
			local res = self:sub(i);
			i = #self + 1;
			return res;
		end
	end
	return splitter, self;
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
	lex = lex or require_alt "std.compiler.lex";
	-- Although we use the parser, this *should* be safe, as we don't execute any code
	-- However, the solution and hand is really stupid
	-- TODO: figure out something less stupid
	local toks, e = lex.parse(self);
	if not toks then error(e) end
	if #toks ~= 1 then return error "too many tokens" end
	if toks[1].type ~= "str" then return error "not a string literal" end
	return toks[1].val --[[@as string]];
end

--- Might not be safe...
--- @param self string
function string:quotesh()
	return "'" .. self:gsub("[*?~$&|;<>%(%)%[%]%{%}\\\'\"`%z\x01-\x1F]", "\\%1") .. "'";
end

string.__metatable = "string";

return string;

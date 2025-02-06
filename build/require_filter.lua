local lexer = require "lexer";

---@param tokens fun(): token?, string?
---@param mapper fun(name: string, base: tok_base): token?
---@return fun(): token?, string?
return function (tokens, mapper)
	local last_req = false;

	return function ()
		local tok, err = tokens();

		if tok == nil then
			return tok, err;
		elseif last_req then
			if tok.type == lexer.TOK_STR then
				last_req = false;
				--- @diagnostic disable-next-line: param-type-mismatch
				return mapper(tok.val, tok);
			elseif tok.type ~= lexer.TOK_KW or tok.val ~= lexer.K_PAREN_OPEN then
				last_req = false;
			end
		elseif tok.type == lexer.TOK_ID and tok.val == "require" then
			last_req = true;
		end

		return tok;
	end
end


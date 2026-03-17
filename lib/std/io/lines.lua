-- Deceptively named, but in short, imitates lua's file*:read function, given either a seek-able stream or a chunk-wise stream with buffering

local lines = {};

--- @param self std.io.stream_backend
--- @param fmt? integer | "l" | "L" | "a" | "c"
function lines.seekable(self, fmt)
	fmt = fmt or "l";
	if type(fmt) == "number" then
		local res = {};
		local len = 0;

		while len < fmt do
			local curr, err = self:read(fmt - len);
			if err then return nil, err end
			if not curr or curr == "" then break end

			len = len + #curr;

			if len > fmt then
				table.insert(res, curr:sub(1, len - fmt));
				local _, err = self:seek(-(len - fmt), "cur");
				if err then return nil, err end
				break;
			else
				table.insert(res, curr);
			end
		end

		if #res == 0 then return nil end
		return table.concat(res);
	elseif fmt == "l" or fmt == "L" then
		local res = {};

		while true do
			local curr, err = self:read();
			if err then return nil, err end
			if not curr or curr == "" then break end

			local nl_i = curr:find "\n";
			if nl_i then
				if fmt == "l" then
					table.insert(res, curr:sub(1, nl_i - 1));
				else
					table.insert(res, curr:sub(1, nl_i));
				end

				local _, err = self:seek(nl_i - #curr, "cur");
				if err then return nil, err end

				break;
			else
				table.insert(res, curr);
			end
		end

		if #res == 0 then return nil end
		return table.concat(res);
	elseif fmt == "a" then
		local f, err = self:seek(0, "cur");
		if not f then return nil, err end

		local l, err = self:seek(0, "end");
		if err then
			self:seek(f, "set");
			return nil, err;
		end

		local _, err = self:seek(f, "set");
		if err then return nil, err end

		return self:read(l - f);
	elseif fmt == "c" then
		local res, err = self:read();
		if err then return nil, err end
		if res == "" then return nil end
		return res;
	else
		error("invalid :read format", 2);
	end
end
--- @param self std.io.stream_backend
--- @param buff string[]
--- @param fmt? integer | "l" | "L" | "a" | "c"
function lines.chunked(self, buff, fmt)
	fmt = fmt or "l";
	if type(fmt) == "number" then
		local res = {};
		local len = 0;

		while len < fmt do
			local curr = table.remove(buff, 1);
			if not curr then
				local err;
				curr, err = self:read(fmt - len);
				if err then return nil, err end
				if not curr or curr == "" then break end
			end

			len = len + #curr;

			if len > fmt then
				local cutoff_i = fmt - len;
				table.insert(res, curr:sub(1, cutoff_i - 1));
				table.insert(buff, curr:sub(cutoff_i));
				break;
			else
				table.insert(res, curr);
			end
		end

		if #res == 0 then return nil end
		return table.concat(res);
	elseif fmt == "l" or fmt == "L" then
		local res = {};

		while true do
			local curr = table.remove(buff, 1);
			if not curr then
				local err;
				curr, err = self:read();
				if err then return nil, err end
				if not curr or curr == "" then break end
			end

			local nl_i = curr:find "\n";
			if nl_i then
				if fmt == "l" then
					table.insert(res, curr:sub(1, nl_i - 1));
				else
					table.insert(res, curr:sub(1, nl_i));
				end

				table.insert(buff, curr:sub(nl_i + 1));
				break;
			else
				table.insert(res, curr);
			end
		end

		if #res == 0 then return nil end
		return table.concat(res);
	elseif fmt == "a" then
		local res = {};

		table.move(buff, 1, #buff, 1, res);

		while true do
			local curr, err = self:read();
			if err then return nil, err end
			if not curr or curr == "" then break end

			table.insert(res, curr);
		end

		return table.concat(res);
	elseif fmt == "c" then
		local curr = table.remove(buff, 1);
		if curr then return curr end

		local res, err = self:read();
		if err then return nil, err end
		if not res or res == "" then return nil end
		return res;
	else
		error("invalid :read format", 2);
	end
end

return lines;

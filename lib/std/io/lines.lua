-- Deceptively named, but in short, imitates lua's file*:read function, given either a seek-able stream or a chunk-wise stream with buffering

local lines = {};

--- @param read fun(self, n: integer): string?, string?
--- @param seek fun(self, offset: integer, whence: "set" | "cur" | "end"): integer?, string?
--- @param fmt integer | "l" | "L" | "a"
--- @param chunk? integer
function lines.seekable(self, read, seek, fmt, chunk)
	if type(fmt) == "number" then
		return read(self, fmt);
	elseif fmt == "l" or fmt == "L" then
		local res = {};

		while true do
			local curr, err = read(self, chunk or 1024);
			if not curr then return nil, err end
			if #curr == "" then break end

			local nl_i = curr:find "\n";
			if nl_i then
				if fmt == "l" then
					table.insert(res, curr:sub(1, nl_i - 1));
				else
					table.insert(res, curr:sub(1, nl_i));
				end

				local ok, err = seek(self, nl_i - #curr, "cur");
				if not ok then return nil, err end

				break;
			else
				table.insert(res, curr);
			end
		end

		return table.concat(res);

	elseif fmt == "a" then
		local f, err = seek(self, 0, "cur");
		if not f then return nil, err end

		local l, err = seek(self, 0, "end");
		if not l then
			seek(self, f, "set");
			return nil, err;
		end

		local _, err = seek(self, f, "set");
		if not _ then return nil, err end

		return read(self, l - f);
	else
		error("invalid :read format", 2);
	end
end
--- @param read fun(self, n: integer): string?, string?
--- @param buff string[]
--- @param fmt integer | "l" | "L" | "a"
--- @param chunk? integer
function lines.chunked(self, read, buff, fmt, chunk)
	if type(fmt) == "number" then
		local res = {};
		local len = 0;

		while len < fmt do
			local curr = table.remove(buff, 1);
			if not curr then
				local err;
				curr, err = read(self, chunk or 1024);
				if not curr then return nil, err end

				if curr == "" then break end
			end

			if len + #curr > fmt then
				table.insert(res, curr:sub(1, (len + #curr) - fmt));
			else
				table.insert(res, curr);
				table.remove(buff, 1);
			end
		end

		return read(self, fmt);
	elseif fmt == "l" or fmt == "L" then
		local res = {};

		while true do
			local curr = table.remove(buff, 1);
			if not curr then
				local err;
				curr, err = read(self, chunk or 1024);
				if not curr then return nil, err end

				if curr == "" then break end
			end

			local nl_i = curr:find "\n";
			if nl_i then
				if fmt == "l" then
					table.insert(res, curr:sub(1, nl_i - 1));
				else
					table.insert(res, curr:sub(1, nl_i));
				end

				table.insert(buff, curr:sub(nl_i + 1));
				return table.concat(res);
			else
				table.insert(res, curr);
			end
		end
	elseif fmt == "a" then
		local res = {};

		table.move(buff, 1, #buff, 1, res);

		while true do
			local curr, err = read(self, chunk or 1024);
			if not curr then return nil, err end
			if curr == "" then break end

			table.insert(res, curr);
		end

		return table.concat(res);
	else
		error("invalid :read format", 2);
	end
end

return lines;

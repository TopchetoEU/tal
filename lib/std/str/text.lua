local buffer = require "string.buffer";
local sig    = require "std.sig"
local ffi    = require "nat.ffi"

--- @class std.strtxt
--- @field str std.str
local strtxt = {};
strtxt.__index = strtxt;
strtxt.__metatable = "std.strtxt";

function strtxt:read(mode)
	if mode == "l" or mode == "L" then
		local buff = buffer.new(1024);
		while true do
			local ptr, n = buff:reserve(1024);
			local n, has_char = self.str:readline(ptr, n, 0x0A --[['\n']]);

			if n == 0 then break end
			if has_char then
				if mode == "l" then
					buff:commit(n - 1);
				else
					buff:commit(n);
				end

				break;
			end

			buff:commit(n);
		end

		if #buff == 0 then return nil end
		return buff:tostring();
	elseif mode == "a" then
		local buff = buffer.new(1024);
		while true do
			local n = self.str:read(buff:reserve(1024));
			if n == 0 then break end

			buff:commit(n);
		end

		if #buff == 0 then return nil end
		return buff:tostring();
	elseif mode == "c" then
		local buff = buffer.new();
		buff:commit(self.str:read(buff:reserve(1024)));

		if #buff == 0 then return nil end
		return buff:tostring();
	elseif type(mode) == "number" then
		local buff = buffer.new();
		buff:commit(self.str:read(buff:reserve(mode), mode));

		if #buff == 0 then return nil end
		return buff:tostring();
	else
		sig.error("mode", "must be an integer, 'l', 'L', 'c' or 'a'");
	end
end
function strtxt:write(...)
	for i = 1, select("#", ...) do
		-- TODO: OPTIMIZE!!!!
		local str = tostring((select(i, ...)));
		local buff = ffi.new("char[?]", #str);
		ffi.copy(buff, str, #str);
		self.str:fullwrite(buff, #str)
	end
end
function strtxt:flush()
	self.str:flush();
	return self;
end

--- @param fmt std.io.readmode
--- @param close? boolean = false
--- @return fun(): string?
function strtxt:lines(fmt, close)
	if close then
		return function ()
			local res = self:read(fmt);
			if not res then self:close() end
			return res;
		end
	else
		return function ()
			return self:read(fmt);
		end
	end
end
--- @param dst std.strtxt
--- @param close? boolean = false
--- @param close_dst? boolean = close
function strtxt:pipe(dst, close, close_dst)
	if close_dst == nil then close_dst = close end

	self.str:pipe(dst.str);

	if close then self:close() end
	if close_dst then dst:close() end

	return self;
end
--- @param mode vbuf
--- @param size? integer
function strtxt:setvbuff(mode, size)
	if mode == "no" then
		self.str:setwbuff();
	elseif mode == "full" then
		self.str:setwbuff(nil, size);
	elseif mode == "line" then
		self.str:setwbuff(nil, size, 0x0A);
	else
		sig.error("mode", "expected 'no', 'line' or 'full'");
	end
end

--- @param whence? seekwhence
--- @param pos? integer
--- @return integer
function strtxt:seek(whence, pos)
	return self.str:seek(whence, pos);
end
function strtxt:stat()
	return self.str:stat();
end
--- @param ... string | integer
function strtxt:chmod(...)
	self.str:chmod(...);
	return self;
end
--- @param uid integer
--- @param gid integer
function strtxt:chown(uid, gid)
	self.str:chown(uid, gid);
	return self;
end

function strtxt:close()
	self.str:close();
	return self;
end

--- @param str std.str
function strtxt.new(str)
	return setmetatable({ str = str }, strtxt);
end

return strtxt;

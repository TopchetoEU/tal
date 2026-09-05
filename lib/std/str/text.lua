local buffer = require "string.buffer";
local sig = require "std.sig";
local ffi = require "nat.ffi";
local str = require "std.str";

--- @class std.strtxt
--- @field str std.str
local strtxt = {};
strtxt.__index = strtxt;
strtxt.__metatable = "std.strtxt";

function strtxt:read(mode)
	if type(mode) == "string" and (mode:sub(1, 1) == "l" or mode:sub(1, 1) == "L") then
		local res = self.str:readlineto(buffer.new(), mode:sub(2):byte());
		if #res == 0 then return nil end
		if mode:sub(1, 1) == "l" then
			return res:get(#res - 1);
		else
			return res:get();
		end
	elseif mode == "a" then
		return self.str:readto(buffer.new()):get();
	elseif mode == "c" then
		local res = self.str:readto(buffer.new(), str.chunksize);
		if #res == 0 then return nil end
		return res:get();
	elseif type(mode) == "number" then
		local buff = buffer.new();
		buff:commit(self.str:fullread(buff:reserve(mode), mode));

		if #buff == 0 then return nil end
		return buff:get();
	else
		sig.error("mode", "must be an integer, 'l[char]', 'L[char]', 'c' or 'a'");
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

--- @param fmt? std.io.readmode
--- @param close? boolean = false
--- @return fun(): string?
function strtxt:lines(fmt, close)
	if close then
		return function ()
			local res = self:read(fmt or "l");
			if not res then self:close() end
			return res;
		end
	else
		return function ()
			return self:read(fmt or "l");
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

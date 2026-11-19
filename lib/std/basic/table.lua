local tag = require "std.tag"
--- @diagnostic disable: duplicate-set-field

--- @alias array<T> T[] | tablelib

--- @class tablelib
local tablelib = table;
tablelib.__index = tablelib;
tablelib.__metatable = "table";

tablelib.clear = require "table.clear";
tablelib.new = require "table.new";
tablelib.unpack = unpack or tablelib.unpack;

function tablelib.pack(...)
	return { n = select("#", ...), ... };
end

--- @param self string | table
--- @param i? integer
function tablelib.absindex(self, i)
	if i < 0 then i = #self + i + 1 end
	return i;
end
--- @param self table
--- @param val any
--- @param maxn? integer
--- @param rev? boolean
function tablelib.delete(self, val, maxn, rev)
	maxn = tablelib.absindex(self, maxn or 1);
	local n = 0;

	if rev then
		local i = #maxn;
		while n < maxn and i > 0 do
			if self[i] == val then
				table.remove(self, i);
				n = n + 1;
			end

			i = i - 1;
		end
	else
		local i = 1;
		while n < maxn and i <= #self do
			if self[i] == val then
				table.remove(self, i);
				n = n + 1;
			else
				i = i + 1;
			end
		end
	end

	return n;
end
--- @param self table
--- @param other table
--- @param maxn? integer
--- @param rev? boolean
function tablelib.deleteall(self, other, maxn, rev)
	local n = 0;

	for i = 1, #other do
		n = n + table.delete(self, other[i], tablelib.absindex(self, maxn or 1), rev);
	end

	return n;
end
--- @param self table
--- @param other table
function tablelib.insertall(self, other)
	table.move(other, 1, #other, #self + 1, self);
end
--- @param self table
--- @param val any
--- @param rev? boolean
--- @param first? integer
--- @param last? integer
function tablelib.find(self, val, rev, first, last)
	first = table.absindex(self, first or 1);
	last = table.absindex(self, last or -1);

	if rev then
		for i = last or #self, first or 1, -1 do
			if self[i] == val then return i end
		end
	else
		for i = first or 1, last or #self do
			if self[i] == val then return i end
		end
	end

	return nil;
end
--- ALternative to table.from, which puts the second element of `iter` to the table
--- Useful for iterators with a state variable (example is `ipairs` although doing `table.ifrom(ipairs {1, 2, 3})` is kinda useless)
--- @generic T
--- @param iter fun(self, i): T?
--- @param self? any
--- @param init? any
--- @return T[]
function tablelib.ifrom(iter, self, init)
	local res = {};

	for _, el in iter, self, init do
		table.insert(res, el);
	end

	return res;
end
--- @generic T
--- @param iter fun(self, i): T?
--- @param self? any
--- @param init? any
--- @return T[]
function tablelib.from(iter, self, init)
	local res = {};

	for el in iter, self, init do
		table.insert(res, el);
	end

	return res;
end

--- @generic T
--- @param val T[]
--- @return array<T>
function tablelib.mk(val)
	return setmetatable(val, tablelib)
end

tablelib.locktag = tag.new "std.table.lock";

--- @generic T: table
--- @param self T
--- @return T
function tablelib.lock(self)
	if tablelib.islocked(self) then return self end
	local meta = debug.getmetatable(self) or {};
	return setmetatable({}, {
		[tablelib.locktag] = true,
		__metatable = getmetatable(self) or false,
		__index = self,
		__newindex = function (t, k, v) error "table locked" end,
		__pairs = function () return pairs(self) end,
		__ipairs = function () return ipairs(self) end,
		__len = function () return #self end,
		__add = meta.__add and function (_, b) return self + b end,
		__sub = meta.__sub and function (_, b) return self - b end,
		__mul = meta.__mul and function (_, b) return self * b end,
		__div = meta.__div and function (_, b) return self / b end,
		__mod = meta.__mod and function (_, b) return self % b end,
		__concat = meta.__concat and function (_, b) return self .. b end,
		__call = meta.__call and function (_, ...) return self(...) end,
		__eq = meta.__eq and function (_, b) return self == b end,
		__le = meta.__le and function (_, b) return self <= b end,
		__lt = meta.__lt and function (_, b) return self < b end,
		__tostring = meta.__tostring and function () return tostring(self) end,
		__unm = meta.__unm and function (_) return -self end,
	})
end
function tablelib.islocked(self)
	local meta = debug.getmetatable(self);
	return meta and meta[tablelib.locktag] ~= nil;
end

return tablelib;

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

--- @param i? integer
--- @param def integer
function tablelib.absindex(self, i, def)
	if not i then i = def end
	if i < 0 then i = #self + i end
	return i;
end
--- @param self table
--- @param val any
--- @param maxn? integer
--- @param rev? boolean
function tablelib.delete(self, val, maxn, rev)
	maxn = tablelib.absindex(self, maxn, 1);
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
		n = n + table.delete(self, other[i], tablelib.absindex(self, maxn, 1), rev);
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
	first = table.absindex(self, first, 1);
	last = table.absindex(self, last, -1);

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

--- @generic T
--- @param val T[]
--- @return array<T>
function tablelib.mk(val)
	return setmetatable(val, tablelib)
end

return tablelib;

return function (glob)
	--- @diagnostic disable: duplicate-set-field

	--- @class arraylib
	local arrays = {};
	arrays.__index = arrays;

	local function array(obj)
		if type(obj) == "string" then
			return obj:split "";
		else
			return arrays.mk(obj);
		end
	end
	--- LuaLS is a piece of shit
	--- @generic T
	--- @param type `T`
	--- @return fun(obj: T[]): array<T>
	local function arrof(type)
		return array;
	end

	--- Creates an array
	function arrays.mk(obj)
		return setmetatable(obj, arrays);
	end

	function arrays.concat(...)
		--- @diagnostic disable-next-line: missing-fields
		return arrays.append(array {}, ...);
	end

	function arrays:append(...)
		local res = self;
		local n = #res + 1;

		for i = 1, select("#", ...) do
			local curr = select(i, ...);
			for j = 1, #curr do
				res[n] = curr[j];
				n = n + 1;
			end
		end

		return res;
	end

	function arrays:push(...)
		return self:append { ... };
	end
	function arrays:pop()
		local res = self[#self];
		self[#self] = nil;
		return res;
	end
	function arrays:peek()
		return self[#self];
	end

	function arrays:shift()
		return table.remove(self, 1);
	end
	function arrays:unshift(...)
		local len = select("#", ...);
		table.move(self, 1, #self, len + 1, self);
		for i = 1, len do
			self[i] = select(i, ...);
		end
	end

	function arrays:map(f, mutate)
		local out;

		if mutate then
			out = self;
		else
			out = array {};
		end

		for i = 1, #self do
			out[i] = f(self[i], i, self);
		end

		return out;
	end
	function arrays:flat_map(f)
		local out = array {};

		for i = 1, #self do
			out:append(f(self[i], i, self));
		end

		return out;
	end
	function arrays:each(f)
		for i = 1, #self do
			f(self[i], i, self);
		end
	end
	function arrays:sort(f, copy)
		local target = self;
		if copy then
			target = array {}:append(self);
		end

		table.sort(target, f);
		return target;
	end

	function arrays:find_i(f)
		for i = 1, #self do
			if f(self[i], i, self) then
				return i;
			end
		end

		return nil;
	end


	function arrays:fill(val, b, e)
		if b == nil then b = 1 end
		if e == nil then e = self end
		if b < 0 then b = #self + 1 - b end
		if e < 0 then e = #self + 1 - e end

		for i = b, e do
			self[i] = val;
		end

		return self;
	end

	function arrays:splice(b, e, ...)
		-- TODO: optimize
		if select("#") > 0 then
			local n = e - b + 1;

			while n > 0 do
				table.remove(self, b);
				n = n - 1;
			end

			for i = 1, select("#") do
				table.insert(self, b, (select(i, ...)));
			end

			return self;
		else
			local res = {};

			for i = b, e do
				table.insert(res, self[i]);
			end

			return res;
		end
	end

	function arrays:slice(b, e)
		b = b or 1;
		e = e or #self;
		local res = array {};

		for i = b, e do
			res:push(self[i]);
		end

		return res;
	end

	function arrays:join(sep, b, e)
		return table.concat(self, sep, b, e);
	end

	function arrays:__concat(other)
		return arrays.concat(self, other);
	end

	glob.arrays = arrays;
	glob.array = array;
	glob.arrof = arrof;
end

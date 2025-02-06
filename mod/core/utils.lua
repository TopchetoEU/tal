return function (glob)
	function glob.box(...)
		return { n = select("#", ...), ... };
	end
	function glob.unbox(obj, s, e)
		return unpack(obj, s or 1, e or obj.n);
	end
	function glob.rebox(obj, s, e)
		return box(unpack(obj, s or 1, e or obj.n));
	end

	function glob.exit()
		os.exit(0);
	end

	function glob.str(...)
		return table.concat { ... };
	end

	function glob.iterate(obj)
		local i = 0;

		return function()
			i = i + 1;
			return obj[i];
		end
	end

	--- Prepares the object to be a class - puts an __index member in it pointing to the object itself
	--- @generic T
	--- @param obj T
	--- @return T | { __index: T }
	function glob.class(obj)
		--- @diagnostic disable-next-line: inject-field
		obj.__index = obj;
		return obj;
	end

	function glob.try(try_fn, catch_fn, finally_fn)
		if not try_fn then
			if finally_fn then
				return finally_fn();
			end
		else
			local function handle_catch(...)
				if finally_fn then
					finally_fn();
				end

				return ...;
			end

			local function handle_try(ok, ...)
				if ok then
					if finally_fn then
						finally_fn();
					end

					return ...;
				else
					if catch_fn then
						return handle_catch(catch_fn(...));
					elseif finally_fn then
						return finally_fn();
					end
				end
			end

			return handle_try(pcall(try_fn));
		end
	end
end

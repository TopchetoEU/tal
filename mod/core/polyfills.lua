return function (glob)
	if glob.getfenv then
		glob._ENV = glob.getfenv();
		glob._G = _ENV;
	else
		glob._G = _ENV;

		if debug.getupvalue then
			local getupvalue = debug.getupvalue;
			function glob.getfenv(func)
				return getupvalue(func, 1);
			end
		else
			function glob.getfenv()
				error("getfenv is not supported", 2);
			end
		end
	end

	if not glob.setfenv then
		if glob.debug.setupvalue then
			local setupvalue = glob.debug.setupvalue;

			if glob.debug.getinfo then
				local getinfo = glob.debug.getinfo;

				function glob.setfenv(func, val)
					setupvalue(func, 1, val);
					if type(func) == "function" then
						return func;
					else
						return getinfo(func, "f");
					end
				end
			else
				function glob.setfenv(func, val)
					setupvalue(func, 1, val);
					return func;
				end
			end
		else
			function glob.setfenv()
				error("setfenv is not supported", 2);
			end
		end
	end

	-- Reimplement this for lua <5.1
	if glob.table.move == nil then
		--- @diagnostic disable: duplicate-set-field
		function glob.table.move(src, src_b, src_e, dst_b, dst)
			if dst == nil then dst = src end
			local offset = dst_b - src_b;

			if dst_b < src_b then
				for i = src_e, src_b, -1 do
					dst[i + offset] = src[i];
				end
			else
				for i = src_b, src_e do
					dst[i + offset] = src[i];
				end
			end

			return dst;
		end
	end

	-- Why did we *remove* this from the spec again? Classical PUC
	glob.unpack = table.unpack or unpack;
	glob.table.unpack = unpack;
end

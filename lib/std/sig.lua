local sig = {};

--- @param i integer | string
--- @param msg string
--- @return ...
function sig.error(i, msg)
	local res = "bad argument ";
	if type(i) == "string" then
		res = res .. "'" .. i .. "'";
	else
		res = res .. "#" .. i;
	end

	local name = debug.getinfo(2, "n");
	if name then
		res = res .. " to " .. name;
	end

	if msg then
		res = res .. "(" .. msg .. ")";
	end

	return error(msg, 2);
end

--- @param i integer | string
--- @param typename string
--- @return ...
function sig.error_type(val, i, typename)
	return sig.error(i, typename .. "expected, got " .. type(val));
end

--- @param i integer | string
--- @return boolean
function sig.bool(val, i)
	if type(val) ~= "boolean" then return sig.error_type(val, i, "boolean") end
	return val;
end
--- @generic T
--- @param i integer | string
--- @param def? T
--- @return boolean | T
function sig.optbool(val, i, def)
	if val == nil then return def end
	if type(val) ~= "boolean" then return sig.error_type(val, i, "boolean") end
	return val;
end

--- @param i integer | string
--- @return number
function sig.num(val, i)
	if type(val) ~= "number" then return sig.error_type(val, i, "number") end
	return val;
end
--- @generic T
--- @param i integer | string
--- @param def? T
--- @return number | T
function sig.optnum(val, i, def)
	if val == nil then return def end
	if type(val) ~= "number" then return sig.error_type(val, i, "number") end
	return val;
end

--- @param i integer | string
--- @return string
function sig.str(val, i)
	if type(val) ~= "string" then return sig.error_type(val, i, "string") end
	return val;
end
--- @generic T
--- @param i integer | string
--- @param def? T
--- @return string
function sig.optstr(val, i, def)
	if val == nil then return def end
	if type(val) ~= "string" then return sig.error_type(val, i, "string") end
	return val;
end

--- @param i integer | string
--- @return table
function sig.tab(val, i)
	if type(val) ~= "table" then return sig.error_type(val, i, "table") end
	return val;
end
--- @generic T
--- @param i integer | string
--- @param def? T
--- @return table
function sig.opttab(val, i, def)
	if val == nil then return def end
	if type(val) ~= "table" then return sig.error_type(val, i, "table") end
	return val;
end

return sig;

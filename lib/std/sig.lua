local sig = {};

--- @class std.sig.err: err
--- @field fname string
--- @field arg string | integer
--- @field msg string
sig.err = setmetatable({}, err);
sig.__index = sig.err;
sig.__metatable = "std.sig.err";

function sig.err:__tostring()
	local res = "bad argument ";
	if type(self.arg) == "string" then
		res = res .. "'" .. self.arg .. "'";
	else
		res = res .. "#" .. self.arg;
	end

	if self.fname then
		res = res .. " to " .. self.fname;
	end

	if self.msg then
		res = res .. " (" .. self.msg .. ")";
	end

	return res;
end

--- @param i integer | string
--- @param msg string
--- @param level? integer
function sig.err:new(i, msg, level)
	local info = debug.getinfo((level or 1) + 1, "n");
	return setmetatable({ arg = i, msg = msg, fname = info and info.name }, sig.err);
end

sig.parent = err.badarg;

--- @param i integer | string
--- @param msg string
--- @param level? integer
--- @return ...
function sig.error(i, msg, level)
	return error(sig.err:new(i, msg, (level or 1) + 1));
end

--- @param i integer | string
--- @param typename string
--- @return ...
function sig.error_type(val, i, typename)
	return sig.error(i, typename .. " expected, got " .. type(val));
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

local tag = require "std.tag";
local traced_err = require "std.errors.traced_err";
local aggr = require "std.errors.aggr_err";
local is = require "std.basic.is";
local error = error;
local pcall = pcall;
local xpcall = xpcall;

local errors = {};

--- @param msg string
function errors.msg(msg)
	return tag.new(msg);
end
--- @param f string
function errors.fmt(f, ...)
	return tag.new(f:format(...));
end
function errors.aggr(errs)
	if #errs == nil then return "empty aggregate" end
	if #errs == 1 then return errs[1] end
	return aggr.new(errs);
end

--- @param err any
--- @param full boolean?
--- @param dst any[]
local function err_all_impl(err, full, dst)
	if type(err.errors) == "function" then
		if full then
			table.insert(dst, err);
		end

		local children = err:errors();

		for i = 1, #children do
			err_all_impl(children[i], full, dst);
		end
	else
		table.insert(dst, err);
	end
end

--- @param err any
--- @param full? boolean = false If true, includes errboxes as well
--- @return any[]
function errors.all(err, full)
	local res = {};
	err_all_impl(err, full, res);
	return res;
end
--- @param errs any[]
--- @param full? boolean = false If true, includes errboxes as well
--- @return any[]
function errors.flatten(errs, full)
	local res = {};
	for i = 1, #errs do
		err_all_impl(errs[i], full, res);
	end
	return res;
end
--- @generic T
--- @param err any
--- @param val `T`
--- @return T[]
function errors.allof(err, val)
	local raw = errors.all(err, true);
	local res = {};

	for i = 1, #raw do
		if is(raw[i], val) then
			table.insert(res, raw[i]);
		end
	end

	return res;
end
--- @generic T
--- @param err any
--- @param val `T`
--- @return T?
function errors.firstof(err, val)
	local res = errors.allof(err, val);
	if #res <= 0 then return nil end
	return res[1];
end
--- @param a any
--- @param ... any
--- @return boolean
function errors.is(a, ...)
	local err_map = {};
	local errs = errors.all(a, true);
	for i = 1, #errs do
		err_map[errs[i]] = true;
	end

	for j = 1, select("#", ...) do
		if err_map[select(j, ...)] then
			return true;
		end
	end

	return false;
end
function errors.throw(e)
	error(e, 0);
end
---@generic T
---@param val? T
---@param ... any
---@return T
---@return any ...
function errors.assert(val, ...)
	if not val then
		return errors.throw((...));
	end

	return val, ...;
end

local function spcall_catch(e)
	if e == "stack overflow" then return errors.nostack end
	if e == "not enough memory" then return errors.nomem end
	return traced_err.new(e, nil, 0);
end

--- Calls the given function with xpcall and captures a stack trace on an error. It is returned alongside the unmodified error
--- @param f function
function errors.spcall(f, ...)
	return xpcall(f, spcall_catch, ...);
end
--- Calls the given function with xpcall and captures a stack trace on an error. It is returned alongside the unmodified error
--- @param f function
--- @param hnd fun(err: any): any, boolean The second boolean return, if true, doesn't emit a stack
function errors.sxpcall(f, hnd, ...)
	return xpcall(f, function (err)
		local err, trace = hnd(err);
		if trace then return err end
		return spcall_catch(err);
	end, ...);
end

errors.xpcall = xpcall;
errors.pcall = pcall;

-- err.badarg = err.ill:new "illegal argument";
-- err.badop = err.ill:new "illegal operation";
-- err.badaccess = err.ill:new "restricted access";
-- err.badrange = err.ill:new "out of range";
-- err.closed = err.ill:new "closed";

-- err.noperm = err.env:new "permission denied";

-- Common, pre-defined errors

errors.cancelled = errors.msg "cancelled";
errors.closed = errors.msg "closed";
errors.eof = errors.msg "eof";
errors.never = errors.msg "unreachable path exectued";
errors.notimpl = errors.msg "not implemented yet";

-- Pre-allocate these, so we don't need to allocate in these special cases

errors.nomem = errors.msg "out of memory";
errors.nostack = errors.msg "stack overflow";

return errors;

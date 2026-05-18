local debug = require "std.debug";

local real_error = error;

local errors = {
	pcall = pcall,
	xpcall = xpcall,
};
local sptag = {};

function errors.throw(err)
	return real_error(err, 0);
end
--- @param msg unknown
--- @param level? integer
function errors.error(msg, level)
	level = level or 1;

	if type(msg) ~= "string" or level < 1 then
		return real_error(msg, 0);
	end

	local info = debug.getinfo(level + 1, "Sl");

	if info and info.what == "Lua" then
		if info.currentcol and info.currentcol > 0 then
			return real_error(info.short_src .. ":" .. info.currentline .. ":" .. info.currentcol .. ": " .. msg, 0);
		elseif info.currentline and info.currentline > 0 then
			return real_error(info.short_src .. ":" .. info.currentline .. ": " .. msg, 0);
		else
			return real_error(info.short_src .. ": " .. msg, 0);
		end
	end

	return real_error(msg, 0);
end
--- @generic T
--- @param val T | nil | false
--- @return T, ...
function errors.assert(val, ...)
	local message = ...;

	if not val then
		return errors.error(message or "assertion failed!", 1);
	else
		return val, ...;
	end
end

--- An IO alternative for assert (doesn't change the error message)
--- @generic T
--- @param val T | nil
--- @param err string?
--- @return T
function errors.iassert(val, err)
	if not val and err then
		return errors.error(err, 0);
	end
	return val;
end
--- An IO alternative for error (doesn't change the error message)
--- @param err any
function errors.ierror(err)
	return errors.error(err, 0);
end

--- If the error is a stackful error, splits it into its base error and a stack trace
--- Useful when working with non stackful error-aware code, like coroutine.resume
function errors.serrunpack(err)
	local trace;
	while type(err) == "table" do
		trace = err.trace;
		err = err.err;
	end

	return err, trace;
end
--- Throws a stackful error. Must be handled by stackful error-aware code (with spcall or serrunpack)
--- @param err any
--- @param trace? string
function errors.serror(err, trace)
	errors.error { err = errors.serrunpack(err), trace = trace, [sptag] = true };
end
local function spcall_catch(err)
	if err == "stack overflow" then return err end

	local err, trace = errors.serrunpack(err);

	if trace then
		trace = trace .. "\nrethrow " .. debug.traceback(nil, 2);
	else
		trace = debug.traceback(nil, 2);
	end

	return { [sptag] = true, err = err, trace = trace };
end
local function spcall_fin(ok, ...)
	if not ok then
		return false, errors.serrunpack(...);
	end

	return ok, ...;
end
--- Calls the given function with xpcall and captures a stack trace on an error. It is returned alongside the unmodified error
--- @param f function
function errors.spcall(f, ...)
	return spcall_fin(errors.xpcall(f, spcall_catch, ...));
end
--- Calls the given function with xpcall and captures a stack trace on an error. It is returned alongside the unmodified error
--- @param f function
--- @param hnd fun(err: any, trace: string): any, boolean | string The second boolean return, if true, doesn't emit a stack, if a string, used as a stack
function errors.sxpcall(f, hnd, ...)
	return spcall_fin(errors.xpcall(f, function (err)
		local err, trace = hnd(errors.serrunpack(err));
		if trace == true then return err end
		if trace then return err, trace end
		return spcall_catch(err);
	end, ...));
end

return errors;

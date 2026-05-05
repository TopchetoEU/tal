local impl = require "impl";
local loop = require "std.loop";

--- @alias std.signal
--- | "INT" Ctrl + C was pressed
--- | "QUIT" Ctrl + Q was pressed
--- | "ABRT" Aborted by abort()
--- | "TERM" Kindly asked to kill oneself
--- | "BADMEM" Illegal memory usage
--- | "BADOP" Illegal operation
--- | "BADPIPE" Illegal usage of a pipe (ignore this)
--- | "TSIZE" Terminal resized
--- | "TLOST" Terminal lost
--- | "USR1" User signal 1
--- | "USR2" User signal 2

local signal = {};

-- TODO: make interface nicer (per-signal handles), when libev cancellations are implemented

--- @param sig std.signal
function signal.on(sig)
	return assert(impl:sig_on(sig));
end
--- @param sig std.signal
function signal.off(sig)
	return assert(impl:sig_off(sig));
end
--- @return std.signal
function signal.wait()
	return assert(loop.sync_ret(impl:sig_wait((coroutine.running()))));
end

return signal;


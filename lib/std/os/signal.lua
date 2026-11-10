local impl = require "impl";
local loop = require "std.loop";
local pipe = require "std.sync.pipe";

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

--- @type table<std.signal, std.sync.pipe[]>
local listeners = {};

loop.fork(function ()
	while true do
		local sig = loop.await(impl:sig_wait((coroutine.running())));

		for i = 1, #listeners[sig] do
			listeners[sig][i]:write(sig);
		end
	end
end)
	:name "Signal handler"
	:daemon(true);

--- @param sig std.signal
--- @param cond std.sync.pipe
function signal.on(sig, cond)
	if not listeners[sig] then
		listeners[sig] = {};
		impl:sig_on(sig);
	end

	table.insert(listeners[sig], cond);
end
--- @param sig std.signal
--- @param cond std.sync.pipe
function signal.off(sig, cond)
	if not listeners[sig] then
		return false;
	end

	if table.delete(listeners[sig], cond) == 0 then
		return false;
	end

	if #listeners[sig] == 0 then
		listeners[sig] = nil;
		impl:sig_off(sig);
	end
end

--- @param sig std.signal
function signal.mute(sig)
	local p = pipe.new();
	signal.on(sig, p);

	return loop.fork(function ()
		local ok, err = spcall(function ()
			while true do p:read() end
		end);

		if ok then return end
		if not errors.is(err, errors.cancelled) then throw(err) end

		signal.off(sig, p);
	end):daemon(true);
end

return signal;


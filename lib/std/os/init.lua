local time = require "std.os.time";
local env = require "std.os.env";
local proc = require "std.os.proc";
local impl = require "impl";
local loop = require "std.loop";

-- VERY bad way of gauging this, this will stay until libev v0.3
local old_time = os.time;
local os = {
	date = os.date,
	exit = os.exit,
	rename = os.rename,
	setlocale = os.setlocale,
	tmpname = os.tmpname,
};

os.os = jit.os;
os.atch = jit.arch;

--- @param a number
--- @param b number
function os.difftime(a, b)
	return a - b;
end
function os.clock()
	return time.time "cpu";
end
--- @param arg? osdateparam
function os.time(arg)
	if arg then
		return old_time(arg);
	else
		return time.time "real";
	end
end
--- @param path string
function os.remove(path)
	loop.sync_ret(impl:remove(coroutine.running(), path));
	return true;
end

os.getenv = env.get;
os.setenv = env.set;
os.iterenv = env.iter;

--- @param cmd string
function os.execute(cmd)
	if os.os == "Windows" then
		local code = proc { argv = { "cmd", "/c", cmd } }:wait();
		if code ~= 0 then
			ierror("process exited with code " .. -code);
		end
	elseif os.os ~= "Other" then
		local code = proc { argv = { "sh", "-c", cmd }, path = true }:wait();
		if code ~= 0 then
			ierror("process exited with code " .. -code);
		end
	else
		ierror "unknown operating system, cannot perform system commands";
	end

	return true;
end

return os;

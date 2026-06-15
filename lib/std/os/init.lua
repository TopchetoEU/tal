local time = require "std.os.time";
local env = require "std.os.env";
local proc = require "std.os.proc";

-- VERY bad way of gauging this, this will stay until libev v0.3
local offset = os.clock() - time.monotime();

local old_time = os.time;
local os = {
	date = os.date,
	exit = os.exit,
	remove = os.remove,
	rename = os.rename,
	setlocale = os.setlocale,
	tmpname = os.tmpname,
};

os.os = jit.os;
os.atch = jit.arch;

function os.difftime(a, b)
	return a - b;
end
function os.clock()
	return time.monotime() + offset;
end
function os.time(arg)
	if arg then
		return old_time(arg);
	else
		return time.now();
	end
end

os.getenv = env.get;
os.setenv = env.set;
os.iterenv = env.iter;

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

local env = {};

local has_jit, jit = pcall(require, "jit");

if has_jit then
	env.jit = true;
	env.os = jit.os;
	env.runtime = jit.version;
	env.arch = jit.arch;
else
	env.jit = false;
	print "NOT RUNNING IN LUAJIT!!";
	print "Some libraries might depend on ffi. Continue at your own risk!";

	env.jit = false;
	env.os = "unknown";
	env.arch = "unknown";

	local function extract_os()
		if not io.popen then return end

		local uname_f = io.popen("uname -ms");
		if uname_f ~= nil then
			local os, arch = uname_f:read "*a":sub(1, -2):match "([^%s]+) ([^%s]+)";

			env.os = os;
			env.arch = arch;
			return;
		end

		local os_name = os.getenv "OS";
		if os_name == "Windows_NT" then
			env.os = "windows";
			env.arch = os.getenv "PROCESSOR_ARCHITECTURE";
		end
	end

	extract_os();
	env.runtime = _VERSION;
end

return function (glob)
	glob.env = env;
end

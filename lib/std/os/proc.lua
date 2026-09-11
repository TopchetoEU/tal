local loop = require "std.loop";
local path = require "std.path";
local impl = require "impl";
local collected = require "std.basic.table.collected";
local str = require "std.str";
local impl_str = require "std.os.fs.str";
local err = require "std.err";

--- @class std.os.proc
--- @field _fd impl.process
--- @field _mng string?
--- @field _closed boolean
--- @field stdin std.str?
--- @field stdout std.str?
--- @field stderr std.str?
local proc = {};
proc.__index = proc;
proc.__metatable = "std.os.proc";


--- @class std.os.proc.err: err
--- @field code integer
proc.err = setmetatable({ parent = err.io }, err);
proc.err.__index = proc.err;
proc.err.__metatable = "std.os.proc.err";

function proc.err:__tostring()
	if self.code < 0 then
		return "process exited with code " .. -self.code;
	else
		return "proc exited with signal " .. self.code;
	end
end

--- @param code integer
function proc.err:new(code)
	return setmetatable({ code = code }, proc.err);
end

function proc:wait()
	if self._closed then error(err.closed) end

	--- @type integer
	local code = loop.sync_ret(self._fd:wait(coroutine.running()));

	self._closed = true;
	self._mng = nil;

	return code;
end
function proc:close()
	if self._closed then return true end

	local code = self:wait();
	if code ~= 0 then error(proc.err:new(code)) end

	return true;
end
function proc:to_stream()
	-- NOTE: we don't have to worry about double-buffering, as the underlying std streams will most likely be unbuffered

	local self = setmetatable({ _proc = self }, str);
	function self:_read(ptr, n)
		if not self._proc.stdout then error(err.notsupp) end
		return self._proc.stdout:read(ptr, n);
	end
	function self:_write(ptr, n)
		if not self._proc.stdin then error(err.notsupp) end
		return self._proc.stdin:write(ptr, n);
	end
	function self:_flush()
		if self._proc.stdin then
			self._proc.stdin:flush();
		end
		if self._proc.stdout then
			self._proc.stdout:flush();
		end
	end
	function self:_close()
		if self._proc._closed then return end

		if self._proc.stdin then
			self._proc.stdin:close();
		end
		if self._proc.stdout then
			self._proc.stdout:close();
		end

		self._proc:close();
	end

	return self;
end
function proc:__gc()
	if not self._closed then
		if self._mng then
			print("warn: proc not freed: " .. self._mng);
		else
			print("warn: proc not freed");
		end
	end
end

--- @class std.proc.opts
--- @field argv string[]
--- @field path? string | boolean Supports package.overridepath, set to ";;" or true to use PATH env variable. Set to false for no path resolution
--- @field env? { [string]: string, [integer]: { [1]: string, [2]: string } }
--- @field cwd? string
--- @field stdin? boolean
--- @field stdout? boolean
--- @field stderr? boolean

--- @param opts std.proc.opts
function proc.new(opts)
	local os_path = (os.getenv "PATH" or ""):gsub(":", ";");

	if opts.path == nil then
		opts.path = true;
	end

	if opts.path == true then
		opts.path = os_path;
	elseif opts.path then
		opts.path = package.overridepath(os_path, opts.path);
	else
		opts.path = nil;
	end

	if opts.path and not opts.argv[1]:find "[/\\%.]" then
		for _, part in opts.path:split ";" do
			local filename = path.join(part, opts.argv[1]);
			local f = io.open(path.join(part, opts.argv[1]), "r");
			if f then
				f:close();
				opts.argv[1] = filename;
				break;
			end
		end
	end

	local res, stdin, stdout, stderr = loop.sync_ret(impl:spawn(coroutine.running(), opts.argv, opts.env, opts.cwd, opts.stdin, opts.stdout, opts.stderr, opts.windowssucks));

	local self = collected(setmetatable({
		_fd = res,
		_mng = debug.traceback(),
		stdin = stdin and impl_str.new(stdin),
		stdout = stdout and impl_str.new(stdout),
		stderr = stderr and impl_str.new(stderr)
	}, proc));

	return self;
end

return proc;

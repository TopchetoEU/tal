local loop = require "std.loop";
local stream = require "std.io.stream";
local collected = require "std.collected";
local path = require "std.path";
local impl = require "impl"

--- @class std.proc
--- @field _fd _impl.process
--- @field _mng string?
--- @field _closed boolean
--- @field stdin std.io.stream?
--- @field stdout std.io.stream?
--- @field stderr std.io.stream?
local proc = {};
proc.__index = proc;
proc.__metatable = "std.proc";

function proc:wait()
	if self._closed then ierror "closed" end

	--- @type "sig" | "exit", integer
	local kind, code = assert(loop.sync_ret(self._fd:wait(coroutine.running())));

	self._closed = true;
	self._mng = nil;

	if kind == "sig" then
		return -code;
	else
		return code;
	end
end
function proc:close()
	if self._closed then return true end

	local code = self:wait();
	if code ~= 0 then ierror(code) end

	return true;
end
function proc:to_stream()
	self._mng = nil;
	local self = { p = self };
	function self:read(ptr, n)
		if not self.p.stdout then ierror "writeonly" end
		return self.p.stdout:ptrread(false, ptr, n);
	end
	function self:write(ptr, n)
		if not self.p.stdin then ierror "readonly" end
		return self.p.stdin:ptrwrite(false, ptr, n);
	end
	function self:flush(ptr, n)
		if self.p.stdin then
			self.p.stdin:flush();
		end
		if self.p.stdout then
			self.p.stdout:flush();
		end
		return true;
	end
	function self:close()
		if self.p._closed then return true end

		if self.p.stdin then
			self.p.stdin:close();
		end
		if self.p.stdout then
			self.p.stdout:close();
		end

		return self.p:close();
	end

	return stream.new(self);
end
function proc:__gc()
	if self._mng then
		print("warn: proc not freed: " .. self._mng);
	end
end

--- @class std.proc.opts
--- @field argv string[]
--- @field path? string | boolean Supports package.overridepath, set to ";;" or true to use PATH env variable. Set to false for no path resolution
--- @field env? { [string]: string, [integer]: { [1]: string, [2]: string } }
--- @field cwd? string
--- @field stdin? "inherit" | "pipe"
--- @field stdout? "inherit" | "pipe"
--- @field stderr? "inherit" | "pipe"

--- @param opts std.proc.opts
return function (opts)
	opts.stdin = opts.stdin or "inherit";
	opts.stdout = opts.stdout or "inherit";
	opts.stderr = opts.stderr or "inherit";

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

	local res = iassert(loop.sync_ret(impl:spawn(coroutine.running(), opts.argv, opts.env, opts.cwd, opts.stdin, opts.stdout, opts.stderr, opts.windowssucks)));

	local self = collected(setmetatable({
		_fd = res.proc,
		_mng = debug.traceback(),
		stdin = res.stdin and stream.from_stream(res.stdin, true),
		stdout = res.stdout and stream.from_stream(res.stdout, true),
		stderr = res.stderr and stream.from_stream(res.stderr, true)
	}, proc));

	return self;
end

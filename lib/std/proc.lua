local loop = require "std.loop";
local stream = require "std.io.stream";
local field = require "std.field";
local collected = require "std.collected";
local path = require "std.path";
local impl = require "impl"

local proc_fd = field();

--- @class std.proc
--- @field _fd _impl.process
--- @field _mng string?
--- @field stdin std.io.stream?
--- @field stdout std.io.stream?
--- @field stderr std.io.stream?
local proc_index = {};
function proc_index:wait()
	if self._mng then return nil, "closed" end

	local kind, code = loop.sync_ret(self._fd:wait(coroutine.running()));
	if not kind then return nil, code end

	proc_fd:set(self, nil);

	self._mng = nil;

	return code;
end

local proc_meta = { __index = proc_index };
function proc_meta:__gc()
	if not self._mng then
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
--- @return std.proc?
--- @return string? err
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

	local res, err = loop.sync_ret(impl:spawn(coroutine.running(), opts.argv, opts.env, opts.cwd, opts.stdin, opts.stdout, opts.stderr));
	if err then return nil, err end

	local self = setmetatable(collected({
		_fd = res.proc,
		_mng = debug.traceback(),
		stdin = res.stdin and stream.from_stream(res.stdin, false),
		stdout = res.stdout and stream.from_stream(res.stdout, false),
		stderr = res.stderr and stream.from_stream(res.stderr, false)
	}), proc_meta);
	proc_fd:set(self, res.proc);

	return self;
end

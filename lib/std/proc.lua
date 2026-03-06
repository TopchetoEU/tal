local loop = require "tal.loop";
local stream = require "std.io.stream";
local field = require "std.field";
local collected = require "std.collected";
local handle = require "std.io.handle";
local path = require "std.path";

local proc_fd = field();

--- @class std.proc
--- @field stdin std.io.stream?
--- @field stdout std.io.stream?
--- @field stderr std.io.stream?
local proc_index = {};
function proc_index:wait()
	if not proc_fd:get(self) then return nil, "closed" end

	local kind, code = loop.curr.ev:sproc_wait(proc_fd:get(self));
	if not kind then return nil, code end

	proc_fd:set(self, nil);
	return kind, code;
end

local proc_meta = { __index = proc_index };
function proc_meta:__gc()
	if proc_fd:get(self) then
		print "warn: proc not freed";
	end
end

--- @class std.proc.opts
--- @field argv string[]
--- @field path? string | boolean Supports package.overridepath, set to ";;" or true to use PATH env variable. Set to false for no path resolution
--- @field env? { [string]: string, [integer]: { [1]: string, [2]: string } }
--- @field cwd? string
--- @field stdin? "inherit" | "pipe" | std.io.stream
--- @field stdout? "inherit" | "pipe" | std.io.stream
--- @field stderr? "inherit" | "pipe" | std.io.stream

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

	if
		opts.stdin ~= "inherit" and opts.stdin ~= "pipe" or
		opts.stdout ~= "inherit" and opts.stdout ~= "pipe" or
		opts.stdout ~= "inherit" and opts.stdout ~= "pipe"
	then
		error "passing stream to spawn not supported";
	else
		local proc, stdin, stdout, stderr = loop.curr.ev:sproc_spawn(opts.argv, opts.env, opts.cwd, opts.stdin, opts.stdout, opts.stderr);
		if not proc then return nil, stdin end

		local res = setmetatable(collected({
			stdin = stdin and stream.new(handle(stdin), nil, true),
			stdout = stdout and stream.new(handle(stdout), nil, true),
			stderr = stderr and stream.new(handle(stderr), nil, true)
		}), proc_meta);
		proc_fd:set(res, proc);

		return res;
	end
end

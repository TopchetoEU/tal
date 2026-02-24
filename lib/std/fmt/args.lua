local read_args;

--- @alias args.consumer<T> fun(ctx: T, ...: string)

--- @alias args.options<T> { ctx: T, next: args.consumer<T>, rest: args.consumer<T>, flags: table<string, args.consumer<T> | string> }

--- @return args.consumer
local function get_opt(opts, name, n)
	n = n or 100;
	if n == 0 then error "option aliases form a loop" end

	if not opts.flags[name] then
		error("no such option '" .. name .. "'");
	elseif type(opts.flags[name]) == "function" then
		return opts.flags[name];
	else
		return get_opt(opts, opts.flags[name], n - 1);
	end
end

local function read_single(opts, i, val, ...)
	if i > #val then
		return read_args(opts, nil, ...);
	end

	return read_single(opts, i + 1, val, get_opt(opts, val:sub(i, i))(opts.ctx, ...));
end
local function read_multi(opts, name, ...)
	return read_args(opts, nil, get_opt(opts, name)(opts.ctx, ...));
end
--- @return string ...
local function read_rest(opts, cb, ...)
	if select("#", ...) > 0 and opts.rest then
		cb(opts, cb, opts.rest(opts.ctx, ...));
	else
		return opts.next(opts.ctx, ...);
	end
end

--- @generic T
--- @param opts args.options<T>
--- @param ... string
--- @return string ...
function read_args(opts, _, ...)
	if select("#", ...) == 0 then
		return opts.next(opts.ctx, ...);
	end

	local curr = ...;

	if curr == "--" then return read_rest(opts, read_rest, select(2, ...)) end

	local name, val = curr:match "^%-%-(.-)=(.+)$";
	if name then
		read_multi(opts, name, val);
		return read_args(opts, nil, select(2, ...));
	end

	name = curr:match "^%-%-(.+)$";
	if name then return read_multi(opts, name, select(2, ...)) end

	name = curr:match "^%-(.+)$";
	if name then return read_single(opts, 1, name, select(2, ...)) end

	return read_rest(opts, read_args, ...);
end

--- @param name string
--- @return args.consumer
local function bool_flag(name, reverse)
	return function (ctx, ...)
		ctx[name] = not reverse;
		return ...;
	end
end
--- @param name string
--- @return args.consumer
local function str_flag(name)
	return function (ctx, val, ...)
		ctx[name] = assert(val, "expected string value for flag '" .. name .. "'");
		return ...;
	end
end
--- @param name string
--- @return args.consumer
local function num_flag(name)
	return function (ctx, val, ...)
		ctx[name] = assert(tonumber(val), "expected number value for flag '" .. name .. "'");
		return ...;
	end
end
--- @param name string
--- @return args.consumer
local function str_arr_flag(name)
	return function (ctx, val, ...)
		ctx[name] = ctx[name] or {};
		val = assert(val, "expected string value for array flag '" .. name .. "'");
		table.insert(ctx[name], val);
		return ...;
	end
end
--- @param name string
--- @return args.consumer
local function rest_flag(name)
	return function (ctx, ...)
		ctx[name] = { ... };
		return;
	end
end

--- @generic T
--- @param opts args.options<T>
--- @return fun(...: string): ...: string
local function cli(opts)
	return function (...)
		return read_args(opts, nil, ...);
	end
end
--- @param opts table<string, fun(...: string): ...: string>
local function pick(opts)
	return function (...)
		if opts[...] then
			return opts[...](select(2, ...));
		else
			return opts[1](...);
		end
	end
end


return {
	pick = pick,
	cli = cli,

	bool = bool_flag,
	num = num_flag,
	str = str_flag,
	str_arr = str_arr_flag,
	rest = rest_flag,
};

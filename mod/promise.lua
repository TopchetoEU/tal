local loop = require "evn-loop";
local promise = {};
promise.__index = promise;

function promise:when(on_ful, on_rej) end

function promise:await()
	local curr = coro.running();
	local res = nil;

	self:when(function (...)
		if coro.running() == curr then
			res = box(true, ...);
		else
			coro.transfer(curr, true, ...);
		end
	end, function (...)
		if coro.running() == curr then
			res = box(false, ...);
		else
			coro.transfer(curr, false, ...);
		end
	end);

	local function process(ok, ...)
		if ok then
			return ...;
		else
			error((...), 2);
		end
	end

	if res then
		return process(unbox(res));
	else
		return process(loop.interrupt());
	end
end

function promise.mk(func)
	local state = 0;
	local val = nil;

	--- @type array<fun(...)>
	local ful_handles = array {};
	--- @type array<fun(val: any)>
	local rej_handles = array {};

	local function invoke_handle(fun, arg_box)
		loop.push(function ()
			pcall(fun, unbox(arg_box));
		end);
	end

	local function fulfill(...)
		if state == 0 then
			state = 1;
			val = box(...);

			for i = 1, #ful_handles do
				invoke_handle(ful_handles[i], val);
			end
		end
	end

	local function reject(err)
		if state == 0 then
			state = 2;
			val = box(err);

			for i = 1, #ful_handles do
				invoke_handle(rej_handles[i], val);
			end
		end
	end

	local ok, err = pcall(func, fulfill, reject);
	if not ok then reject(err) end

	return setmetatable({
		when = function (_, on_ful, on_rej)
			if state == 0 then
				ful_handles:push(on_ful);
				rej_handles:push(on_rej);
			elseif state == 1 then
				return invoke_handle(on_ful, val);
			elseif state == 2 then
				return invoke_handle(on_rej, val);
			end
		end
	}, promise);
end

function promise.resolve(...)
	local res = box(...);

	return promise.mk(function (ful, rej)
		local passed = 0;

		for i = 1, res.n do
			if type(res[i]) == "table" and type(res[i].when) == "function" then
				res[i]:when(
					function (...)
						res[i] = ...;
						passed = passed + 1;

						if passed >= res.n then
							ful(unbox(res));
						end
					end,
					function (err) rej(err) end
				);
			else
				passed = passed + 1;
			end
		end

		if passed == res.n then
			ful(unbox(res));
		end
	end);
end

function promise.reject(err)
	return promise.mk(function (_, rej)
		if err and type(err.when) == "function" then
			err:when(rej, rej);
		else
			rej(err);
		end
	end);
end

return promise;

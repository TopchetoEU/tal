---@param consumers table<string, (fun(arg: string): boolean?, boolean?) | string>
--- @param ... string
--- @returns nil
return function (consumers, ...)
	local consumer_stack = array {};
	local pass_args = false;

	local function digest_arg(v)
		local consumed = false;

		while true do
			local el = consumer_stack:pop();
			if el == nil then break end

			local res, fin = el(v);
			if res then
				consumed = true;
			end
			if fin then
				pass_args = true;
				break;
			end

			if fin or res then
				break;
			end
		end

		if not consumed then
			if consumers[1](v) then
				pass_args = true;
			end
		end
	end

	local function get_consumer(name)
		local consumer = name;
		local path = {};
		local n = 0;

		while true do
			local curr = consumer;
			if path[curr] then
				local path_arr = array {};

				for k, v in next, path do
					path_arr[v] = k;
				end

				error("Alias to '" .. curr .. "' is recursive: " .. path_arr:join " -> ");
			end

			consumer = consumers[curr];
			if consumer == nil then
				local prefix;
				if n == 0 then
					prefix = "Unknown flag";
				else
					prefix = "Unknown alias";
				end

				if #curr == 1 then
					error(prefix .. " '-" .. curr .. "'");
				else
					error(prefix .. " '--" .. curr .. "'");
				end
			elseif type(consumer) == "function" then
				return consumer;
			end

			path[curr] = n;
			n = n + 1;
		end
	end

	local function next(...)
		if ... == nil then
			while #consumer_stack > 0 do
				local el = consumer_stack:pop();

				if el(nil) then
					error("Unexpected end of arguments", 0);
					break;
				end
			end
		else
			if pass_args then
				consumers[1]((...));
			elseif ... == "--" then
				pass_args = true;
			elseif (...):match "^%-%-" then
				consumer_stack:push(get_consumer((...):sub(3)));
			elseif (...):match "^%-" then
				for c in (...):sub(2):gmatch "." do
					consumer_stack:unshift(get_consumer(c));
				end
			else
				digest_arg(...);
			end

			return next(select(2, ...));
		end
	end

	return next(...);
end

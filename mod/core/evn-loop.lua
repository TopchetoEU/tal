local resolver = require "lua-resolver";

local stack = array {};
local active_th, main_th;

local exports = {};

--- @param ... fun()
function exports.push(...)
	stack:push(...);
end

function exports.interrupt()
	if coro.running() == active_th then
		-- We are trying to interrupt the currently active event loop thread
		-- We will transfer away from it and "abandon" it (leave it for non-event loop use)
		return coro.transfer(main_th);
	else
		-- We are currently in an abandoned or a non-loop thread. We can calmly transfer to the active thread
		return coro.transfer(active_th);
	end
end

--- @param main fun(...)
--- @param ... any
function exports.run(main, ...)
	if active_th then
		error "Event loop is already running!";
	end

	main_th = coro.running();

	local args = box(...);
	exports.push(function ()
		main(unbox(args));
	end)

	while #stack > 0 do
		active_th = coro.create(function ()
			while #stack > 0 and coro.running() == active_th do
				local msg = stack:shift();
				msg();
			end

			coro.transfer(main_th);
		end);

		coro.transfer(active_th);
		print "Abandoned thread...";
	end
end

-- Register the module as phony
resolver.register("evn-loop.lua", exports);

return exports;

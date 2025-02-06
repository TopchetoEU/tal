local resolver = require "lua-resolver";

local stack = array {};
local active;

local exports = {};

--- @param ... fun()
function exports.push(...)
	stack:push(...);
end

function exports.interrupt()
	if coro.running() == active then
		-- We are trying to interrupt the currently active event loop thread
		-- We will transfer away from it and "abandon" it (leave it for non-event loop use)
		return coro.transfer(exports.main);
	else
		-- We are currently in an abandoned or a non-loop thread. We can calmly transfer to the active thread
		return coro.transfer(active);
	end
end

--- @param main fun(...)
--- @param ... any
function exports.run(main, ...)
	if active then
		error "Event loop is already running!";
	end
	exports.main = coro.running();

	local args = box(...);
	exports.push(function ()
		main(unbox(args));
	end)

	while #stack > 0 do
		active = coro.create(function ()
			while #stack > 0 and coro.running() == active do
				local msg = stack:shift();
				msg();
			end

			coro.transfer(exports.main);
		end);

		coro.transfer(active);
		print "Abandoned thread...";
	end
end

-- Register the module as phony
resolver.register("evn-loop.lua", exports);

return exports;

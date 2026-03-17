local sig = require "std.sig"
--- @param cb function | thread
return function (cb, ...)
	if type(cb) == "thread" then
		if cb == coroutine.running() then
			error "cannot invoke same thread as current";
		else
			return coroutine.resume(cb, ...);
		end
	elseif type(cb) == "function" then
		return pcall(cb, ...);
	elseif type(cb) == "table" then
		return pcall(cb.cb, table.unpack(cb, 1, cb.n));
	else
		sig.error_type(cb, "cb", "function, thread or arg-packed table");
	end
end

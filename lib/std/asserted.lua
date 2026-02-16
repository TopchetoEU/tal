local function handle(...)
	local ok, err = ...;
	if not ok and err then error(err, 2) end
	return ...;
end

--- @generic T
--- @param func? T
--- @param ... any
--- @return T, ...
return function (func, ...)
	func = assert(func, ...);

	return function (...)
		return handle(func(...));
	end, ...;
end

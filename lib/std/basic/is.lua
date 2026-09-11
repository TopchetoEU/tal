--- Asks the object if it is of a given type
--- @generic T
--- @param obj any
--- @param name `T`
--- @return T?
return function (obj, name)
	if type(obj) == name then return obj end
	if obj.__is and obj:__is(name) then return obj end

	while obj ~= nil do
		if getmetatable(obj) == name then return obj end
		obj = debug.getmetatable(obj);
	end
	return nil;
end

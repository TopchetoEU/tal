--- Asks the object if it is of a given type
--- @generic T
--- @param obj any
--- @param name `T`
--- @return T?
return function (obj, name)
	if obj == nil then return nil end
	if type(obj) == name then return obj end
	if type(obj) == "table" and obj.__is and obj:__is(name) then return obj end

	while obj ~= nil do
		if getmetatable(obj) == name then return obj end
		obj = debug.getmetatable(obj);
	end
	return nil;
end

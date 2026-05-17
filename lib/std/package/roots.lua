--- @class std.package.root
--- @field path string
--- @field n integer

--- @class std.package.roots
--- @field [string] integer Reference count of each path
--- @field [integer] string Ordered list of all paths
local roots_index = {};
roots_index.__index = roots_index;
roots_index.__metatable = "std.package.roots";

local function add_one(self, path)
	if self[path] then
		self[path] = self[path] + 1;
	else
		self[path] = 1;
		table.insert(self, path);
	end
end
local function addif_one(self, path)
	if self[path] then return end

	self[path] = 1;
	table.insert(self, path);
end
local function del_one(self, path)
	if not self[path] then return end
	self[path] = self[path] - 1;

	if self[path] > 0 then return end

	for i = 1, #self do
		if self[i] == path then
			table.remove(self, i);
			break;
		end
	end
	self[path] = nil;
end
local function foreach(self, cb, ...)
	for i = 1, select("#", ...) do
		local path = select(i, ...);

		if type(path) == "string" then
			cb(self, path);
		elseif type(path) == "table" then
			for i = 1, #path do
				cb(self, path[i]);
			end
		elseif path ~= nil then
			error("bad arg type #" .. i .. "(" .. type(path) .. ")", 2);
		end
	end

	return self;
end

--- Adds all arguments as root paths, only if they aren't already present in the roots list
--- @param ... string | string[]
function roots_index:addif(...)
	return foreach(self, addif_one, ...);
end
--- Adds all arguments as root paths
--- @param ... string | string[]
function roots_index:add(...)
	return foreach(self, add_one, ...);
end
--- @param env? string
function roots_index:addenv(env)
	if not env then return self end
	for el in env:gmatch "[^;]+" do
		self:add(el);
	end
	return self;
end
--- Deletes all arguments from the root paths. If duplicates exist, removes one of them
--- @param ... string | string[]
function roots_index:del(...)
	return foreach(self, del_one, ...);
end
--- Iterates all roots. Duplicates are skipped
--- @return fun(): string?
function roots_index:iter()
	local i = 0;
	return function ()
		if i >= #self then return nil end
		i = i + 1;
		return self[i];
	end
end
--- Calls the given function with the root added to the roots set.
--- Upon the function exiting (with either a return or an error), the path is removed from the set
--- @param path string
--- @param cb fun()
function roots_index:with(cb, path)
	self:add(path);
	return (function (ok, ...)
		self:del(path);
		if not ok then error(..., 0) end
		return ...;
	end)(spcall(cb));
end

function roots_index.new(...)
	local self = setmetatable({}, roots_index);
	return self:add(...);
end

return roots_index;

local exports = {};

local function mk_module(name, init, parent)
	local module;
	local cache = {};

	parent.modules = parent.modules or {};
	module = setmetatable({
		name = name,
		exports = {},
		init = init,
		env = setmetatable({}, { __index = parent.env }),
	}, { __index = parent });

	module.returns = { n = 1, module.exports };

	function module.resolve(id, list)
		if cache[id] ~= nil then return cache[id] end

		for i = 1, #module.resolvers do
			local res, files = module.resolvers[i](module, id);
			if res then
				cache[id] = res;
				return res;
			elseif list then
				for i = 1, #files do
					list[#list + 1] = files[i];
				end
			end
		end

		return nil;
	end
	function module.import(id)
		local paths = {};
		local mod = module.resolve(id, paths);
		if mod == nil then
			error(table.concat {
				"Unable to resolve module '",
				id,
				"' - tried the following paths:\n- ",
				table.concat(paths, "\n- ")
			}, 2);
		elseif type(mod.init) == "function" then
			local init = mod.init;
			mod.init = nil;
			init(mod);
		end

		return (unpack or table.unpack)(mod.returns, 1, mod.returns.n);
	end

	function module.require(id)
		local original_id = id;
		local match = id:match "[^/]+$";

		if match == id then
			local start = id:match "^%.+" or "";
			local rest = id:sub(#start + 1):gsub("%.", "/");

			if #start == 0 then
				id = rest;
			elseif #start == 1 then
				id = "./" .. rest;
			else
				id = ("../"):rep(#start - 1) .. rest;
			end
		else
			id = id:sub(1, -#match - 1) .. match:gsub("%.", "/");
		end

		local paths = {};
		local mod = module.resolve(id .. ".lua", paths);

		if mod == nil then
			mod = module.resolve(id .. "/init.lua", paths);
		end

		if mod == nil then
			error(table.concat {
				"Unable to resolve module '",
				original_id,
				"' - tried the following paths:\n- ",
				table.concat(paths, "\n- ")
			}, 2);
		elseif type(mod.init) == "function" then
			local init = mod.init;
			mod.init = nil;
			init(mod);
		end

		return (unpack or table.unpack)(mod.returns, 1, mod.returns.n);
	end
	function module.export(exports)
		for k, v in next, exports do
			module.exports[k] = v;
		end
	end
	function module.mk(name, init)
		if module.modules[name] ~= nil then
			return module.modules[name], true;
		else
			local mod = mk_module(name, init, module);
			module.modules[name] = mod;
			return mod, false;
		end
	end

	module.env.module = module;
	module.env.import = module.import;
	module.env.require = module.require;
	module.env.export = module.export;
	module.env.exports = module.exports;

	module.env.package = setmetatable({}, {
		__index = function()
			error "This is a TAL module, please use 'module' instead";
		end,
		__newindex = function()
			error "This is a TAL module, please use 'module' instead";
		end,
	});

	return module;
end

local function try_file(self, cwd, id, base, suffixes)
	suffixes = suffixes or { "" };
	local file, found;
	local files = {};

	for i = 1, #suffixes do
		file = cwd(base, id .. suffixes[i]);

		local f = io.open(file, "r");
		if f ~= nil then
			f:close();
			found = true;
			break;
		end

		files[#files + 1] = file;
	end

	if not found then
		return nil, files;
	end

	return self.mk(file, function (self)
		local func = assert(loadfile(file, "t", self.env));

		local function fin(...)
			if select("#", ...) > 0 then
				self.exports = ...;
				self.returns = { n = select("#", ...), ... };
			end
		end
		fin(func());
	end), file;
end

function exports.file_resolver(cwd, join)
	return function(self, id)
		if id:match "^%./" or id:match "^%.%./" then
			return try_file(self, cwd, id, join(self.name, "..", self.extensions), self.extensions);
		else
			local files = {};

			for i = 1, #self.paths do
				local res, file = try_file(self, cwd, id, self.paths[i], self.extensions);
				if res ~= nil then
					return res, file;
				end

				for i = 1, #file do
					files[#files + 1] = file[i];
				end
			end

			return nil, files;
		end
	end
end
function exports.lua_resolver(opts)
	local returns = {
		modules = {},
	};

	function returns.resolver(self, id)
		if id:match "^lua:" then
			id = id:sub(5);
		end

		if returns.modules[id] ~= nil then
			return returns.modules[id], "lua:" ..id;
		else
			return nil, { "lua:" .. id };
		end
	end

	function returns.register(name, ...)
		returns.modules[name] = {
			name = "lua:" .. name,
			exports = ...,
			returns = { n = select("#", ...), ... },
		};
	end

	if opts.glob then
		returns.register("global.lua", opts.glob);
	end

	if opts.expose then
		local expose = opts.expose;
		if expose == true then
			expose = {
				"utf8", "bit32", "bit",
				"table", "string", "os", "math", "jit", "io", "ffi", "debug", "coroutine",
				"table.new", "table.clear",
				"string.buffer",
				"jit.profile",
			};
		end

		for i = 1, #expose do
			local ok, mod = pcall(require, expose[i]);
			if ok then
				returns.register(expose[i]:gsub("%.", "/") .. ".lua", mod);
			end
		end
	end

	if opts.root then
		returns.register("root.lua", opts.root);
	end

	returns.register("lua-resolver.lua", returns);

	return returns;
end

function exports.mk_root(opts)
	local run_loop;
	local root = mk_module(
		opts.join(opts.pwd, "/<root>"),
		nil,
		{
			paths = {},
			resolvers = {},
			modules = {},
			env = opts.glob,
		}
	);

	root.paths[#root.paths + 1] = opts.pwd .. "/.tal_mod";

	if opts.tal_path then
		for i = 1, #opts.tal_path do
			local p = opts.tal_path[i];

			if p:match "^~/" then
				root.paths[#root.paths + 1] = opts.join(opts.home, p:sub(2));
			elseif p:match "^/" then
				root.paths[#root.paths + 1] = opts.join(p);
			else
				root.paths[#root.paths + 1] = opts.join(opts.pwd, p);
			end
		end
	end

	if opts.lua_path then
		for v in opts.lua_path:gmatch "[^;]+" do
			local match = v:match "^(.+)/%?%.lua$";
			if match ~= nil and match ~= "." then
				root.paths[#root.paths + 1] = match;
			end
		end
	end

	if opts.resolvers then
		root.resolvers[#root.resolvers + 1] = exports.file_resolver(opts.cwd, opts.join);
		root.resolvers[#root.resolvers + 1] = exports.lua_resolver {
			glob = opts.glob,
			expose = true,
			root = root,
		}.resolver;
	end

	return root, run_loop;
end

function exports.init(opts, msg)
	if opts.glob == nil then
		---@diagnostic disable-next-line: deprecated
		opts.glob = _ENV or _G or (getfenv and getfenv());
		if opts.glob == nil then
			error "Environment is not accessible";
		end
	end

	local root = exports.mk_root {
		tal_path = opts.tal_path,
		lua_path = opts.lua_path or package.path,
		resolvers = true,
		evn_loop = true,

		pwd = opts.pwd or opts.fs.pwd(),
		home = opts.home or opts.fs.home(),

		join = opts.join or opts.path.join,
		cwd = opts.cwd or opts.path.cwd,
		glob = opts.glob,
	};

	local require = root.require;

	require "core"(opts.target_glob or root.env);
	local run_loop = require "core.evn-loop";
	root.env.promise = require "promise";

	return root, run_loop;
end

return exports;

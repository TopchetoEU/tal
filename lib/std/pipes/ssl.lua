local ffi = require "ffi";
local libssl = require "nat.libssl";
local cond = require "std.sync.cond";
local str  = require "std.str"

local function ssl_doread(self)
	if self.reading then
		-- A bit shitty, makes sure that we block on the current read, as if we did it
		self.cond:wait();
		return false;
	end

	self.reading = true;

	local ptr = ffi.new "char[8192]";

	local ok, n, trace = spcall(self.stream.read, self.stream, ptr, 8192);
	if n == 0 then ok = false; n = "unexpected ssl stream eof" end
	if not ok then
		self.reading = false;
		self.cond:signal(true);
		srethrow(n, trace);
	end
	--- @cast n integer

	self.bin:write(n, ptr);

	self.reading = false;
	self.cond:signal(true);
	return true;
end
local function ssl_dowrite(self)
	if self.writting then
		self.cond:wait();
		return false;
	end

	self.writting = true;

	local buff = ffi.new "char[8192]";

	while true do
		if not self.stream then ierror "closed" end

		local n = self.bout:read(8192, buff);
		if not n or n == 0 then break end

		local ok, err, trace = spcall(self.stream.fullwrite, self.stream, buff, n);
		if not ok then
			self.writting = false;
			self.cond:signal(true);
			srethrow(err, trace);
		end
	end

	self.writting = false;
	self.cond:signal(true);
	return true;
end

local function ssl_flush(self)
	if not self.hnd then ierror "closed" end
	ssl_dowrite(self);
end
local function ssl_close(self)
	if not self.stream then return end
	if self.owned then self.stream:close() end
	self.cond:signal(true);
	self.stream = nil;
end

--- @class std.io.ssl_opts
--- @field backend std.str The stream over which to do TLS
--- @field host? string For clients, name of the server we are connecting to
--- @field owned? boolean If set to true, closing the created stream will close the backend too
--- @field role? "client" | "server" What role the TLS stream will have. By default client
--- @field cert? string Certificate to use. Only for servers
--- @field key? string Private key to use. Only for servers

--- Returns a TLS stream, using `backend` as the transport
--- @param opts std.io.ssl_opts
return function (opts)
	local owned = opts.owned or false;
	local role = opts.role or "client";
	local backend = opts.backend;

	local hnd = libssl.new();
	local bin = libssl.new_bio();
	local bout = libssl.new_bio();

	hnd:set_bio(bin, bout);

	if role == "client" then
		hnd:set_connect_state();
		if opts.host then
			assert(hnd:set_host(opts.host));
		end
	else
		hnd:use_cert(assert(libssl.read_x509(libssl.bio_from_str(opts.cert))));
		hnd:use_key(assert(libssl.read_pkey(libssl.bio_from_str(opts.key))));
		hnd:set_accept_state();
	end

	local self = setmetatable({
		hnd = hnd,
		stream = backend,

		reading = false,
		writting = false,
		cond = cond.new(),
		-- readlock = mutex.new(),
		-- writelock = mutex.new(),

		bin = bin,
		bout = bout,

		owned = owned,
	}, str);

	function self:read(ptr, n)
		if not self.hnd then ierror "closed" end

		while true do
			local curr_n, code = self.hnd:read(n, ptr);
			if curr_n and not code then return curr_n end

			local err_code = self.hnd:get_error(0);

			if err_code == 6 then
				ierror "pipe broken";
			elseif err_code == 5 then
				return 0;
			elseif err_code == 2 then
				if ssl_dowrite(self) then ssl_doread(self) end
			elseif err_code ~= 3 then
				ierror(libssl.err_msg(code));
			end
		end
	end
	function self:write(ptr, n)
		if not self.hnd then ierror "closed" end

		while true do
			local res_n, code = self.hnd:write(n, ptr);
			if res_n then
				ssl_dowrite(self);
				return res_n;
			end

			local err_code = self.hnd:get_error(0);

			if err_code == 6 then
				ierror "pipe broken";
			elseif err_code == 5 then
				return 0;
			elseif err_code == 2 then
				if ssl_dowrite(self) then ssl_doread(self) end
			elseif err_code ~= 3 then
				ierror(libssl.err_msg(code));
			end
		end
	end
	function self:flush()
		if not self.hnd then ierror "closed" end

		ssl_flush(self);
		self.stream:flush();
	end
	function self:close()
		ssl_close(self);
	end

	return self;
end

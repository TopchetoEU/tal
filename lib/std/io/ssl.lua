local stream = require "std.io.stream";
local ffi = require "ffi";
local libssl = require "nat.libssl";
local cond = require "std.sync.cond";

--- @class std.io.ssl_data
--- @field hnd? nat.libssl.ssl
--- @field stream? std.io.stream
---
--- @field bin nat.libssl.bio
--- @field bout nat.libssl.bio
---
--- @field owned boolean

local function ssl_flush(self)
	if not self.hnd then ierror "closed" end

	local buff = ffi.new "char[8192]";

	while true do
		local n = self.bout:read(8192, buff);
		if not n or n == 0 then return end
		if not self.stream then ierror "closed" end
		self.stream:ptrwrite(true, buff, n);
	end
end
local function ssl_close(self_data)
	if self_data.owned then
		self_data.stream:close();
		self_data.owned = false;
		self_data.stream = nil;
	end
end

local function ssl_handle_err(self, code)
	if not self.hnd then ierror "closed" end

	local ssl_err = self.hnd:get_error(code);
	if ssl_err == 2 or ssl_err == 3 then
		ssl_flush(self);

		if ssl_err == 2 then
			if self.reading then
				self.read_cond:wait();
				return true;
			end

			local ptr = ffi.new "char[8192]";

			if not self.stream then ierror "closed" end

			self.reading = true;
			local n = self.stream:ptrread(false, ptr, 8192);
			self.reading = false;
			self.read_cond:signal(true);

			if n == 0 then return false end

			ssl_flush(self);
			self.bin:write(n, ptr);

			return true;
		end
	else
		ierror(libssl.err_msg(code));
	end
end

--- @class std.io.ssl_opts
--- @field backend std.io.stream The stream over which to do TLS
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

	--- @type std.io.stream.backend
	local self = {
		hnd = hnd,
		stream = backend,

		reading = false,
		read_cond = cond.new(),

		bin = bin,
		bout = bout,

		owned = owned,
	};

	function self:read(ptr, n)
		if not self.hnd then ierror "closed" end

		while true do
			local curr_n, code = self.hnd:read(n, ptr);
			if curr_n and not code then return curr_n end

			if self.hnd:get_error(0) == 6 then
				ierror "pipe broken";
			end

			if self.hnd:get_error(0) == 5 then
				if code == 0 then return 0 end
			end

			if not ssl_handle_err(self, code) then
				ierror "pipe broken";
			end
		end
	end
	function self:write(ptr, n)
		if not self.hnd then ierror "closed" end

		while true do
			local res_n, code = self.hnd:write(n, ptr);
			if res_n then return res_n end

			if not ssl_handle_err(self, code) then
				return 0;
			end
		end
	end
	function self:flush()
		ssl_flush(self);
		self.stream:flush();
	end
	function self:close()
		ssl_close(self --[[@as std.io.ssl_data]]);
	end

	return stream.new(self, true);
end

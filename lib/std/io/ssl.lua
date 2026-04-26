local stream = require "std.io.stream";
local loop = require "std.loop";
local ffi = require "ffi";
local libssl = require "nat.libssl"
local libc   = require "nat.libc"
local mutex  = require "std.sync.mutex"
local cond   = require "std.sync.cond"

--- @class std.io.ssl_data
--- @field hnd? nat.libssl.ssl
--- @field stream? std.io.stream
---
--- @field bin nat.libssl.bio
--- @field bout nat.libssl.bio
---
--- @field owned boolean

local function ssl_flush(self)
	if not self.hnd then return nil, "closed" end

	local buff = ffi.new "char[8192]";

	while true do
		local n = self.bout:read(8192, buff);
		if not n or n == 0 then return true end

		local _, err = self.stream:ptrwrite(true, buff, n);
		if err then return nil, err end
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
	if not self.hnd then return nil, "closed" end

	local ssl_err = self.hnd:get_error(code);
	if ssl_err == 2 or ssl_err == 3 then
		local _, err = ssl_flush(self);
		if err then return nil, err end

		if ssl_err == 2 then
			if self.reading then
				self.read_cond:wait();
				return true;
			end

			self.reading = true;

			local ptr = ffi.new "char[8192]";
			local n, err = self.stream:ptrread(false, ptr, 8192);

			self.reading = false;

			self.read_cond:signal(true);

			if err then return nil, err end
			if not n or n == 0 then return nil end

			local _, err = ssl_flush(self);
			if err then return nil, err end

			self.bin:write(n, ptr);

			return true;
		end
	else
		return nil, libssl.err_msg(code);
	end
end

--- @class std.io.ssl_opts
--- @field backend std.io.stream The stream over which to do TLS
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
		read_cond = cond(),

		bin = bin,
		bout = bout,

		owned = owned,
	};

	function self:read(ptr, n)
		if not self.hnd then return nil, "closed" end

		while true do
			local curr_n, code = self.hnd:read(n, ptr);
			if curr_n and not code then
				return curr_n;
			end

			if self.hnd:get_error(0) == 5 then
				if code == 0 then return nil end
			end

			local ok, err = ssl_handle_err(self, code);
			if err then return nil, err end
			if ok == nil then return nil, "pipe broken" end
		end
	end
	function self:write(ptr, n)
		if not self.hnd then return nil, "closed" end

		while true do
			local res_n, code = self.hnd:write(n, ptr);
			if res_n then
				return res_n;
			end

			local ok, err = ssl_handle_err(self, code);
			if err then return nil, err end
			if ok == nil then return 0 end
		end
	end
	function self:flush()
		local _, err = ssl_flush(self);
		if err then return nil, err end

		return self.stream:flush();
	end
	function self:close()
		return ssl_close(self --[[@as std.io.ssl_data]]);
	end

	return stream.new(self, true);
end

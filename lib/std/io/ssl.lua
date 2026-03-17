local stream = require "std.io.stream";
local loop = require "tal.loop";
local ffi = require "ffi";
local libssl = require "nat.libssl"
local libc   = require "nat.libc"

--- @class std.io.ssl_data
--- @field hnd? nat.libssl.ssl
--- @field stream? std.io.stream
---
--- @field bin nat.libssl.bio
--- @field bout nat.libssl.bio
---
--- @field owned boolean

local ssl_identity = newproxy(true);
local ssl_backend_meta = getmetatable(ssl_identity);
--- @class std.io.ssl_backend: std.io.stream_backend, userdata
local ssl_backend_index = {};
ssl_backend_meta.__index = ssl_backend_index;

local function ssl_flush(self_data)
	if not self_data.hnd then return nil, "closed" end

	local buff = ffi.new "char[8192]";
	while true do
		local n = self_data.bout:read(8192, buff);
		if not n or n == 0 then break end

		local _, err = self_data.stream:write(ffi.string(buff, n));
		if err then return nil, err end
	end

	return true;
end
local function ssl_close(self_data)
	if self_data.owned then
		self_data.stream:close();
		self_data.owned = false;
		self_data.stream = nil;
	end
end

local function ssl_handle_err(self_data, code)
	if not self_data.hnd then return nil, "closed" end

	local err = self_data.hnd:get_error(code);
	if err == 2 or err == 3 then
		local _, flush_err = ssl_flush(self_data);
		if flush_err then return nil, flush_err end

		if err == 2 then
			local data, err = self_data.stream:read "c";
			if err then return nil, err end
			if not data or data == "" then return nil end

			self_data.bin:write(#data, ffi.cast("char*", data));
		end

		return true;
	else
		return nil, libssl.err_msg(err);
	end
end

function ssl_backend_index:read(n)
	n = n or 8192;
	local self_data = debug.getuservalue(self) --[[@as std.io.ssl_data]];
	if not self_data.hnd then return nil, "closed" end

	local pdata = libc.malloc_gc(n);
	local res_n = 0;

	while true do
		local curr_n, code = self_data.hnd:read(n, pdata);
		if curr_n and not code then
			res_n = curr_n;
			break;
		end

		local ok, err = ssl_handle_err(self_data, code);
		if err then return nil, err end
		if not ok then return nil, "pipe broken" end
	end

	return ffi.string(pdata, res_n);
end
function ssl_backend_index:write(data)
	local self_data = debug.getuservalue(self) --[[@as std.io.ssl_data]];
	if not self_data.hnd then return nil, "closed" end

	local pdata = libc.malloc_gc(#data);
	ffi.copy(pdata, data, #data);
	local pn = ffi.new("size_t[1]");

	while true do
		pn[0] = #data;
		-- local err = self_data.hnd:async_write(loop.curr.ev, coroutine.running(), pn, pdata);
		-- if err then return nil, err end

		-- local code = coroutine.yield();
		-- if code > 0 then return pn[0] end

		-- local ok, err = ssl_handle_err(self_data, code);
		-- if err then return nil, err end
		-- if not ok then return 0 end

		local n, code = self_data.hnd:write(#data, pdata);
		if n then return n end

		local ok, err = ssl_handle_err(self_data, code);
		if err then return nil, err end
		if not ok then return 0 end
	end
end
function ssl_backend_index:sync()
	local err = ssl_flush(debug.getuservalue(self));

	if err then
		return nil, err;
	else
		return true;
	end
end
function ssl_backend_index:close()
	return ssl_close(debug.getuservalue(self) --[[@as std.io.ssl_data]]);
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

	local ssl_backend = newproxy(ssl_identity) --[[@type std.io.ssl_backend]];
	debug.setuservalue(ssl_backend, {
		hnd = hnd,
		stream = backend,

		bin = bin,
		bout = bout,

		owned = owned,
	});


	hnd:set_bio(bin, bout);

	if role == "client" then
		hnd:set_connect_state();
	else
		hnd:use_cert(assert(libssl.read_x509(libssl.bio_from_str(opts.cert))));
		hnd:use_key(assert(libssl.read_pkey(libssl.bio_from_str(opts.key))));
		hnd:set_accept_state();
	end

	return stream.new(ssl_backend);
end

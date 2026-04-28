local ffi = require "ffi";
local field = require "std.field";
local libev = require "nat.libev";
local objects = require "nat.utils.objects";
local callbacks = require "nat.utils.callbacks";

local libssl = ffi.load "ssl";
ffi.cdef [[
	typedef struct ssl_method SSL_METHOD;
	typedef struct ssl_ctx SSL_CTX;
	typedef struct ssl SSL;
	typedef struct bio BIO;
	typedef struct bio_method BIO_METHOD;
	typedef struct evp_pkey EVP_PKEY;
	typedef struct x509 X509;
	typedef int pem_password_cb(char *buf, int size, int rwflag, void *u);

	SSL_METHOD *TLS_method(void);
	SSL_CTX *SSL_CTX_new(const SSL_METHOD *meth);
	void SSL_CTX_free(SSL_CTX *a);

	SSL *SSL_new(SSL_CTX *ctx);
	void SSL_free(SSL *s);
	int SSL_get_error(const SSL *s, int i);
	void SSL_set_bio(SSL *s, BIO *rbio, BIO *wbio);
	void SSL_set_connect_state(SSL *s);
	void SSL_set_accept_state(SSL *s);

	long SSL_ctrl(SSL *ssl, int cmd, long larg, void *parg);
	int SSL_set1_host(SSL *s, const char *host);

	int SSL_use_PrivateKey(SSL *ssl, EVP_PKEY *pkey);
	int SSL_use_certificate(SSL *ssl, X509 *x);
	int SSL_do_handshake(SSL *s);
	int SSL_read_ex(SSL *ssl, void *buf, size_t num, size_t *readbytes);
	int SSL_write_ex(SSL *s, const void *buf, size_t num, size_t *written);

	const BIO_METHOD *BIO_s_mem(void);

	BIO *BIO_new(const BIO_METHOD *type);
	BIO *BIO_new_mem_buf(const void *buf, int len);
	int BIO_free(BIO *a);
	int BIO_read_ex(BIO *b, void *data, size_t dlen, size_t *readbytes);
	int BIO_write_ex(BIO *b, const void *data, size_t dlen, size_t *written);

	X509 *PEM_read_bio_X509(BIO *bp, X509 **x, pem_password_cb *cb, void *u);
	EVP_PKEY *PEM_read_bio_PrivateKey(BIO *bp, EVP_PKEY **x, pem_password_cb *cb, void *u);

	void X509_free(X509 *a);
	void EVP_PKEY_free(EVP_PKEY *pkey);

	unsigned long ERR_get_error(void);
	char *ERR_error_string(unsigned long e, char *buf);
	const char *ERR_lib_error_string(unsigned long e);
	const char *ERR_reason_error_string(unsigned long e);

]];

local ssl_field = field();

local ssl = {};

--- @class nat.libssl.ssl_ctx: ffi.cdata*
local ssl_ctx_index = {};
local ssl_ctx_meta = { __index = ssl_ctx_index };

function ssl_ctx_meta:__gc()
	libssl.SSL_CTX_free(self);
end

local ssl_ctx_type = ffi.metatype("SSL_CTX", ssl_ctx_meta);


--- @return nat.libssl.ssl_ctx
function ssl.new_ctx()
	return libssl.SSL_CTX_new(libssl.TLS_method());
end

--- @class nat.libssl.bio: ffi.cdata*
local bio_index = {};
local bio_meta = { __index = bio_index };

function bio_meta:__gc()
	print("FREE BIO META");
	return libssl.BIO_free(self);
end

local bio_type = ffi.metatype("BIO", bio_meta);

--- @param n integer
--- @param ptr ffi.cdata*
function bio_index:read(n, ptr)
	local pn = ffi.new "size_t[1]";
	if libssl.BIO_read_ex(self, ptr, n, pn) == 0 then
		return nil, tonumber(libssl.SSL_get_error(ssl_field:get(self), 0));
	else
		return tonumber(pn[0]);
	end
end
--- @param n integer
--- @param ptr ffi.cdata*
function bio_index:write(n, ptr)
	local pn = ffi.new "size_t[1]";
	if libssl.BIO_write_ex(self, ptr, n, pn) == 0 then
		return nil, tonumber(libssl.SSL_get_error(ssl_field:get(self)));
	else
		return tonumber(pn[0]);
	end
end

--- @return nat.libssl.bio
function ssl.new_bio()
	return libssl.BIO_new(libssl.BIO_s_mem());
end
--- @return nat.libssl.bio
function ssl.bio_from_str(data)
	return libssl.BIO_new_mem_buf(data, #data);
end

--- @class nat.libssl.x509: ffi.cdata*
local x509_index = {};

local x509_meta = { __index = x509_index };

function x509_meta:__gc()
	print("FREE X509");
	return libssl.X509_free(self);
end

local x509_type = ffi.metatype("X509", x509_meta);

--- @class nat.libssl.pkey: ffi.cdata*
local pkey_index = {};
local pkey_meta = { __index = pkey_index };

function pkey_meta:__gc()
	print("FREE PKEY");
	return libssl.EVP_PKEY_free(self);
end

local pkey_type = ffi.metatype("EVP_PKEY", pkey_meta);

--- @class nat.libssl.ssl: ffi.cdata*
local ssl_index = {};
local ssl_meta = { __index = ssl_index };

function ssl_meta:__gc()
	print("FREE SSL");
	return libssl.SSL_free(self);
end

local ssl_type = ffi.metatype("SSL", ssl_meta);

function ssl_index:get_error(code)
	return tonumber(libssl.SSL_get_error(self, code));
end

function ssl_index:set_bio(bin, bout)
	return libssl.SSL_set_bio(self, bin, bout);
end
function ssl_index:set_connect_state()
	return libssl.SSL_set_connect_state(self);
end
function ssl_index:set_accept_state()
	return libssl.SSL_set_accept_state(self);
end
function ssl_index:set_host(host)
	if libssl.SSL_set1_host(self, host) == 0 then
		return nil, self:get_error(0);
	end

	local code = libssl.SSL_ctrl(self, 55, 0, ffi.cast("void*", host));
	if code == 2 then
		return nil, self:get_error(code);
	end

	return true;
end

--- @param cert nat.libssl.x509
function ssl_index:use_cert(cert)
	return libssl.SSL_use_certificate(self, cert);
end
--- @param key nat.libssl.pkey
function ssl_index:use_key(key)
	return libssl.SSL_use_PrivateKey(self, key);
end

--- @param ev ev
--- @param pn ffi.cdata*
--- @param ptr ffi.cdata*
function ssl_index:async_read(ev, cb, pn, ptr)
	return ev:exec(cb, libssl.SSL_read_ex, "i****", ffi.typeof "int", self, ptr, ffi.cast("void*", pn[0]), ffi.cast("void*", pn));
end
--- @param ev ev
--- @param pn ffi.cdata*
--- @param ptr ffi.cdata*
function ssl_index:async_write(ev, cb, pn, ptr)
	return ev:exec(cb, libssl.SSL_write_ex, "i****", ffi.typeof "int", self, ptr, ffi.cast("size_t", pn[0]), ffi.cast("size_t*", pn));
end

--- @param n integer
--- @param ptr ffi.cdata*
function ssl_index:write(n, ptr)
	local pn = ffi.new "size_t[1]";
	local code = libssl.SSL_write_ex(self, ptr, n, pn);

	if code == 1 then
		return tonumber(pn[0]);
	else
		return nil, tonumber(code);
	end
end
--- @param n integer
--- @param ptr ffi.cdata*
function ssl_index:read(n, ptr)
	local pn = ffi.new "size_t[1]";
	local code = libssl.SSL_read_ex(self, ptr, n, pn);

	if code == 1 then
		return tonumber(pn[0]);
	else
		return nil, tonumber(code);
	end
end

--- @param ctx? nat.libssl.ssl_ctx
--- @return nat.libssl.ssl
function ssl.new(ctx)
	return libssl.SSL_new(ctx or ssl.ctx);
end

function ssl.err_msg(code)
	local errs = {};

	while true do
		code = libssl.ERR_get_error();
		if code == 0 then break end

		local res = libssl.ERR_error_string(code, nil);
		if res ~= ffi.cast("void*", 0) then
			table.insert(errs, ffi.string(res));
		end
	end

	if #errs == 0 then return "ssl error code " .. tonumber(code) end
	return table.concat(errs, "\n");
end

local function pass_password(buf, size, rwflag, userdata)
	local data = objects.get(assert(tonumber(userdata)));

	if not data.pass then
		data.err = "password required";
		return -1;
	elseif #data.pass > size then
		data.err = "password too long";
		return -1;
	elseif #data.pass < 1 then
		data.err = "password too short";
		return -1
	else
		ffi.copy(buf, data.pass);
		return #data.pass;
	end
end

local pass_password_cb = ffi.cast("pem_password_cb*", pass_password);

--- @param bio nat.libssl.bio
--- @param password? string
--- @return nat.libssl.x509?, string?
function ssl.read_x509(bio, password)
	local password_data = { pass = password };
	local password_udata = objects.add(password_data);

	local res = libssl.PEM_read_bio_X509(bio, nil, pass_password_cb, ffi.cast("void*", password_udata));
	objects.del(password_udata);

	if res == ffi.cast("void*", 0) then
		if password_data.err then
			return nil, password_data.err;
		else
			return nil, ssl.err_msg(-1);
		end
	end

	return res;
end

--- @param bio nat.libssl.bio
--- @param password? string
--- @return nat.libssl.pkey?, string?
function ssl.read_pkey(bio, password)
	local password_data = { pass = password };
	local password_udata = objects.add(password_data);

	local res = libssl.PEM_read_bio_PrivateKey(bio, nil, pass_password_cb, ffi.cast("void*", password_udata));
	objects.del(password_udata);

	if res == ffi.cast("void*", 0) then
		if password_data.err then
			return nil, password_data.err;
		else
			return nil, ssl.err_msg(-1);
		end
	end

	return res;
end

ssl.ctx = ssl.new_ctx();

return ssl;

local ffi = require "ffi";
local prop = require "std.field";
local objects = require "nat.utils.objects";

local libc = ffi.C;

local libev = ffi.load "ev";
ffi.cdef [[
	typedef int64_t off_t;
	typedef int ev_code_t;

	void free(void *ptr);

	#line 13
	typedef struct ev *ev_t;

	// Used to deploy a sync workload in an ev-managed thread
	typedef int (*ev_worker_t)(void *pargs);

	typedef struct ev_fd *ev_fd_t;
	typedef struct ev_socket *ev_socket_t;
	typedef struct ev_dir *ev_dir_t;

	typedef enum {
		// The file will be usable only for statting (by default allowed)
		EV_OPEN_STAT = 0,
		// Opens the file in read mode
		EV_OPEN_READ = 1,
		// Opens the file in write mode
		EV_OPEN_WRITE = 2,
		// Opens the file in append mode (implies WRITE)
		EV_OPEN_APPEND = 4,

		// Creates the file if it doesn't exist
		EV_OPEN_CREATE = 8,
		// Empties the contents of the file if it exists
		EV_OPEN_TRUNC = 16,
		// Opens the file in direct mode
		EV_OPEN_DIRECT = 32,
	} ev_open_flags_t;

	typedef enum {
		EV_PATH_HOME,
		EV_PATH_CONFIG,
		EV_PATH_DATA,
		EV_PATH_CACHE,
		EV_PATH_RUNTIME,
		EV_PATH_CWD,
	} ev_path_type_t;

	typedef enum {
		EV_ADDR_IPV4,
		EV_ADDR_IPV6,
		// TODO: bluetooth maybe?
	} ev_addr_type_t;
	typedef struct {
		ev_addr_type_t type;
		union {
			uint8_t v4[4];
			uint16_t v6[8];
		};
	} ev_addr_t;

	typedef struct {
		size_t n;
		ev_addr_t addr[];
	} *ev_addrinfo_t;
	typedef enum {
		// Resolves only ipv4 (if neither this nor EV_AI_IPV6 are specified, resolves both)
		EV_AI_IPV4 = 1,
		// Resolves only ipv6 (this is mutually-exclusive with IPV4, and this will override IPV4)
		EV_AI_IPV6 = 2,
		// If no IPV6 address was found, but an IPV4 address was, resolves as an ipv6 mapping of the ipv4 address
		EV_AI_IPV4_MAPPED = 4,
		// Resolves to a bindable address - mostly applicable when name is NULL (equivalent to AI_PASSIVE)
		EV_AI_BIND = 8,
		// Resolves only IP addresses - does not make DNS requests (equivalent to AI_NUMERICHOST)
		EV_AI_NODNS = 16,
	} ev_addrinfo_flags_t;

	typedef enum {
		EV_PROTO_TCP,
		EV_PROTO_UDP,
	} ev_proto_t;

	typedef enum {
		EV_STAT_REG,
		EV_STAT_DIR,
		EV_STAT_LINK,
		EV_STAT_SOCK,
		EV_STAT_FIFO,
		EV_STAT_CHAR,
		EV_STAT_BLK,
	} ev_stat_type_t;

	typedef struct {
		int64_t sec;
		uint32_t nsec;
	} ev_time_t;

	typedef struct {
		ev_stat_type_t type;
		uint32_t mode;
		uint32_t gid;
		uint32_t uid;

		ev_time_t atime, mtime, ctime;

		uint64_t size;
		uint32_t blksize;

		uint64_t inode;
		uint32_t links;
	} ev_stat_t;

	typedef enum {
		EV_POLL_OK,
		EV_POLL_EMPTY = -1,
		EV_POLL_TIMEOUT = -2,
	} ev_poll_res_t;

	// Gets the time, elapsed since the unix epoch (CLOCK_REALTIME)
	int ev_realtime(ev_time_t *pres);
	// Gets a reliably and monotonically ticking time, unaffected by the system time (CLOCK_MONOTONIC)
	// You should use this instead of `ev_realtime` when dealing with ev_poll's timeouts, and in general,
	// when you care about time offsets more than the actual current time, which is almost always the case
	int ev_monotime(ev_time_t *pres);

	// Adds the two times together
	ev_time_t ev_timeadd(ev_time_t a, ev_time_t b);
	// Subtracts the two times
	ev_time_t ev_timesub(ev_time_t a, ev_time_t b);
	// Converts the time to a millisecond count
	int64_t ev_timems(ev_time_t time);

	// Parses the string to an IP address (ipv4/6 auto-detected)
	bool ev_parse_ip(const char *str, ev_addr_t *pres);
	// Returns true if both addresses are equal
	bool ev_cmpaddr(ev_addr_t a, ev_addr_t b);

	// Converts the error code to a human-readable string
	const char *ev_strerr(ev_code_t code);

	// Creates an ev instance. Combines a queue and a thread pool
	ev_t ev_init();
	// Cancels all filesystem operations, waits for all worker threads to finish and frees all resources of the loop
	// Safe(ish) to call in GCs
	void ev_free(ev_t ev);

	// Checks if ev still has pending operations
	bool ev_busy(ev_t ev);

	// Signals to ev that a task has begun. Used to track `ev_busy`
	void ev_begin(ev_t ev);
	// Pushes a result to the message queue
	// NOTE: using the same udata twice is UB
	ev_code_t ev_push(ev_t ev, void *udata, ev_code_t err);
	// Calls worker with pargs in a ev-managed thread and returns a new ticket to it
	// Internally, this is used as a fallback for ops, not supported by AIO
	// sync - if true, will side-step the thread pool and will instead call the worker immediately
	ev_code_t ev_exec(ev_t ev, void *udata, ev_worker_t worker, void *pargs, bool sync);

	// Gets the next message in the message queue
	// If the queue is empty:
	//     If the loop is closed, returns EV_POLL_EMPTY and frees the loop
	//     If block is false, returns EV_POLL_EMPTY
	//     If block is true, blocks until a message is available and returns it
	// If ptimeout is not NULL and is reached, EV_POLL_TIMEOUT is returned. ptimeout is relative to the monotonic clock
	ev_poll_res_t ev_poll(ev_t ev, bool block, const ev_time_t *ptimeout, void **pudata, int *perr);

	// Returns a reference to the stdin FD
	ev_fd_t ev_stdin(ev_t ev);
	// Returns a reference to the stdout FD
	ev_fd_t ev_stdout(ev_t ev);
	// Returns a reference to the stderr FD
	ev_fd_t ev_stderr(ev_t ev);

	// These are the I/O wrapper functions - they will return 0 on success and a negative errno code on error
	// All the other arguments are self-explanatory. All of these functions return their results in a pointer, provided by the callee

	// Exceptions to the model are the ev_close and ev_closedir functions, which are synchronous - this makes them fit to be called in a GC

	// Equivalent to posix's open
	ev_code_t ev_open(ev_t ev, void *udata, ev_fd_t *pres, const char *path, ev_open_flags_t flags, int mode);
	// Equivalent to posix's pread
	ev_code_t ev_read(ev_t ev, void *udata, ev_fd_t fd, const char *buff, size_t *n, size_t offset);
	// Equivalent to posix's pwrite
	ev_code_t ev_write(ev_t ev, void *udata, ev_fd_t fd, char *buff, size_t *n, size_t offset);
	// Equivalent to posix's stat
	ev_code_t ev_stat(ev_t ev, void *udata, ev_fd_t fd, ev_stat_t *buff);
	// Equivalent to posix's fstat
	ev_code_t ev_fstat(ev_t ev, void *udata, ev_fd_t fd, ev_stat_t *buff);
	// Unlike all other functions, close will complete synchronously, and will never error out
	// Equivalent to posix's close
	void ev_close(ev_t ev, ev_fd_t fd);

	// Equivalent to posix's mkdir
	ev_code_t ev_mkdir(ev_t ev, void *udata, const char *path, int mode);
	// Equivalent to posix's opendir
	ev_code_t ev_opendir(ev_t ev, void *udata, ev_dir_t *pres, const char *path);
	// Equivalent to posix's readdir
	ev_code_t ev_readdir(ev_t ev, void *udata, ev_dir_t fd, char **pname);
	// Equivalent to posix's closedir
	void ev_closedir(ev_t ev, ev_dir_t fd);

	// Equivalent to socket() + bind()
	ev_code_t ev_bind(ev_t ev, void *udata, ev_socket_t *pres, ev_proto_t proto, ev_addr_t addr, uint16_t port, size_t max_n);
	// Equivalent to socket() + connect()
	ev_code_t ev_connect(ev_t ev, void *udata, ev_socket_t *pres, ev_proto_t proto, ev_addr_t addr, uint16_t port);
	// Equivalent to posix's accept
	ev_code_t ev_accept(ev_t ev, void *udata, ev_socket_t *pres, ev_addr_t *paddr, uint16_t *pport, ev_socket_t server);
	// Equivalent to posix's recv
	ev_code_t ev_recv(ev_t ev, void *udata, ev_socket_t sock, char *buff, size_t *pn);
	// Equivalent to posix's send
	ev_code_t ev_send(ev_t ev, void *udata, ev_socket_t sock, char *buff, size_t *pn);
	// Equivalent to posix's close (but for sockets)
	void ev_closesock(ev_t ev, ev_socket_t sock);

	// Equivalent to posix's getaddrinfo (with a few simplifications)
	ev_code_t ev_getaddrinfo(ev_t ev, void *udata, ev_addrinfo_t *pres, const char *name, ev_addrinfo_flags_t flags);
	// Gets a malloc'd string, representing the requested path
	ev_code_t ev_getpath(ev_t ev, void *udata, char **pres, ev_path_type_t type);
]];

local libev_dyn = ffi.load "ev-dyn";

local ev_cbs = prop();

--- @class ev.fd: ffi.cdata*
--- @class ev.socket: ffi.cdata*
--- @class ev.dir: ffi.cdata*

--- @alias ev.callback thread | fun(val: integer)

--- @class ev: ffi.cdata*
local ev = {};
ev.__index = ev;
function ev:__gc()
	print("SADFDSAF");
	libev.ev_free(self);
end
ev._ctype = ffi.metatype("struct ev", ev);

--- @param func function
--- @param ev ev
--- @param obji integer
--- @return string? err
local function ev_sync_call(func, ev, obji, ...)
	local code = func(ev, ffi.cast("void*", obji), ...);
	if code ~= 0 then return ffi.string(libev.ev_strerr(code)) end
end

local function ev_parse_ip(ip)
	local pres = ffi.new "ev_addr_t[1]";
	if not libev.ev_parse_ip(ip, pres) then return nil, "invalid address" end
	return pres[0];
end
local function ev_stringify_ip(addr)
	if addr.type == 0 then
		return ("%d.%d.%d.%d"):format(addr.v4[0], addr.v4[1], addr.v4[2], addr.v4[3]);
	elseif addr.type == 1 then
		return ("%x:%x:%x:%x:%x:%x:%x:%x"):format(
			addr.v6[0], addr.v6[1], addr.v6[2], addr.v6[3],
			addr.v6[4], addr.v6[5], addr.v6[6], addr.v6[7]
		);
	end
end

local function ev_numify_time(time)
	return assert(tonumber(time.sec)) + assert(tonumber(time.sec)) / 1000000000;
end

function ev:busy()
	return libev.ev_busy(self);
end
--- @param block? boolean = true
--- @param timeout? number
--- @return boolean | "timeout"? ok
--- @return any ...
function ev:poll(block, timeout)
	local ptimeout = nil;
	if timeout then
		ptimeout = ffi.new "ev_time_t[1]";
		ptimeout[0].sec = math.floor(timeout);
		ptimeout[0].nsec = (timeout - math.floor(timeout)) * 1000000000;
	end
	if block == nil then block = true end

	local pudata = ffi.new "void*[1]";
	local perr = ffi.new "int[1]";

	local code = assert(tonumber(libev.ev_poll(self, block, ptimeout, pudata, perr)));
	if code == 0 then
		local iudata = assert(tonumber(ffi.cast("size_t", pudata[0])));

		local ctx = objects.get(iudata);
		if type(ctx) ~= "table" then return nil, "invalid udata" end
		objects.del(iudata);

		if perr[0] == 0 then
			if ctx.process then
				return ctx.udata, ctx:process();
			else
				return ctx.udata, true;
			end
		else
			return ctx.udata, nil, ffi.string(libev.ev_strerr(tonumber(perr[0]))), tonumber(perr[0]);
		end
	elseif code == 1 then
		return false;
	else
		return "timeout";
	end
end

function ev:stdin()
	return libev.ev_stdin(self);
end
function ev:stdout()
	return libev.ev_stdout(self);
end
function ev:stderr()
	return libev.ev_stderr(self);
end

--- @param path string
--- @param flags std.fs.open_flags
--- @param mode? integer | string
--- @return string? err
function ev:open(udata, path, flags, mode)
	local real_flags = 0;
	for c in flags:gmatch "." do
		if c == "r" then
			real_flags = real_flags + 1;
		elseif c == "w" then
			real_flags = real_flags + 2;
		elseif c == "a" then
			real_flags = real_flags + 4;
		elseif c == "c" then
			real_flags = real_flags + 8;
		elseif c == "t" then
			real_flags = real_flags + 16;
		elseif c == "d" then
			real_flags = real_flags + 32;
		end
	end

	if type(mode) == "string" then
		mode = tonumber(mode, 8);
	elseif mode == nil then
		mode = 777;
	end

	local ctx = {
		udata = udata,
		pres = ffi.new "ev_fd_t[1]",
		process = function (self) return self.pres[0] end
	};

	return ev_sync_call(libev.ev_open, self, objects.add(ctx), ctx.pres, path, real_flags, mode);
end
--- @param fd ev.fd
--- @param offset integer
--- @param n integer
--- @param buff? ffi.cdata*
--- @return string? err
function ev:rawread(udata, fd, offset, n, buff)
	local ctx = {
		udata = udata,
		pn = ffi.new("size_t[1]", n),
		buff = buff or ffi.new("char[?]", n),
		process = function (self) return tonumber(self.pn[0]), self.buff end
	};

	return ev_sync_call(libev.ev_read, self, objects.add(ctx), fd, ctx.buff, ctx.pn, offset);
end
--- @param fd ev.fd
--- @param offset integer
--- @param n integer
--- @param buff ffi.cdata* | string
--- @return string? err
function ev:rawwrite(udata, fd, offset, n, buff)
	if type(buff) == "string" then buff = ffi.cast("char*", buff) end

	local ctx = {
		udata = udata,
		pn = ffi.new("size_t[1]", n),
		buff = buff,
		process = function (self) return tonumber(self.pn[0]), self.buff end
	};

	return ev_sync_call(libev.ev_write, self, objects.add(ctx), fd, ctx.buff, ctx.pn, offset);
end
--- @param fd ev.fd
--- @param offset integer
--- @param n integer
--- @return string? err
function ev:read(udata, fd, offset, n)
	local ctx = {
		udata = udata,
		pn = ffi.new("size_t[1]", n),
		buff = ffi.new("char[?]", n),
		process = function (self) return ffi.string(self.buff, self.pn[0]) end
	};

	return ev_sync_call(libev.ev_read, self, objects.add(ctx), fd, ctx.buff, ctx.pn, offset);
end
--- @param fd ev.fd
--- @param offset integer
--- @param data string
--- @return string? err
function ev:write(udata, fd, offset, data)
	local ctx = {
		udata = udata,
		pn = ffi.new("size_t[1]", #data),
		buff = ffi.cast("char*", data),
		process = function (self) return tonumber(self.pn[0]) end
	};

	return ev_sync_call(libev.ev_write, self, objects.add(ctx), fd, ctx.buff, ctx.pn, offset);
end
--- @param fd ev.fd
--- @return string? err
function ev:sync(udata, fd)
	local ctx = {
		udata = udata,
		process = function () return true end
	};

	return ev_sync_call(libev.ev_sync, self, objects.add(ctx), fd);
end
--- @param fd ev.fd
--- @return string? err
function ev:stat(udata, fd)
	local ctx = {
		udata = udata,
		pres = ffi.new("ev_stat_t[1]"),
		process = function (self)
			local file_type = "file";
			if self.pres[0].type == 1 then
				file_type = "dir";
			elseif self.pres[0].type == 2 then
				file_type = "link";
			elseif self.pres[0].type == 3 then
				file_type = "sock";
			elseif self.pres[0].type == 4 then
				file_type = "fifo";
			elseif self.pres[0].type == 5 then
				file_type = "char";
			elseif self.pres[0].type == 6 then
				file_type = "blk";
			end

			return {
				type = file_type,
				mode = assert(tonumber(self.pres[0].mode)),
				gid = assert(tonumber(self.pres[0].gid)),
				uid = assert(tonumber(self.pres[0].uid)),
				atime = ev_numify_time(self.pres[0].atime),
				ctime = ev_numify_time(self.pres[0].ctime),
				mtime = ev_numify_time(self.pres[0].mtime),
				size = assert(tonumber(self.pres[0].size)),
				blksize = assert(tonumber(self.pres[0].blksize)),
				inode = assert(tonumber(self.pres[0].inode)),
				links = assert(tonumber(self.pres[0].links)),
			};
		end
	};

	return ev_sync_call(libev.ev_stat, self, objects.add(ctx), fd, ctx.pres);
end
--- @param fd ev.fd
function ev:close(fd)
	return libev.ev_close(self, fd);
end

--- @param path string
--- @param mode? integer | string
--- @return string? err
function ev:mkdir(udata, path, mode)
	if type(mode) == "string" then
		mode = tonumber(mode, 8);
	elseif mode == nil then
		mode = 777;
	end

	local ctx = {
		udata = udata,
		process = function () return true end,
	};

	return ev_sync_call(libev.ev_mkdir, self, objects.add(ctx), path, mode);
end
--- @param path string
--- @return string? err
function ev:opendir(udata, path)
	local ctx = {
		udata = udata,
		pres = ffi.new "ev_dir_t[1]",
		process = function (self)
			return self.pres[0];
		end
	};

	return ev_sync_call(libev.ev_opendir, self, objects.add(ctx), ctx.pres, path);
end
--- @param dir ev.dir
--- @return string? err
function ev:readdir(udata, dir)
	local ctx = {
		udata = udata,
		pres = ffi.new "char*[1]",
		process = function (self)
			if self.pres[0] == ffi.cast("void*", 0) then
				return nil;
			else
				return ffi.string(self.pres[0]);
			end
		end
	};

	return ev_sync_call(libev.ev_readdir, self, objects.add(ctx), dir, ctx.pres);
end
--- @param dir ev.dir
function ev:closedir(dir)
	return libev.ev_closedir(self, dir);
end

--- @param addr string
--- @param port integer
--- @param prot? "tcp" | "udp" = tcp
--- @return string? err
function ev:bind(udata, addr, port, prot, max_n)
	prot = prot or "tcp";

	local real_prot;

	if prot == "tcp" then
		real_prot = 0;
	elseif prot == "udp" then
		real_prot = 1;
	else
		error "invalid proto";
	end

	local real_addr = ev_parse_ip(addr);

	local ctx = {
		udata = udata,
		pres = ffi.new "ev_socket_t[1]",
		process = function (self) return self.pres[0] end
	}

	return ev_sync_call(libev.ev_bind, self, objects.add(ctx), ctx.pres, real_prot, real_addr, port, max_n or 32);
end
--- @param addr string
--- @param port integer
--- @param prot? "tcp" | "udp" = tcp
--- @return string? err
function ev:connect(udata, addr, port, prot)
	prot = prot or "tcp";

	local real_prot;

	if prot == "tcp" then
		real_prot = 0;
	elseif prot == "udp" then
		real_prot = 1;
	else
		error "invalid proto";
	end

	local real_addr = ev_parse_ip(addr);

	local ctx = {
		udata = udata,
		pres = ffi.new "ev_socket_t[1]",
		process = function (self) return self.pres[0] end
	}

	return ev_sync_call(libev.ev_connect, self, objects.add(ctx), ctx.pres, real_prot, real_addr, port);
end
--- @param server ev.socket
--- @return string? err
function ev:accept(udata, server)
	local ctx = {
		udata = udata,
		pclient = ffi.new "ev_socket_t[1]",
		paddr = ffi.new "ev_addr_t[1]",
		pport = ffi.new "uint16_t[1]",
		process = function (self) return self.pclient[0], ev_stringify_ip(self.paddr[0]), assert(tonumber(self.pport[0])) end
	};

	return ev_sync_call(libev.ev_accept, self, objects.add(ctx), ctx.pclient, ctx.paddr, ctx.pport, server);
end
--- @param fd ev.socket
--- @param n integer
--- @param buff? ffi.cdata*
--- @return string? err
function ev:rawrecv(udata, fd, n, buff)
	local ctx = {
		udata = udata,
		pn = ffi.new("size_t[1]", n),
		buff = buff or ffi.new("char[?]", n),
		process = function (self) return tonumber(self.pn[0]), self.buff end
	};

	return ev_sync_call(libev.ev_recv, self, objects.add(ctx), fd, ctx.buff, ctx.pn);
end
--- @param fd ev.socket
--- @param n integer
--- @param buff ffi.cdata* | string
--- @return string? err
function ev:rawsend(udata, fd, n, buff)
	if type(buff) == "string" then buff = ffi.cast("char*", buff) end

	local ctx = {
		udata = udata,
		pn = ffi.new("size_t[1]", n),
		buff = buff,
		process = function (self) return tonumber(self.pn[0]), self.buff end
	};

	return ev_sync_call(libev.ev_send, self, objects.add(ctx), fd, ctx.buff, ctx.pn);
end
--- @param fd ev.socket
--- @param n integer
--- @return string? err
function ev:recv(udata, fd, n)
	local ctx = {
		udata = udata,
		pn = ffi.new("size_t[1]", n),
		buff = ffi.new("char[?]", n),
		process = function (self) return ffi.string(self.buff, self.pn[0]) end
	};

	return ev_sync_call(libev.ev_recv, self, objects.add(ctx), fd, ctx.buff, ctx.pn);
end
--- @param fd ev.socket
--- @param data string
--- @return string? err
function ev:send(udata, fd, data)
	local ctx = {
		udata = udata,
		pn = ffi.new("size_t[1]", #data),
		buff = ffi.cast("char*", data),
		process = function (self) return tonumber(self.pn[0]) end
	};

	return ev_sync_call(libev.ev_send, self, objects.add(ctx), fd, ctx.buff, ctx.pn);
end
--- @param fd ev.socket
function ev:closesock(fd)
	return libev.ev_closesock(self, fd);
end

--- @param name string
--- @param flags? std.net.addrinfo_flags
--- @return string? err
function ev:getaddrinfo(udata, name, flags)
	local real_flags = 0;
	flags = flags or "";

	for c in flags:gmatch "." do
		if c == "4" then
			real_flags = real_flags + 1;
		elseif c == "6" then
			real_flags = real_flags + 2;
		elseif c == "m" then
			real_flags = real_flags + 4;
		elseif c == "b" then
			real_flags = real_flags + 8;
		elseif c == "n" then
			real_flags = real_flags + 16;
		end
	end

	local ctx = {
		udata = udata,
		pres = ffi.new "ev_addrinfo_t[1]",
		process = function (self)
			local res = {};

			for i = 1, assert(tonumber(self.pres[0].n)) do
				table.insert(res, ev_stringify_ip(self.pres[0].addr[i - 1]));
			end

			return res;
		end
	};

	return ev_sync_call(libev.ev_getaddrinfo, self, objects.add(ctx), ctx.pres, name, real_flags);
end

--- @param type "home" | "config" | "data" | "cache" | "runtime" | "cwd"
--- @return string? err
function ev:getpath(udata, type)
	local real_type;

	if type == "home" then
		real_type = 0;
	elseif type == "config" then
		real_type = 1;
	elseif type == "data" then
		real_type = 2;
	elseif type == "cache" then
		real_type = 3;
	elseif type == "runtime" then
		real_type = 4;
	elseif type == "cwd" then
		real_type = 5;
	else
		error "invalid param getpath type";
	end

	local ctx = {
		udata = udata,
		pres = ffi.new "char*[1]",
		process = function (self)
			local res = ffi.string(self.pres[0]);
			libc.free(self.pres[0]);
			return res;
		end
	};

	return ev_sync_call(libev.ev_getpath, self, objects.add(ctx), ctx.pres, real_type);
end

local exec_cache = setmetatable({}, { __mode = "k" });

function ev:exec(udata, func, sig_str, ret_t, ...)
	local sig;
	if exec_cache[func] then
		sig = exec_cache[func];
	else
		local pres = ffi.new "ev_dyn_sig_t[1]";

		local code = libev_dyn.ev_dyn_sig_new(func, sig_str, pres);
		if code ~= 0 then error(ffi.string(libev.ev_strerr(code)), 2) end

		sig = pres[0];
		exec_cache[func] = sig;
	end

	local args = ffi.new("void*[?]", select("#", ...) + 1);

	for i = 1, select("#", ...) do
		local arg = select(i, ...);
		if type(arg) ~= "cdata" then
			error("bad argument #" .. i + 2 .. " (cdata expected)", 2);
		end

		args[i - 1] = ffi.typeof("$[1]", arg, arg);
	end

	local ctx = {
		udata = udata,
		pret = ffi.new("$[1]", ret_t),
		process = function (self) return self.pret[0] end
	};

	local pret = ffi.new("$[1]", ret_t);
	return ev_sync_call(libev.ev_exec, self, objects.add(ctx), libev_dyn.ev_dyn_cb, libev_dyn.ev_dyn_args_new(sig, pret, args));
end

--- @return ev
function ev.new()
	local self = libev.ev_init();
	ev_cbs:set(self, {});
	return self;
end

function ev.realtime()
	local res = ffi.new "ev_time_t[1]";
	local code = libev.ev_realtime(res);
	if code ~= 0 then error(ffi.string(libev.ev_strerr(code)), 2) end

	return assert(tonumber(res[0].sec)) + assert(tonumber(res[0].nsec)) / 1000000000;
end
function ev.monotime()
	local res = ffi.new "ev_time_t[1]";
	local code = libev.ev_monotime(res);
	if code ~= 0 then error(ffi.string(libev.ev_strerr(code)), 2) end

	return assert(tonumber(res[0].sec)) + assert(tonumber(res[0].nsec)) / 1000000000;
end

return ev;

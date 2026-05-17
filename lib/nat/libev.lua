local ffi = require "nat.ffi";
local prop = require "std.field";
local objects = require "nat.utils.objects";
local libc = require "nat.libc";

local libev = ffi.load "ev";
ffi.cdef [[
typedef int64_t off_t;
typedef int ev_code_t;
typedef int ev_signo_t;

void free(void *ptr);

#line 15

typedef struct ev *ev_t;

// Used to deploy a sync workload in an ev-managed thread
typedef int (*ev_worker_t)(void *pargs);

typedef struct ev_hnd *ev_handle_t;
typedef struct ev_server *ev_server_t;
typedef struct ev_dir *ev_dir_t;
typedef struct ev_proc *ev_proc_t;

typedef enum {
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
	// Keeps the file open after an exec() call
	// By default, all files, not marked with this, are closed
	EV_OPEN_SHARED = 64,

	// Doesn't follow symlinks. Useful for statting
	EV_OPEN_NOFOLLOW = 128,
	// Opens the file in statting mode. Mutually-exclusive with READ, WRITE and APPEND and takes precedence over them
	EV_OPEN_STAT= 128,
} ev_open_flags_t;

typedef enum {
	// Use parent's stdio handle (default)
	EV_SPAWN_STD_INHERIT,
	// Create a dummy file descriptor (pipe), store it in the ev_fd_t* argument and use that for the stdio handle
	EV_SPAWN_STD_PIPE,
} ev_spawn_stdio_flags_t;

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

// Adds the two times together
ev_time_t ev_timeadd(ev_time_t a, ev_time_t b);
// Subtracts the two times
ev_time_t ev_timesub(ev_time_t a, ev_time_t b);
// Compares both timestamps, in a strcmp fashion
int ev_timecmp(ev_time_t a, ev_time_t b);
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
// ev_exec implicitly calls this
void ev_begin(ev_t ev);
// Signals to ev that a task has ended. Used to track `ev_busy`
// ev_exec and ev_push implicitly call this
void ev_end(ev_t ev);
// Pushes a result to the message queue. Thread-safe
// NOTE: using the same udata twice is UB
ev_code_t ev_push(ev_t ev, void *udata, ev_code_t err);
// Calls worker with pargs in a ev-managed thread and returns a new ticket to it
// Internally, this is used as a fallback for ops, not supported by AIO
// sync - if true, will side-step the thread pool and will instead call the worker immediately
ev_code_t ev_exec(ev_t ev, void *udata, ev_worker_t worker, void *pargs, bool sync);

// Gets the next message in the message queue, or times out when ptimeout occurs, if not NULL
// You may run this function in three modes: peeking, timed or polling
// - peeking - by setting ptimeout to a time that has already occurred, you effectively check if a message exists, without blocking
// - timed - by setting ptimeout to any future time, the function will either return a message or timeout, hence acting as a timer
// - polling - by setting ptimeout to NULL, the function will never timeout, hence you will be polling for just a message
// If a message was delivered, true is returned. If timed out, false is returned
bool ev_poll(ev_t ev, const ev_time_t *ptimeout, void **pudata, int *perr);

// Returns a reference to the stdin stream
ev_handle_t ev_stdin(ev_t ev);
// Returns a reference to the stdout stream
ev_handle_t ev_stdout(ev_t ev);
// Returns a reference to the stderr stream
ev_handle_t ev_stderr(ev_t ev);


// These are the I/O wrapper functions - they will return 0 on success and a negative errno code on error
// All the other arguments are self-explanatory. All of these functions return their results in a pointer, provided by the callee

// A handle roughly equates to a fd (or a windows HANDLE/socket). Such may be an opened file, socket, tty or a pipe.

// Creates a handle from an OS-specific FD
ev_handle_t ev_handle_new(ev_t ev, uint64_t fd);
// Equivalent to posix's read
ev_code_t ev_read(ev_t ev, void *udata, ev_handle_t stream, char *buff, size_t *pn);
// Equivalent to posix's write
ev_code_t ev_write(ev_t ev, void *udata, ev_handle_t stream, char *buff, size_t *pn);
// Equivalent to posix's sync
ev_code_t ev_sync(ev_t ev, void *udata, ev_handle_t fd);
// Equivalent to posix's stat
ev_code_t ev_stat(ev_t ev, void *udata, ev_handle_t fd, ev_stat_t *buff);

// File-specific functions. They must be exclusively used on handles, generated from ev(s)_file_open.
// Mixing the file and generic RW functions on a file handle will work as expected (the generic handles will read
// the file as a stream, as if the file operations aren't occurring)
// Using a file RW operation on a non-file handle is UB, but will either succeed "weirdly" or fail with an error of an invalid seek. Don't do it!

// Equivalent to posix's open
ev_code_t ev_file_open(ev_t ev, void *udata, ev_handle_t *pres, const char *path, ev_open_flags_t flags, int mode);
// A file-specific read function
ev_code_t ev_file_read(ev_t ev, void *udata, ev_handle_t fd, char *buff, size_t *pn, size_t offset);
// A file-specific write function
ev_code_t ev_file_write(ev_t ev, void *udata, ev_handle_t fd, char *buff, size_t *pn, size_t offset);
// Changes the permissions of the given file
ev_code_t ev_file_chmod(ev_t ev, void *udata, ev_handle_t hnd, int mode);
// Changes the owner of the given file
ev_code_t ev_file_chown(ev_t ev, void *udata, ev_handle_t hnd, int uid, int gid);

// Creates a symbolic link to path at target
ev_code_t ev_file_symlink(ev_t ev, void *udata, const char *src, const char *dst);
// Creates a hard link to the file
ev_code_t ev_file_hardlink(ev_t ev, void *udata, const char *src, const char *dst);
// Reads the given symlink into a malloc'd string
ev_code_t ev_file_readlink(ev_t ev, void *udata, const char *path, char **pres);
// Deletes the given file
ev_code_t ev_file_delete(ev_t ev, void *udata, const char *path);

// Equivalent to posix's mkdir
ev_code_t ev_dir_new(ev_t ev, void *udata, const char *path, int mode);
// Equivalent to posix's opendir
ev_code_t ev_dir_open(ev_t ev, void *udata, ev_dir_t *pres, const char *path);
// Equivalent to posix's readdir
ev_code_t ev_dir_next(ev_t ev, void *udata, ev_dir_t fd, char **pname);

// Unlike posix, I decided it would make sense to split off bound sockets from connected sockets, as the two have completely different usages

// Equivalent to socket() + bind()
ev_code_t ev_server_bind(ev_t ev, void *udata, ev_server_t *pres, ev_proto_t proto, ev_addr_t addr, uint16_t port, size_t max_n);
// Equivalent to posix's accept
ev_code_t ev_server_accept(ev_t ev, void *udata, ev_handle_t *pres, ev_addr_t *paddr, uint16_t *pport, ev_server_t server);

// Equivalent to socket() + connect()
ev_code_t ev_socket_connect(ev_t ev, void *udata, ev_handle_t *pres, ev_proto_t proto, ev_addr_t addr, uint16_t port);

// Equivalent to posix's fork then exec
ev_code_t ev_proc_spawn(
	ev_t ev, void *udata, ev_proc_t *pres,
	const char **argv, const char **env,
	const char *cwd,
	ev_spawn_stdio_flags_t in_flags, ev_handle_t *pin,
	ev_spawn_stdio_flags_t out_flags, ev_handle_t *pout,
	ev_spawn_stdio_flags_t err_flags, ev_handle_t *perr
);
// Equivalent to posix's waitpid
// psig is set to the signal that terminated the child, or -1 if not terminated by a signal
// pcode is set to the exit code of the app, or -1 if child did not exit with a code
ev_code_t ev_proc_wait(ev_t ev, void *udata, ev_proc_t proc, int *psig, int *pcode);

// Equivalent to posix's getaddrinfo (with a few simplifications)
ev_code_t ev_getaddrinfo(ev_t ev, void *udata, ev_addrinfo_t *pres, const char *name, ev_addrinfo_flags_t flags);

// Signal handling utilities. NOTE: these won't correlate to signals 1:1, as signals have a stupid amount of historic baggage
// Activating one logical ev signal might activate multiple OS signals, or none at all. Furthermore, the set of signals you can
// receive has been reduced to ones you will want to receive.

// On windows, signals don't exist, so they are "faked" with other facilities.
// This means that some ev signals will never be produced on windows.

// Activates the given signal for receiving. After this call, wait_sig will receive this signal, when generated, as well
// Internally, both this and ev_sig_off use a refcount, so the two must be called in pairs (calling off is optional,
// but it must be called no more times than on has been called per signal)
ev_code_t ev_sig_on(ev_t ev, ev_signo_t sig);
// Deactivates the given signal and restores its default semantics. After this call, wait_sig will no longer receiv eit
ev_code_t ev_sig_off(ev_t ev, ev_signo_t sig);

// Blocks until the given signal is received.
// NOTE: activating a signal and then not calling sig_wait is equivalent to ignoring it
ev_code_t ev_sig_wait(ev_t ev, void *udata, ev_signo_t *pres);

// These functions give you more or less direct access to the underlying OS I/O functions
// Most of these have async versions, except for environment, path, time and close functions, which aren't meant to be async

ev_code_t evs_read(ev_handle_t fd, char *buff, size_t *pn);
ev_code_t evs_write(ev_handle_t fd, char *buff, size_t *pn);
void evs_close(ev_handle_t fd);

ev_code_t evs_file_open(ev_handle_t *pres, const char *path, ev_open_flags_t flags, int mode);
ev_code_t evs_file_read(ev_handle_t fd, char *buff, size_t *n, size_t offset);
ev_code_t evs_file_write(ev_handle_t fd, char *buff, size_t *n, size_t offset);
ev_code_t evs_file_chmod(ev_handle_t hnd, int mode);
ev_code_t evs_file_chown(ev_handle_t hnd, int uid, int gid);

ev_code_t evs_file_symlink(const char *path, const char *target);
ev_code_t evs_file_hardlink(const char *path, const char *target);
ev_code_t evs_file_readlink(const char *path, char **pres);
ev_code_t evs_file_delete(const char *path);

ev_code_t evs_sync(ev_handle_t fd);
ev_code_t evs_stat(ev_handle_t fd, ev_stat_t *buff);

ev_code_t evs_dir_new(const char *path, int mode);
ev_code_t evs_dir_open(ev_dir_t *pres, const char *path);
ev_code_t evs_dir_next(ev_dir_t dir, char **pname);
void evs_dir_close(ev_dir_t dir);

ev_code_t evs_server_bind(ev_server_t *pres, ev_proto_t proto, ev_addr_t addr, uint16_t port, size_t max_n);
ev_code_t evs_server_accept(ev_handle_t *pres, ev_addr_t *paddr, uint16_t *pport, ev_server_t server);
void evs_server_close(ev_server_t server);

ev_code_t evs_socket_connect(ev_handle_t *pres, ev_proto_t proto, ev_addr_t addr, uint16_t port);

ev_code_t evs_proc_spawn(
	ev_proc_t *pres,
	const char **argv, const char **envp,
	const char *cwd,
	ev_spawn_stdio_flags_t in_flags, ev_handle_t *pin,
	ev_spawn_stdio_flags_t out_flags, ev_handle_t *pout,
	ev_spawn_stdio_flags_t err_flags, ev_handle_t *perr
);
ev_code_t evs_proc_wait(ev_proc_t proc, int *psig, int *pcode);

ev_code_t evs_getaddrinfo(ev_addrinfo_t *pres, const char *name, ev_addrinfo_flags_t flags);
// Gets a malloc'd string, representing the requested path
ev_code_t evs_getpath(char **pres, ev_path_type_t type);

// Gets an env variable from the current process
ev_code_t evs_getenv(const char *name, char **pres);
// Sets an env variable in the current process (if val is NULL, unsets it)
ev_code_t evs_setenv(const char *name, const char *val);
// Iterates all key-value env pairs and sets them to pit, as "KEY=VAL\0"
// pit contains impl-specific iteration data. Passing the pointer, stored after an iteration more than once is UB
// ppair is used to save the current pair, or NULL if the end of the list is reached
// Modifying of the environment in between iterations leads to UB, and generally is a very, very bad idea
ev_code_t evs_nextenv(void **pit, const char **ppair);

// Gets the time, elapsed since the unix epoch (CLOCK_REALTIME)
ev_code_t evs_realtime(ev_time_t *pres);
// Gets a reliably and monotonically ticking time, unaffected by the system time (CLOCK_MONOTONIC)
// You should use this instead of `ev_realtime` when dealing with ev_poll's timeouts, and in general,
// when you care about time offsets more than the actual current time, which is almost always the case
ev_code_t evs_monotime(ev_time_t *pres);

// Sleeps until the monotone timestamp provided occurs
void evs_sleep(ev_time_t time);

// Blocks until the given signal is received.
// NOTE: activating a signal and then not calling sig_wait is equivalent to ignoring it
ev_code_t evs_sig_wait(ev_signo_t *pres);
]];

local ev_cbs = prop();

--- @class ev.handle: ffi.cdata*
--- @class ev.file: ev.handle
--- @class ev.server: ffi.cdata*
--- @class ev.dir: ffi.cdata*
--- @class ev.proc: ffi.cdata*

--- @alias ev.callback thread | fun(val: integer)

--- @class ev: ffi.cdata*
local ev = {};
ev.__index = ev;
function ev:__gc()
	libev.ev_free(self);
end
ev._ctype = ffi.metatype("struct ev", ev);

--- @param func function
--- @param self ev
--- @return boolean sync
--- @return ...
local function ev_sync_call(func, self, obj, ...)
	local code = func(self, ffi.cast("void*", objects.add(obj)), ...);
	if code ~= 0 then return true, nil, ffi.string(libev.ev_strerr(code)) end
	return false;
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
--- @param timeout? number
--- @return any? udata
--- @return ...
function ev:next(timeout)
	local ptimeout = nil;
	if timeout then
		ptimeout = ffi.new "ev_time_t[1]";
		ptimeout[0].sec = math.floor(timeout);
		ptimeout[0].nsec = (timeout - math.floor(timeout)) * 1000000000;
	end

	local pudata = ffi.new "void*[1]";
	local perr = ffi.new "int[1]";

	if libev.ev_poll(self, ptimeout, pudata, perr) then
		local iudata = assert(tonumber(ffi.cast("size_t", pudata[0])));

		local ctx = objects.get(iudata);
		assert(type(ctx) == "table", "invalid udata");
		objects.del(iudata);

		if perr[0] == 0 then
			if ctx.get_args then
				return ctx.udata, ctx:get_args();
			else
				return ctx.udata, true;
			end
		else
			return ctx.udata, nil, ffi.string(libev.ev_strerr(tonumber(perr[0]))), tonumber(perr[0]);
		end
	else
		return nil;
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

--- @param fd integer
--- @return ev.handle handle
function ev:handle_new(fd)
	return libev.ev_handle_new(self, fd);
end
--- @param fd ev.handle
--- @param n integer
--- @param buff? ffi.cdata*
--- @return boolean sync
--- @return integer? n
--- @return string? err
function ev:read(udata, fd, n, buff)
	local ctx = {
		udata = udata,
		pn = ffi.new("size_t[1]", n),
		buff = buff or ffi.new("char[?]", n),
		get_args = function (self) return tonumber(self.pn[0]) end
	};

	return ev_sync_call(libev.ev_read, self, ctx, fd, ctx.buff, ctx.pn);
end
--- @param fd ev.handle
--- @param n integer
--- @param buff ffi.cdata* | string
--- @return boolean sync
--- @return integer? n
--- @return string? err
function ev:write(udata, fd, n, buff)
	if type(buff) == "string" then buff = ffi.cast("char*", buff) end

	local ctx = {
		udata = udata,
		pn = ffi.new("size_t[1]", n),
		buff = buff,
		get_args = function (self) return tonumber(self.pn[0]) end
	};

	return ev_sync_call(libev.ev_write, self, ctx, fd, ctx.buff, ctx.pn);
end
--- @param fd ev.handle
--- @return boolean sync
--- @return true? ok
--- @return string? err
function ev:sync(udata, fd)
	local ctx = {
		udata = udata,
		get_args = function () return true end
	};

	return ev_sync_call(libev.ev_sync, self, ctx, fd);
end
--- @param fd ev.handle
--- @return boolean sync
--- @return std.io.stat? stat
--- @return string? err
function ev:stat(udata, fd)
	local ctx = {
		udata = udata,
		pres = ffi.new("ev_stat_t[1]"),
		get_args = function (self)
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

	return ev_sync_call(libev.ev_stat, self, ctx, fd, ctx.pres);
end
--- @param fd ev.handle
function ev:close(fd)
	return libev.evs_close(fd);
end

--- @param path string
--- @param flags std.io.open_flags
--- @param mode? integer | string
--- @return boolean sync
--- @return ev.file? file
--- @return string? err
function ev:file_open(udata, path, flags, mode)
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
		elseif c == "l" then
			real_flags = real_flags + 128;
		elseif c == "s" then
			real_flags = real_flags + 256;
		end
	end

	if type(mode) == "string" then
		mode = tonumber(mode, 8);
	elseif mode == nil then
		mode = 777;
	end

	local ctx = {
		udata = udata,
		pres = ffi.new "ev_handle_t[1]",
		get_args = function (self) return self.pres[0] end
	};

	return ev_sync_call(libev.ev_file_open, self, ctx, ctx.pres, path, real_flags, mode);
end
--- @param fd ev.handle
--- @param offset integer
--- @param n integer
--- @param buff ffi.cdata*
--- @return boolean sync
--- @return integer? n
--- @return string? err
function ev:file_read(udata, fd, offset, n, buff)
	local ctx = {
		udata = udata,
		pn = ffi.new("size_t[1]", n),
		buff = buff or ffi.new("char[?]", n),
		get_args = function (self) return tonumber(self.pn[0]) end
	};

	return ev_sync_call(libev.ev_file_read, self, ctx, fd, ctx.buff, ctx.pn, offset);
end
--- @param fd ev.handle
--- @param offset integer
--- @param n integer
--- @param buff ffi.cdata* | string
--- @return boolean sync
--- @return integer? n
--- @return string? err
function ev:file_write(udata, fd, offset, n, buff)
	if type(buff) == "string" then buff = ffi.cast("char*", buff) end

	local ctx = {
		udata = udata,
		pn = ffi.new("size_t[1]", n),
		buff = buff,
		get_args = function (self) return tonumber(self.pn[0]) end
	};

	return ev_sync_call(libev.ev_file_write, self, ctx, fd, ctx.buff, ctx.pn, offset);
end
--- @param fd ev.handle
--- @param mode integer
--- @return boolean sync
--- @return integer? n
--- @return string? err
function ev:file_chmod(udata, fd, mode)
	local ctx = {
		udata = udata,
		get_args = function () return true end
	};

	return ev_sync_call(libev.ev_file_chmod, self, ctx, fd, mode);
end
--- @param fd ev.handle
--- @param uid integer
--- @param gid integer
--- @return boolean sync
--- @return integer? n
--- @return string? err
function ev:file_chown(udata, fd, uid, gid)
	local ctx = {
		udata = udata,
		get_args = function () return true end
	};

	return ev_sync_call(libev.ev_file_chown, self, ctx, fd, uid, gid);
end

--- @param src string
--- @param dst string
--- @return boolean sync
--- @return integer? n
--- @return string? err
function ev:file_symlink(udata, src, dst)
	local ctx = {
		udata = udata,
		keep_path = src,
		keep_target = dst,
		get_args = function () return true end
	};

	return ev_sync_call(libev.ev_file_symlink, self, ctx, src, dst);
end
--- @param src string
--- @param dst string
--- @return boolean sync
--- @return integer? n
--- @return string? err
function ev:file_hardlink(udata, src, dst)
	local ctx = {
		udata = udata,
		keep_target = dst,
		get_args = function () return true end
	};

	return ev_sync_call(libev.ev_file_hardlink, self, ctx, src, dst);
end
--- @param path string
--- @return boolean sync
--- @return integer? n
--- @return string? err
function ev:file_readlink(udata, path)
	local ctx = {
		udata = udata,
		pres = ffi.new "char*[1]",
		keep_path = path,
		get_args = function (self)
			local res = ffi.string(self.pres[0], libc.strlen(self.pres[0]));
			libc.free(self.pres[0]);
			return res;
		end
	};

	return ev_sync_call(libev.ev_file_readlink, self, ctx, path, ctx.pres);
end
--- @param path string
--- @return boolean sync
--- @return integer? n
--- @return string? err
function ev:file_delete(udata, path)
	local ctx = {
		udata = udata,
		get_args = function () return true end
	};

	return ev_sync_call(libev.ev_file_delete, self, ctx, path);
end

--- @param path string
--- @param mode? integer | string
--- @return boolean sync
--- @return true? ok
--- @return string? err
function ev:dir_new(udata, path, mode)
	local ctx = {
		udata = udata,
		get_args = function () return true end
	};

	return ev_sync_call(libev.ev_dir_new, self, ctx, path, mode);
end
--- @param path string
--- @return boolean sync
--- @return ev.dir? dir
--- @return string? err
function ev:dir_open(udata, path)
	local ctx = {
		udata = udata,
		pres = ffi.new "ev_dir_t[1]",
		get_args = function (self)
			return self.pres[0];
		end
	};

	return ev_sync_call(libev.ev_dir_open, self, ctx, ctx.pres, path);
end
--- @param dir ev.dir
--- @return boolean sync
--- @return string? name
--- @return string? err
function ev:dir_next(udata, dir)
	local ctx = {
		udata = udata,
		pres = ffi.new "char*[1]",
		get_args = function (self)
			if self.pres[0] == ffi.cast("void*", 0) then
				return nil;
			else
				return ffi.string(self.pres[0]);
			end
		end
	};

	return ev_sync_call(libev.ev_dir_next, self, ctx, dir, ctx.pres);
end
--- @param dir ev.dir
function ev:dir_close(dir)
	return libev.evs_dir_close(dir);
end

--- @param addr string
--- @param port integer
--- @param prot "tcp" | "udp"
--- @param max_n integer
--- @return boolean sync
--- @return ev.server? server
--- @return string? err
function ev:server_bind(udata, addr, port, prot, max_n)
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
		pres = ffi.new "ev_server_t[1]",
		get_args = function (self) return self.pres[0] end
	}

	return ev_sync_call(libev.ev_server_bind, self, ctx, ctx.pres, real_prot, real_addr, port, max_n);
end
--- @param server ev.server
--- @return boolean sync
--- @return { client: ev.handle, ip: string, port: integer }? res
--- @return string? err
function ev:server_accept(udata, server)
	local ctx = {
		udata = udata,
		pclient = ffi.new "ev_handle_t[1]",
		paddr = ffi.new "ev_addr_t[1]",
		pport = ffi.new "uint16_t[1]",
		get_args = function (self)
			return {
				client = self.pclient[0],
				ip = ev_stringify_ip(self.paddr[0]),
				port = assert(tonumber(self.pport[0]))
			};
		end
	};

	return ev_sync_call(libev.ev_server_accept, self, ctx, ctx.pclient, ctx.paddr, ctx.pport, server);
end
--- @param fd ev.server
function ev:server_close(fd)
	return libev.evs_server_close(fd);
end
--- @param addr string
--- @param port integer
--- @param prot? "tcp" | "udp" = tcp
--- @return boolean sync
--- @return ev.handle? client
--- @return string? err
function ev:socket_connect(udata, addr, port, prot)
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
		pres = ffi.new "ev_handle_t[1]",
		get_args = function (self) return self.pres[0] end
	}

	return ev_sync_call(libev.ev_socket_connect, self, ctx, ctx.pres, real_prot, real_addr, port);
end

local function proc_fix_stdarg(stdarg)
	if stdarg == "inherit" then
		return 0, nil;
	elseif stdarg == "pipe" then
		return 1, ffi.new "ev_handle_t[1]";
	end
end

--- @param argv string[]
--- @param env { [string]: string, [integer]: { [1]: string, [2]: string } }
--- @param stdin? "pipe" | "inherit"
--- @param stdout? "pipe" | "inherit"
--- @param stderr? "pipe" | "inherit"
--- @return boolean sync
--- @return { proc: ev.proc, stdin?: ev.handle, stdout?: ev.handle, stderr?: ev.handle }?
--- @return string? err
function ev:proc_spawn(udata, argv, env, cwd, stdin, stdout, stderr)
	local in_flag, out_flag, err_flag;

	local ctx = {
		udata = udata,
		pres = ffi.new "ev_proc_t[1]",
		keep_str = {},
		get_args = function (self)
			return {
				proc = self.pres[0],
				stdin = in_flag == 1 and self.pin[0] or nil,
				stdout = out_flag == 1 and self.pout[0] or nil,
				stderr = err_flag == 1 and self.perr[0] or nil,
			};
		end
	}

	local function strdup(str)
		local res = libc.malloc(#str + 1);
		ffi.copy(res, str);
		table.insert(ctx.keep_str, res);
		return res;
	end

	ctx.argv = ffi.new("const char*[?]", #argv + 1);
	for i = 1, #argv do
		ctx.argv[i - 1] = strdup(argv[i]);
	end
	ctx.argv[#argv] = nil;
	ctx.keep_argv = argv;

	local env_n = 0;

	if env then
		for k in pairs(env) do
			if type(k) ~= "number" then
				env_n = env_n + 1;
			end
		end

		ctx.envp = ffi.new("const char*[?]", #env + env_n + 1);
		local env_i = #env;
		for k, v in pairs(env) do
			if type(k) ~= "number" then
				ctx.envp[env_i] = strdup(k .. "=" .. v);
				env_i = env_i + 1;
			else
				ctx.envp[k - 1] = strdup(v[0] .. "=" .. v[1]);
			end
		end
		ctx.envp[#env + env_n] = nil;
		ctx.keep_env = env;
	end

	ctx.keep_cwd = cwd;

	in_flag, ctx.pin = proc_fix_stdarg(stdin);
	out_flag, ctx.pout = proc_fix_stdarg(stdout);
	err_flag, ctx.perr = proc_fix_stdarg(stderr);

	return ev_sync_call(libev.ev_proc_spawn, self, ctx, ctx.pres, ctx.argv, ctx.envp, cwd, in_flag, ctx.pin, out_flag, ctx.pout, err_flag, ctx.perr);
end
--- @param proc ev.proc
--- @return boolean sync
--- @return "sig" | "exit"? kind
--- @return string | integer? err_or_code
function ev:proc_wait(udata, proc)
	local ctx = {
		udata = udata,
		pcode = ffi.new "int[1]",
		psig = ffi.new "int[1]",
		get_args = function (self)
			local code, sig = self.pcode[0], self.psig[0];

			if sig >= 0 then return "sig", sig end
			if code >= 0 then return "exit", code end
			return "int";
		end
	}

	return ev_sync_call(libev.ev_proc_wait, self, ctx, proc, ctx.pcode, ctx.psig);
end

--- @param name string
--- @param flags? std.io.net.addrinfo_flags
--- @return boolean sync
--- @return string[]? names
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
		get_args = function (self)
			local res = {};

			for i = 1, assert(tonumber(self.pres[0].n)) do
				table.insert(res, ev_stringify_ip(self.pres[0].addr[i - 1]));
			end

			return res;
		end
	};

	return ev_sync_call(libev.ev_getaddrinfo, self, ctx, ctx.pres, name, real_flags);
end

--- @param sig integer
--- @return true? ok
--- @return string? err
function ev:sig_on(sig)
	local code = libev.ev_sig_on(self, sig);
	if code ~= 0 then return nil, ffi.string(libev.ev_strerr(code)) end

	return true;
end
--- @param sig integer
--- @return true? ok
--- @return string? err
function ev:sig_off(sig)
	local code = libev.ev_sig_off(self, sig);
	if code ~= 0 then return nil, ffi.string(libev.ev_strerr(code)) end

	return true;
end
--- @return boolean sync
--- @return integer? sig
--- @return string? err
function ev:sig_wait(udata)
	local ctx = {
		udata = udata,
		pres = ffi.new "ev_signo_t[1]",
		get_args = function (self) return tonumber(self.pres[0]) end
	};

	return ev_sync_call(libev.ev_sig_wait, self, ctx, ctx.pres);
end

--- @return ev
function ev.new()
	local self = libev.ev_init();
	ev_cbs:set(self, {});
	return self;
end

function ev.realtime()
	local res = ffi.new "ev_time_t[1]";
	local code = libev.evs_realtime(res);
	if code ~= 0 then error(ffi.string(libev.ev_strerr(code)), 2) end

	return assert(tonumber(res[0].sec)) + assert(tonumber(res[0].nsec)) / 1000000000;
end
function ev.monotime()
	local res = ffi.new "ev_time_t[1]";
	local code = libev.evs_monotime(res);
	if code ~= 0 then error(ffi.string(libev.ev_strerr(code)), 2) end

	return assert(tonumber(res[0].sec)) + assert(tonumber(res[0].nsec)) / 1000000000;
end

--- @param type "home" | "config" | "data" | "cache" | "runtime" | "cwd"
--- @return string? val
--- @return string? err
function ev.getpath(type)
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

	local pres = ffi.new "char*[1]";

	local code = libev.evs_getpath(pres, real_type);
	if code ~= 0 then return nil, ffi.string(libev.ev_strerr(code)) end

	local res = ffi.string(pres[0]);
	libc.free(pres[0]);
	return res;
end
--- @param name string
--- @return string? val
--- @return string? err
function ev.getenv(name)
	local pres = ffi.new "char*[1]";

	local code = libev.evs_getenv(name, pres);
	if code ~= 0 then return nil, ffi.string(libev.ev_strerr(code)) end

	local res = ffi.string(pres[0]);
	libc.free(pres[0]);
	return res;
end
--- @param name string
--- @param val string
--- @return true?
--- @return string? err
function ev.setenv(name, val)
	local code = libev.evs_setenv(name, name, val);
	if code ~= 0 then return nil, ffi.string(libev.ev_strerr(code)) end
	return true;
end
--- @return string? pair
--- @return string? err
function ev.nextenv(pit)
	local pres = ffi.new "char *[1]";

	local code = libev.evs_nextenv(pit, pres);
	if code ~= 0 then return nil, ffi.string(libev.ev_strerr(code)) end

	local res = ffi.string(pres[0]);
	libc.free(pres[0]);
	return res;
end
function ev.iterenv()
	return ev.nextenv, ffi.new "void *[1]";
end

return ev;

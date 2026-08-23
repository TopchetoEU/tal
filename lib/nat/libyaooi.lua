local ffi = require "nat.ffi";
local libc = require "nat.libc";
local errors = require "std.errors";
local field  = require "std.field";

local error = errors.ierror;

local yaooi = {};

local libyaooi = ffi.load "yaooi";
ffi.cdef [[
typedef int yo_code_t;
typedef int yo_signo_t;

#line 8 yaooi/addr.h
typedef enum {
	YO_ADDR_IPV4,
	YO_ADDR_IPV6,
	// TODO: bluetooth maybe?
} yo_addr_type_t;
typedef struct {
	yo_addr_type_t type;
	union {
		uint8_t v4[4];
		uint16_t v6[8];
	};
} yo_addr_t;

// Parses the string to an IP address (ipv4/6 auto-detected)
bool yo_addrparse(const char *str, yo_addr_t *pres);
// Returns true if both addresses are equal
bool yo_addrcmp(yo_addr_t a, yo_addr_t b);


#line 8 yaooi/time.h
typedef struct {
	int64_t sec;
	uint32_t nsec;
} yo_time_t;

// Adds the two times together
yo_time_t yo_timeadd(yo_time_t a, yo_time_t b);
// Subtracts the two times
yo_time_t yo_timesub(yo_time_t a, yo_time_t b);
// Compares both timestamps, in a strcmp fashion
int yo_timecmp(yo_time_t a, yo_time_t b);
// Converts the time to a millisecond count
int64_t yo_timems(yo_time_t time);

typedef enum {
	YO_CLOCK_REAL,
	YO_CLOCK_MONO,
	YO_CLOCK_CPU,
} yo_clock_t;

// Gets the current monotonic time
yo_time_t yo_time(yo_clock_t clock);
// Blocks until the monotonic time is greater than `until`
void yo_timesleep(yo_time_t until);

#line 108 yaooi/errno.h
// Converts the error code to a human-readable string
const char *yo_strerr(yo_code_t code);

#line 9 yaooi/queue.h
// Used to deploy a sync workload in an ev-managed thread
typedef int (*yo_worker_t)(void *pargs);

// A structure, keeping track of all pending operations and results
typedef struct yo_queue *yo_queue_t;
// A generic request in the queue
typedef struct yo_req *yo_req_t;

yo_queue_t yo_queue_new();
// Cancels all requests and frees all associated resources
void yo_queue_free(yo_queue_t queue);
// Gets the next completed request in the queue, or blocks until one is available
// - If `pdeadline` is not NULL, limits the block time until the monotonic time is reached
// - If `pdeadline` was reached before a result was pushed, NULL is stored in pres
// - If `pdeadline` is before the current moment, returns immediatly.
// A good way to non-blockingly poll is to pass yo_monotime() to `pdeadline`
yo_code_t yo_queue_poll(yo_queue_t queue, const yo_time_t *pdeadline, yo_req_t *preq, yo_code_t *pcode);

// Inserts a new request in the queue and returns it
yo_req_t yo_req_new(yo_queue_t queue);

// Executes the function in a thread pool returns its value via the request
// The function must return YO_EINTR, if it has been interrupted. This is interpreted as a cancellation
yo_code_t yo_req_exec(yo_req_t req, yo_worker_t worker, void *pargs);

// Cancels the request and removes it from the queue. If it is an IO operation, cancels it in the OS-appropriate way
void yo_req_cancel(yo_req_t req);
// Cancels the request and frees all associated resources
void yo_req_free(yo_req_t req);

#line 15 yaooi/io.h
typedef enum {
	// Opens the file in read mode
	YO_OPEN_READ = 1,
	// Opens the file in write mode
	YO_OPEN_WRITE = 2,
	// Opens the file in append mode (implies WRITE)
	YO_OPEN_APPEND = 4,

	// Creates the file if it doesn't exist
	YO_OPEN_CREATE = 8,
	// Empties the contents of the file if it exists
	YO_OPEN_TRUNC = 16,
	// Opens the file in direct mode
	YO_OPEN_DIRECT = 32,
	// Keeps the file open after an exec() call
	// By default, all files, not marked with this, are closed
	YO_OPEN_SHARED = 64,

	// Doesn't follow symlinks. Useful for statting
	YO_OPEN_NOFOLLOW = 128,
	// Opens the file in statting mode. Mutually-exclusive with READ, WRITE and APPEND and takes precedence over them
	YO_OPEN_STAT= 128,
} yo_open_flags_t;
typedef enum {
	// Valid on windows only, does not escape arguments
	// Used only to allow cmd /c command. Thanks windows, very cool!
	YO_SPAWN_NOESCAPE,
} yo_spawn_flags_t;
typedef enum {
	YO_PATH_HOME,
	YO_PATH_CONFIG,
	YO_PATH_DATA,
	YO_PATH_CACHE,
	YO_PATH_RUNTIME,
	YO_PATH_CWD,
} yo_path_type_t;
typedef enum {
	YO_PROTO_TCP,
	YO_PROTO_UDP,
} yo_proto_t;
typedef enum {
	YO_TTY_NORMAL,
	YO_TTY_RAW,
} yo_tty_mode_t;

typedef struct {
	enum {
		YO_STAT_REG,
		YO_STAT_DIR,
		YO_STAT_LINK,
		YO_STAT_SOCK,
		YO_STAT_FIFO,
		YO_STAT_CHAR,
		YO_STAT_BLK,
	} type;
	uint32_t mode;
	uint32_t gid;
	uint32_t uid;

	yo_time_t atime, mtime, ctime;

	uint64_t size;
	uint32_t blksize;

	uint64_t inode;
	uint32_t links;
} yo_stat_t;

// A handle roughly equates to a fd (or a windows HANDLE/socket). Such may be an opened file, socket, tty or a pipe.
typedef struct yo_fd *yo_fd_t;

// Creates a handle from an OS-specific FD
// If owned is false, the file won't actually be closed by yo_fd_close()
yo_code_t yo_fd_new(yo_fd_t *pres, uint64_t fd, bool owned);
// Cancels all requests, associated to the handle and releases all resources, used by the `req`
void yo_fd_close(yo_fd_t fd);

// Equivalent to posix's read
yo_code_t yo_read(yo_fd_t fd, char *buff, size_t *pn);
// Equivalent to posix's write
yo_code_t yo_write(yo_fd_t fd, char *buff, size_t *pn);
// Equivalent to posix's sync
yo_code_t yo_sync(yo_fd_t fd);
// Equivalent to posix's stat
yo_code_t yo_stat(yo_fd_t fd, yo_stat_t *buff);

typedef struct yo_tty_raw *yo_tty_raw_t;

// Initializes `tty` to a refrence to `stdin`
yo_code_t yo_tty_in(yo_fd_t *pres);
// Initializes `tty` to a refrence to `stdout`
yo_code_t yo_tty_out(yo_fd_t *pres);
// Initializes `tty` to a refrence to `stderr`
yo_code_t yo_tty_err(yo_fd_t *pres);
// Begins a raw mode of the tty. yo_tty_rawend must be called on yo_tty_raw_t, stored in pres, to end the raw mode
// Make sure to do that, as we are not calling that for you upon exit!
yo_code_t yo_tty_raw(yo_fd_t tty, yo_tty_raw_t *pres);
// Restores the given raw mode to the previous mode of the underlying TTY. This may be another raw mode
yo_code_t yo_tty_rawend(yo_tty_raw_t rawmode);

// Deletes the given file or directory. Fails if directory is not empty
yo_code_t yo_file_remove(const char *path);
// Creates a symbolic link to path at target
yo_code_t yo_file_symlink(const char *src, const char *dst);
// Creates a hard link to the file
yo_code_t yo_file_hardlink(const char *src, const char *dst);
// Reads the given symlink into a malloc'd string
yo_code_t yo_file_readlink(const char *path, char **pres);

// Although on linux, files are blocking, the file functions are async, because they may block for a long time
// (for example, if the file lives on an NFS or FUSE filesystem)

// Equivalent to posix's open
yo_code_t yo_file_open(yo_fd_t *pres, const char *path, yo_open_flags_t flags, int mode);
// A file-specific read function
yo_code_t yo_file_read(yo_fd_t fd, char *buff, size_t *pn, size_t offset);
// A file-specific write function
yo_code_t yo_file_write(yo_fd_t fd, char *buff, size_t *pn, size_t offset);
// Changes the permissions of the given file
yo_code_t yo_file_chmod(yo_fd_t fd, int mode);
// Changes the owner of the given file
yo_code_t yo_file_chown(yo_fd_t fd, int uid, int gid);

typedef struct yo_dir *yo_dir_t;
// Equivalent to posix's mkdir
yo_code_t yo_dir_new(const char *path, int mode);
// Equivalent to posix's opendir
yo_code_t yo_dir_open(yo_dir_t *pres, const char *path);
// Equivalent to posix's readdir
yo_code_t yo_dir_next(yo_dir_t dir, char **pname);
// Equivalent to posix's closedir
void yo_dir_close(yo_dir_t dir);

// Equivalent to connect()
yo_code_t yo_socket_connect(yo_fd_t *pres, yo_proto_t proto, yo_addr_t addr, uint16_t port);
// Equivalent to bind()
yo_code_t yo_socket_bind(yo_fd_t *pres, yo_proto_t proto, yo_addr_t addr, uint16_t port, size_t max_n);
// Equivalent to accept()
yo_code_t yo_socket_accept(yo_fd_t server, yo_fd_t *pres, yo_addr_t *paddr, uint16_t *pport);

typedef struct {
	size_t n;
	yo_addr_t addr[];
} *yo_addrinfo_t;
typedef enum {
	// Resolves only ipv4 (if neither this nor YO_AI_IPV6 are specified, resolves both)
	YO_AI_IPV4 = 1,
	// Resolves only ipv6 (this is mutually-exclusive with IPV4, and this will override IPV4)
	YO_AI_IPV6 = 2,
	// If no IPV6 address was found, but an IPV4 address was, resolves as an ipv6 mapping of the ipv4 address
	YO_AI_IPV4_MAPPED = 4,
	// Resolves to a bindable address - mostly applicable when name is NULL (equivalent to AI_PASSIVE)
	YO_AI_BIND = 8,
	// Resolves only IP addresses - does not make DNS requests (equivalent to AI_NUMERICHOST)
	YO_AI_NODNS = 16,
} yo_addrinfo_flags_t;

// Equivalent to posix's getaddrinfo (with a few simplifications)
yo_code_t yo_dns_getaddrinfo(yo_addrinfo_t *pres, const char *name, yo_addrinfo_flags_t flags);

typedef struct yo_proc *yo_proc_t;

// Equivalent to posix's fork then exec
yo_code_t yo_proc_spawn(
	yo_proc_t *pres, yo_spawn_flags_t flags,
	const char **argv, const char **env, const char *cwd,
	yo_fd_t *pin, yo_fd_t *pout, yo_fd_t *perr
);
// Equivalent to posix's waitpid
// Will free all resources, associated with proc
// psig is set to the signal that terminated the child, or -1 if not terminated by a signal
// pcode is set to the exit code of the app, or -1 if child did not exit with a code
yo_code_t yo_proc_wait(yo_proc_t proc, int *psig, int *pcode);
// Immeditely releases all resources, associated with tracking the process, effectively daemonizing it.
// On unix-like systems, this will initialize a process-wide reaper (if not initialized yet) and put the child in the reaper's list
// Upon our process's exit, as per unix rules, the child will daemonize
yo_code_t yo_proc_disown(yo_proc_t proc);

// Signal handling utilities. NOTE: these won't correlate to signals 1:1, as signals have a stupid amount of historic baggage
// Activating one logical ev signal might activate multiple OS signals, or none at all. Furthermore, the set of signals you can
// receive has been reduced to ones you will want to receive.

// On windows, signals don't exist, so they are "faked" with other facilities.
// This means that some ev signals will never be produced on windows.

// Activates the given signal for receiving. After this call, wait_sig will receive this signal, when generated, as well
// Internally, both this and yo_sig_off use a refcount, so the two must be called in pairs (calling off is optional,
// but it must be called no more times than on has been called per signal)
yo_code_t yo_sig_on(yo_signo_t sig);
// Deactivates the given signal and restores its default semantics. After this call, wait_sig will no longer receiv eit
yo_code_t yo_sig_off(yo_signo_t sig);
// Blocks until the given signal is received.
// NOTE: activating a signal and then not calling sig_wait is equivalent to ignoring it
yo_code_t yo_sig_wait(yo_signo_t *pres);

// Gets a malloc'd string, representing the requested path
yo_code_t yo_getpath(yo_path_type_t type, char **pres);

// Gets an env variable from the current process
yo_code_t yo_env_get(const char *name, char **pres);
// Sets an env variable in the current process (if val is NULL, unsets it)
yo_code_t yo_env_set(const char *name, const char *val);

typedef struct yo_enviter *yo_enviter_t;
// Initializes an iterator of the env variables
yo_enviter_t yo_enviter_new();
// Gets the next env variable from the iterator
yo_code_t yo_enviter_next(yo_enviter_t iter, const char **pres);
void yo_enviter_close(yo_enviter_t iter);

#line 10 yaooi/ioq.h
// Here, queue versions of some functions are presented
// Those that don't have queue equivalents should be used only synchronously

// On linux, some of these are 'technically' blocking-only. However, this design is retarded,
// as network-based FS-es will gladly block for minutes when the underlying connection is lost.
// If that happens, our app would block for minutes as well, rendering the queue system rather useless.
// Underneath, blocking-only ops are run on a thread pool

// Poignant language here used because i am a victim of this "great" design of linux. Thanks, linus!

yo_code_t yoa_read(yo_req_t req, yo_fd_t fd, char *buff, size_t *pn);
yo_code_t yoa_write(yo_req_t req, yo_fd_t fd, char *buff, size_t *pn);
yo_code_t yoa_sync(yo_req_t req, yo_fd_t fd);
yo_code_t yoa_stat(yo_req_t req, yo_fd_t fd, yo_stat_t *buff);

yo_code_t yoa_file_remove(yo_req_t req, const char *path);
yo_code_t yoa_file_symlink(yo_req_t req, const char *src, const char *dst);
yo_code_t yoa_file_hardlink(yo_req_t req, const char *src, const char *dst);
yo_code_t yoa_file_readlink(yo_req_t req, const char *path, char **pres);

// yo_code_t yoa_file_open(yo_req_t req, yo_filelist_t fl, yo_fd_t *pres, const char *path, yo_open_flags_t flags, int mode);
yo_code_t yoa_file_read(yo_req_t req, yo_fd_t fd, char *buff, size_t *pn, size_t offset);
yo_code_t yoa_file_write(yo_req_t req, yo_fd_t fd, char *buff, size_t *pn, size_t offset);

yo_code_t yoa_dir_new(yo_req_t req, const char *path, int mode);
yo_code_t yoa_dir_open(yo_req_t req, yo_dir_t *pres, const char *path);
yo_code_t yoa_dir_next(yo_req_t req, yo_dir_t dir, char **pname);

yo_code_t yoa_socket_connect(yo_req_t req, yo_fd_t *pclient, yo_proto_t proto, yo_addr_t addr, uint16_t port);
yo_code_t yoa_socket_accept(yo_req_t req, yo_fd_t server, yo_fd_t *pclient, yo_addr_t *paddr, uint16_t *pport);

yo_code_t yoa_dns_getaddrinfo(yo_req_t req, yo_addrinfo_t *pres, const char *name, yo_addrinfo_flags_t flags);

yo_code_t yoa_proc_wait(yo_req_t req, yo_proc_t proc, int *psig, int *pcode);

yo_code_t yoa_sig_wait(yo_req_t req, yo_signo_t *pres);
#line 344
]];


local function addrparse(ip)
	local pres = ffi.new "yo_addr_t[1]";
	if not libyaooi.yo_addrparse(ip, pres) then error "invalid address" end
	return pres[0];
end
local function addrstr(addr)
	if addr.type == 0 then
		return ("%d.%d.%d.%d"):format(addr.v4[0], addr.v4[1], addr.v4[2], addr.v4[3]);
	elseif addr.type == 1 then
		return ("%x:%x:%x:%x:%x:%x:%x:%x"):format(
			addr.v6[0], addr.v6[1], addr.v6[2], addr.v6[3],
			addr.v6[4], addr.v6[5], addr.v6[6], addr.v6[7]
		);
	end
end

local function timenum(time)
	return assert(tonumber(time.sec)) + assert(tonumber(time.nsec)) / 1000000000;
end

local function yo_assert(code)
	if code ~= 0 then error(ffi.string(libyaooi.yo_strerr(code))) end
end

--- @class libyaooi.req: ffi.cdata*
yaooi.req = {};
yaooi.req.__index = yaooi.req;
yaooi.req.__metatable = "libyaooi.req";
local req_type = ffi.metatype("struct yo_req", yaooi.req);
local req_udata = field();
local req_getres = field();

--- @param getres fun(): ...
local function req_prep(req, getres)
	req_getres:set(tonumber(ffi.cast("size_t", req)), getres);
	return req;
end

--- @param func function
--- @param req libyaooi.req
--- @return fun()? cancel
--- @return ...
local function yo_sync_call(func, req, ...)
	yo_assert(func(req, ...));
	return function () return req:cancel() end;
end

function yaooi.req:__gc()
	libyaooi.yo_req_free(self);
end

function yaooi.req:cancel()
	libyaooi.yo_req_cancel(self);
end
function yaooi.req:num()
	return assert(tonumber(self));
end

function yaooi.req:udata()
	return req_udata:get(tonumber(ffi.cast("size_t", self)));
end

--- @param queue libyaooi.queue
--- @return libyaooi.req
function yaooi.req.new(queue, udata)
	local res = libyaooi.yo_req_new(queue);
	if res == libc.NULL then error "out of memory" end

	req_udata:set(tonumber(ffi.cast("size_t", res)), udata);
	return res;
end

--- @class libyaooi.queue: ffi.cdata*
yaooi.queue = {};
yaooi.queue.__index = yaooi.queue;
yaooi.queue.__metatable = "libyaooi.queue";
local queue_type = ffi.metatype("struct yo_queue", yaooi.queue);

function yaooi.queue:__gc()
	libyaooi.yo_queue_free(self);
end
--- @param deadline? number
--- @return libyaooi.req? req
--- @return boolean? ok
--- @return ... results
function yaooi.queue:poll(deadline)
	local pdeadline = nil;
	local pcode = ffi.new "int[1]";
	local preq = ffi.new "yo_req_t[1]";

	if deadline then
		pdeadline = ffi.new "yo_time_t[1]";
		pdeadline[0].sec = math.floor(deadline);
		pdeadline[0].nsec = (deadline - math.floor(deadline)) * 1000000000;
	end

	local code = libyaooi.yo_queue_poll(self, pdeadline, preq, pcode);
	if code == -110 then return nil end
	if code ~= 0 then error(ffi.string(libyaooi.yo_strerr(code))) end

	--- @type libyaooi.req
	local req = preq[0];
	local code = assert(tonumber(pcode[0]));
	if code == 0 then
		return req, true, req_getres:get(tonumber(ffi.cast("size_t", req)))();
	else
		return req, false, ffi.string(libyaooi.yo_strerr(code));
	end
end
--- @return libyaooi.queue
function yaooi.queue.new()
	local res = libyaooi.yo_queue_new();
	if res == libc.NULL then error "out of memory" end
	return res;
end

--- @return libyaooi.fd
function yaooi.tty_in()
	local pres = ffi.new "yo_fd_t[1]";
	yo_assert(libyaooi.yo_tty_in(pres));
	return pres[0];
end
--- @return libyaooi.fd
function yaooi.tty_out()
	local pres = ffi.new "yo_fd_t[1]";
	yo_assert(libyaooi.yo_tty_out(pres));
	return pres[0];
end
--- @return libyaooi.fd
function yaooi.tty_err()
	local pres = ffi.new "yo_fd_t[1]";
	yo_assert(libyaooi.yo_tty_err(pres));
	return pres[0];
end

--- @class libyaooi.fd: ffi.cdata*
yaooi.fd = {};
yaooi.fd.__index = yaooi.fd;
yaooi.fd.__metatable = "libyaooi.fd";
local fd_type = ffi.metatype("struct yo_fd", yaooi.fd);

function yaooi.fd:close()
	libyaooi.yo_fd_close(self);
	return true;
end
--- @param req libyaooi.req
--- @param n integer
--- @param buff? ffi.cdata*
--- @return fun()? cancel
--- @return integer n
function yaooi.fd:read(req, buff, n)
	local pn = ffi.new("size_t[1]", n);
	return yo_sync_call(libyaooi.yoa_read, req_prep(req, function () return tonumber(pn[0]) end), self, buff, pn);
end
--- @param req libyaooi.req
--- @param n integer
--- @param buff ffi.cdata* | string
--- @return fun()? cancel
--- @return integer n
function yaooi.fd:write(req, buff, n)
	local pn = ffi.new("size_t[1]", n);
	return yo_sync_call(libyaooi.yoa_write, req_prep(req, function () return tonumber(pn[0]) end), self, buff, pn);
end
--- @param req libyaooi.req
--- @param offset integer
--- @param n integer
--- @param buff ffi.cdata*
--- @return fun()? cancel
--- @return integer n
function yaooi.fd:pread(req, offset, buff, n)
	local pn = ffi.new("size_t[1]", n);
	return yo_sync_call(libyaooi.yoa_file_read, req_prep(req, function () return tonumber(pn[0]) end), self, buff, pn, offset);
end
--- @param req libyaooi.req
--- @param offset integer
--- @param n integer
--- @param buff ffi.cdata* | string
--- @return fun()? cancel
--- @return integer n
function yaooi.fd:pwrite(req, offset, buff, n)
	local pn = ffi.new("size_t[1]", n);
	return yo_sync_call(libyaooi.yoa_file_write, req_prep(req, function () return tonumber(pn[0]) end), self, buff, pn, offset);
end

--- @param req libyaooi.req
--- @return fun()? cancel
--- @return true
function yaooi.fd:sync(req)
	return yo_sync_call(libyaooi.yoa_sync, req_prep(req, function () return true end), self);
end
--- @param req libyaooi.req
--- @return fun()? cancel
--- @return std.io.stat
function yaooi.fd:stat(req)
	local pres = ffi.new("yo_stat_t[1]");
	return yo_sync_call(libyaooi.yoa_stat, req_prep(req, function ()
		local file_type = "file";
		if pres[0].type == 1 then
			file_type = "dir";
		elseif pres[0].type == 2 then
			file_type = "link";
		elseif pres[0].type == 3 then
			file_type = "sock";
		elseif pres[0].type == 4 then
			file_type = "fifo";
		elseif pres[0].type == 5 then
			file_type = "char";
		elseif pres[0].type == 6 then
			file_type = "blk";
		end

		return {
			type = file_type,
			mode = assert(tonumber(pres[0].mode)),
			gid = assert(tonumber(pres[0].gid)),
			uid = assert(tonumber(pres[0].uid)),
			atime = timenum(pres[0].atime),
			ctime = timenum(pres[0].ctime),
			mtime = timenum(pres[0].mtime),
			size = assert(tonumber(pres[0].size)),
			blksize = assert(tonumber(pres[0].blksize)),
			inode = assert(tonumber(pres[0].inode)),
			links = assert(tonumber(pres[0].links)),
		};
	end), self, pres);
end
--- @param req libyaooi.req
--- @param mode integer
--- @return fun()? cancel
--- @return true?
function yaooi.fd:chmod(req, mode)
	yo_assert(libyaooi.yo_file_chmod(self,mode));
	return nil, true;
end
--- @param req libyaooi.req
--- @param uid integer
--- @param gid integer
--- @return fun()? cancel
--- @return true?
function yaooi.fd:chown(req, uid, gid)
	yo_assert(libyaooi.yo_file_chown(self, uid, gid));
	return nil, true;
end

--- @param fd integer
--- @param owned? boolean
--- @return libyaooi.fd fd
function yaooi.fd.new(fd, owned)
	local pres = ffi.new "yo_fd_t[1]";
	yo_assert(libyaooi.yo_fd_new(pres, fd, owned or false));
	return pres[0];
end

--- @class libyaooi.dir: ffi.cdata*
yaooi.dir = {};
yaooi.dir.__index = yaooi.dir;
yaooi.dir.__metatable = "libyaooi.dir";
local dir_type = ffi.metatype("struct yo_dir", yaooi.dir);

--- @param req libyaooi.req
--- @param path string
--- @param mode? integer | string
--- @return fun()? cancel
--- @return true
function yaooi.dir.new(req, path, mode)
	return yo_sync_call(libyaooi.yoa_dir_new, req_prep(req, function () return true end), path, mode);
end
--- @param path string
--- @return libyaooi.dir dir
function yaooi.dir.open(path)
	local pres = ffi.new "yo_dir_t[1]";
	yo_assert(libyaooi.yo_dir_open(pres, path));
	return pres[0];
end
--- @param req libyaooi.req
--- @return fun()? cancel
--- @return string name
function yaooi.dir:next(req)
	local pres = ffi.new "char*[1]";
	return yo_sync_call(libyaooi.yoa_dir_next, req_prep(req, function ()
		if pres[0] == libc.NULL then
			return nil;
		else
			return ffi.string(pres[0]);
		end
	end), self, pres);
end
function yaooi.dir:close()
	libyaooi.yo_dir_close(self);
	return true;
end

--- @class libyaooi.proc: ffi.cdata*
yaooi.proc = {};
yaooi.proc.__index = yaooi.proc;
yaooi.proc.__metatable = "libyaooi.proc";
local proc_type = ffi.metatype("struct yo_proc", yaooi.proc);

--- @param argv string[]
--- @param env { [string]: string, [integer]: { [1]: string, [2]: string } }
--- @param stdin? boolean
--- @param stdout? boolean
--- @param stderr? boolean
--- @param windowssucks? boolean Usually always true, but set this only when spawning a cmd /c command process
--- @return libyaooi.proc
--- @return libyaooi.fd? stdin
--- @return libyaooi.fd? stdout
--- @return libyaooi.fd? stderr
function yaooi.proc.spawn(argv, env, cwd, stdin, stdout, stderr, windowssucks)
	local pin = stdin and ffi.new "yo_fd_t[1]" or nil;
	local pout = stdout and ffi.new "yo_fd_t[1]" or nil;
	local perr = stderr and ffi.new "yo_fd_t[1]" or nil;
	local pres = ffi.new "yo_proc_t[1]";

	local argvp = ffi.new("const char*[?]", #argv + 1);
	for i = 1, #argv do
		argvp[i - 1] = argv[i];
	end
	argvp[#argv] = nil;

	local env_n = 0;

	local envp;

	if env then
		for k in pairs(env) do
			if type(k) ~= "number" then
				env_n = env_n + 1;
			end
		end

		envp = ffi.new("const char*[?]", #env + env_n + 1);
		local env_i = #env;
		for k, v in pairs(env) do
			if type(k) ~= "number" then
				local val = k .. "=" .. v;
				envp[env_i] = val;
				env_i = env_i + 1;
			else
				local val = v[0] .. "=" .. v[1];
				envp[k - 1] = val;
			end
		end
		envp[#env + env_n] = nil;
	end

	yo_assert(libyaooi.yo_proc_spawn(pres, windowssucks and 1 or 0, argvp, envp, cwd, pin, pout, perr));

	return pres[0], pin and pin[0], pout and pout[0], perr and perr[0];
end
--- @param req libyaooi.req
--- @return fun()? cancel
--- @return integer sig_or_code
function yaooi.proc:wait(req)
	local pcode = ffi.new "int[1]";
	local psig = ffi.new "int[1]";

	return yo_sync_call(libyaooi.yoa_proc_wait, req_prep(req, function ()
		local code, sig = pcode[0], psig[0];

		if sig >= 0 then return sig end
		if code >= 0 then return -code end
		return "int";
	end), self, pcode, psig);
end
function yaooi.proc:disown()
	libyaooi.yo_proc_disown(self);
	return true;
end

--- @class libyaooi.enviter: ffi.cdata*
yaooi.enviter = {};
yaooi.enviter.__index = yaooi.enviter;
yaooi.enviter.__metatable = "libyaooi.enviter";
local enviter_type = ffi.metatype("struct yo_enviter", yaooi.enviter);

--- @return libyaooi.enviter
function yaooi.enviter.new()
	local res = yaooi.yo_enviter_new();
	if res == libc.NULL then error "out of memory" end
	return res;
end
--- @return string? pair
function yaooi.enviter:next()
	local pres = ffi.new "const char*[1]";

	yo_assert(libyaooi.yo_enviter_next(self, pres));
	if pres[0] == libc.NULL then return nil end

	return ffi.string(pres[0]);
end
function yaooi.enviter:__gc()
	libyaooi.yo_enviter_close(self);
end

--- @param path string
--- @param flags std.io.open_flags
--- @param mode? integer | string
--- @return libyaooi.fd file
function yaooi.file_open(path, flags, mode)
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

	local pres = ffi.new "yo_fd_t[1]";
	yo_assert(libyaooi.yo_file_open(pres, path, real_flags, mode));
	return pres[0];
end
--- @param req libyaooi.req
--- @param src string
--- @param dst string
--- @return fun()? cancel
--- @return integer n
function yaooi.file_symlink(req, src, dst)
	return yo_sync_call(libyaooi.yoa_file_symlink, req_prep(req, function () return true end), src, dst);
end
--- @param req libyaooi.req
--- @param src string
--- @param dst string
--- @return fun()? cancel
--- @return integer n
function yaooi.file_hardlink(req, src, dst)
	return yo_sync_call(libyaooi.yoa_file_hardlink, req_prep(req, function () return true end), src, dst);
end
--- @param req libyaooi.req
--- @param path string
--- @return fun()? cancel
--- @return integer n
function yaooi.file_readlink(req, path)
	local pres = ffi.new "char*[1]";
	return yo_sync_call(libyaooi.yoa_file_readlink, req_prep(req, function ()
		local res = ffi.string(pres[0], libc.strlen(pres[0]));
		libc.free(pres[0]);
		return res;
	end), path, pres);
end
--- @param req libyaooi.req
--- @param path string
--- @return fun()? cancel
--- @return integer n
function yaooi.file_remove(req, path)
	return yo_sync_call(libyaooi.yoa_file_remove, req_prep(req, function () return true end), path);
end

--- @param addr string
--- @param port integer
--- @param prot "tcp" | "udp"
--- @param max_n integer
--- @return libyaooi.fd server
function yaooi.socket_bind(addr, port, prot, max_n)
	prot = prot or "tcp";

	local real_prot;

	if prot == "tcp" then
		real_prot = 0;
	elseif prot == "udp" then
		real_prot = 1;
	else
		error "invalid proto";
	end

	local real_addr = addrparse(addr);

	local pres = ffi.new "yo_fd_t[1]";
	yo_assert(libyaooi.yo_socket_bind(pres, real_prot, real_addr, port, max_n));
	return pres[0];
end
--- @param req libyaooi.req
--- @param fd libyaooi.fd
--- @return fun()? cancel
--- @return libyaooi.fd client
--- @return string ip
--- @return integer port
function yaooi.socket_accept(req, fd)
	local pclient = ffi.new "yo_fd_t[1]";
	local paddr = ffi.new "yo_addr_t[1]";
	local pport = ffi.new "uint16_t[1]";

	return yo_sync_call(libyaooi.yoa_socket_accept, req_prep(req, function ()
		return pclient[0], addrstr(paddr[0]), assert(tonumber(pport[0]));
	end), fd, pclient, paddr, pport);
end
--- @param req libyaooi.req
--- @param addr string
--- @param port integer
--- @param prot? "tcp" | "udp" = tcp
--- @return fun()? cancel
--- @return libyaooi.fd client
function yaooi.socket_connect(req, addr, port, prot)
	prot = prot or "tcp";

	local real_prot;

	if prot == "tcp" then
		real_prot = 0;
	elseif prot == "udp" then
		real_prot = 1;
	else
		error "invalid proto";
	end

	local real_addr = addrparse(addr);
	local pres = ffi.new "yo_fd_t[1]";

	return yo_sync_call(libyaooi.yoa_socket_connect, req_prep(req, function () return pres[0] end), pres, real_prot, real_addr, port);
end

--- @param req libyaooi.req
--- @param name string
--- @param flags? std.io.net.addrinfo_flags
--- @return fun()? cancel
--- @return string[] names
function yaooi.dns_getaddrinfo(req, name, flags)
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

	local pres = ffi.new "yo_addrinfo_t[1]";
	return yo_sync_call(libyaooi.yoa_dns_getaddrinfo, req_prep(req, function ()
		local res = {};

		for i = 1, assert(tonumber(pres[0].n)) do
			table.insert(res, addrstr(pres[0].addr[i - 1]));
		end

		libc.free(pres[0]);
		return res;
	end), pres, name, real_flags);
end

--- @param sig integer
--- @return true ok
function yaooi.sig_on(sig)
	yo_assert(libyaooi.yo_sig_on(sig));
	return true;
end
--- @param sig integer
--- @return true ok
function yaooi.sig_off(sig)
	yo_assert(libyaooi.yo_sig_off(sig));
	return true;
end
--- @param req libyaooi.req
--- @return fun()? cancel
--- @return integer sig
function yaooi.sig_wait(req)
	local pres = ffi.new "yo_signo_t[1]";
	return yo_sync_call(libyaooi.yoa_sig_wait, req_prep(req, function () return tonumber(pres[0]) end), pres);
end

--- @param name string
--- @return string? val
function yaooi.env_get(name)
	local pres = ffi.new "char*[1]";

	yo_assert(libyaooi.yo_env_get(name, pres));

	if pres[0] == libc.NULL then
		return nil;
	end

	local res = ffi.string(pres[0]);
	libc.free(pres[0]);
	return res;
end
--- @param name string
--- @param val string
--- @return true
function yaooi.env_set(name, val)
	yo_assert(libyaooi.yo_env_set(name, name, val));
	return true;
end

--- @param clock? "real" | "mono" | "cpu" = mono\
--- @return number
function yaooi.time(clock)
	if not clock or clock == "mono" then return timenum(libyaooi.yo_time(libyaooi.YO_CLOCK_MONO)) end
	if clock == "real" then return timenum(libyaooi.yo_time(libyaooi.YO_CLOCK_REAL)) end
	if clock == "cpu" then return timenum(libyaooi.yo_time(libyaooi.YO_CLOCK_CPU)) end
	error "invalid clock type";
end
--- @param type "home" | "config" | "data" | "cache" | "runtime" | "cwd"
--- @return string
function yaooi.getpath(type)
	local real_type;

	if type == "home" then
		real_type = libyaooi.YO_PATH_HOME;
	elseif type == "config" then
		real_type = libyaooi.YO_PATH_CONFIG;
	elseif type == "data" then
		real_type = libyaooi.YO_PATH_DATA;
	elseif type == "cache" then
		real_type = libyaooi.YO_PATH_CACHE;
	elseif type == "runtime" then
		real_type = libyaooi.YO_PATH_RUNTIME;
	elseif type == "cwd" then
		real_type = libyaooi.YO_PATH_CWD;
	else
		error "invalid param getpath type";
	end

	local pres = ffi.new "char*[1]";

	yo_assert(libyaooi.yo_getpath(real_type, pres));

	local res = ffi.string(pres[0]);
	libc.free(pres[0]);
	return res;
end

return yaooi;

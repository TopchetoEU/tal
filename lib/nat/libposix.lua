local field = require "std.field";
local ffi = require "nat.ffi";
local libc = require "nat.libc";
local errors = require "std.errors";
local objects = require "nat.utils.objects";
local sig = require "std.sig";
local error = errors.throw;

local libposix = ffi.C;

if jit.os == "Linux" then
	ffi.cdef [[
		struct dirent {
			long d_ino;
			long d_off;
			unsigned short d_reclen;
			unsigned char d_type;
			char d_name[256];
		};
	]];
elseif jit.os == "BSD" or jit.os == "OSX" then
	ffi.cdef [[
		struct dirent {
			long d_ino;
			long d_off;
			uint16_t d_reclen;
			uint8_t	d_type;
			uint8_t	d_namlen;
			uint32_t d_pad0;
			char d_name[256];
		};
	]];
end

ffi.cdef [[
typedef struct DIR DIR;

int open(const char *path, int flags, ...);
int close(int fd);

DIR *opendir(const char *name);
int closedir(DIR *fd);
struct dirent *readdir(DIR *fd);

char *strerror(int errnum);

extern char **environ;
extern int errno;
]]

local posix = { [require "std.package.strongtag"] = true };

posix.open_flags = {
	WRONLY = 0x01,
	RDWR = 0x02,
	CREAT = 0x40,
	EXCL = 0x80,
	NOCTTY = 0x100,
	TRUNC = 0x200,
	APPEND = 0x400,
	NONBLOCK = 0x800,
	SYNC = 0x101000,

	DSYNC = 0x1000,
	ASYNC = 0x2000,
	DIRECT = 0x4000,

	LARGEFILE = 0x8000,
	DIRECTORY = 0x10000,
	NOFOLLOW = 0x20000,
	NOATIME = 0x40000,
	CLOEXEC = 0x80000,
	PATH = 0x200000,
	TMPFILE = 0x410000,
};

local errmap = {
	-- Included here so that no memory is allocated for an out of memory error, as we already appear to not have much of it
	[4 --[[EINTR]]] = errors.cancelled,
	[12 --[[ENOMEM]]] = errors.nomem,
	[32 --[[EPIPE]]] = errors.eof,
	[38 --[[ENOSYS]]] = errors.notimpl,
	[110 --[[ETIMEDOUT]]] = errors.cancelled,
	[125 --[[ECANCELED]]] = errors.cancelled,
};

--- @param res integer
local function posix_assert(res)
	if res < 0 then
		local err = tonumber(libposix.errno);
		if errmap[err] then
			throw(errmap[err]);
		else
			throw(libposix.strerror(err));
		end
	end

	return res;
end

--- @param path string
--- @param flags integer
--- @param mode? integer
--- @return integer
function posix.open(path, flags, mode)
	return posix_assert(libposix.open(path, flags, mode));
end
--- @param fd integer
function posix.close(fd)
	posix_assert(libposix.close(fd));
end

--- @param path string
--- @return ffi.cdata*
function posix.opendir(path)
	local dir = libposix.opendir(path);
	if dir == libc.NULL then posix_assert(-1) end

	return dir;
end
--- @param fd ffi.cdata*
function posix.closedir(fd)
	posix_assert(libposix.closedir(fd));
end
--- @param fd ffi.cdata*
--- @return string name
--- @return integer ino
function posix.readdir(fd)
	libposix.errno = 0;
	local entry = libposix.readdir(fd);
	if entry == libc.NULL then
		if libposix.errno == 0 then
			error(errors.eof);
		else
			posix_assert(-1);
		end
	end

	return ffi.string(entry.d_name, libc.strlen(entry.d_name)), assert(tonumber(entry.d_ino));
end

function posix.environ()
	return libposix.environ --[[@as ffi.cdata*]];
end
--- @param name string
function posix.getenv(name)
	local res = libposix.getenv(name);
	if res == libc.NULL then return nil end
	return ffi.string(res);
end
--- @param name string
--- @param val string
function posix.setenv(name, val)
	posix_assert(libposix.getenv(name, val, true));
end
--- @param name string
function posix.unsetenv(name)
	posix_assert(libposix.unsetenv(name));
end


return posix;

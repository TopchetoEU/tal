--- @meta
--- Declaration file for the expected functions an implementation shall provide

-- All "async" functions can short-circtuit by returning true + the return values.
-- Otherwise, they will return false, and later on, will return the udata + the results from poll()

--- @class _impl.fd
local file = {};
--- @param buff ffi.cdata*
--- @param n integer
--- @return fun()? cancel
--- @return integer n
function file:read(udata, buff, n) end
--- @param buff ffi.cdata*
--- @param n integer
--- @return fun()? cancel
--- @return integer n
function file:write(udata, buff, n) end
--- @param offset integer
--- @param buff ffi.cdata*
--- @param n integer
--- @return fun()? cancel
--- @return integer n
function file:pread(udata, offset, buff, n) end
--- @param offset integer
--- @param buff ffi.cdata*
--- @param n integer
--- @return fun()? cancel
--- @return integer n
function file:pwrite(udata, offset, buff, n) end
--- @return fun()? cancel
--- @return true ok
function file:flush(udata) end
--- @return fun()? cancel
--- @return std.io.stat stat
function file:stat(udata) end
--- @param mode integer
--- @return fun()? cancel
--- @return true ok
function file:chmod(udata, mode) end
--- @param uid integer
--- @param gid integer
--- @return fun()? cancel
--- @return true ok
function file:chown(udata, uid, gid) end
function file:close() end

--- @class _impl.dir
local dir = {};

--- @return fun()? cancel
--- @return string name
function dir:next(udata) end
function dir:close() end

--- @class _impl.server
local server = {};
--- @return fun()? cancel
--- @return _impl.fd client
--- @return string ip
--- @return integer port
function server:next(udata) end
function server:close() end

--- @class _impl.iterenv
local iterenv = {};
--- @return string
function iterenv:next() end
function iterenv:close() end

--- @class _impl.process
local process = {};
--- @return fun()? cancel
--- @return integer code
function process:wait(udata) end
-- TODO: add close()
-- function process:close() end

--- @class _impl
--- @field stdin _impl.fd
--- @field stdout _impl.fd
--- @field stderr _impl.fd
local _impl = {};

--- Converts an OS fd to a stream
--- @param fd integer
--- @return _impl.fd file
function _impl:openfd(fd) end

--- @param path string
--- @param flags std.io.open_flags
--- @param mode integer
--- @return fun()? cancel
--- @return _impl.fd file
function _impl:open(udata, path, flags, mode) end
--- @param path string
--- @param mode integer
--- @return fun()? cancel
--- @return true ok
function _impl:mkdir(udata, path, mode) end
--- @param path string
--- @return fun()? cancel
--- @return _impl.dir dir
function _impl:opendir(udata, path) end

--- @param src string
--- @param dst string
--- @return fun()? cancel
--- @return true ok
function _impl:symlink(udata, src, dst) end
--- @param src string
--- @param dst string
--- @return fun()? cancel
--- @return true ok
function _impl:hardlink(udata, src, dst) end
--- @param path string
--- @return fun()? cancel
--- @return string res
function _impl:readlink(udata, path) end
--- @param path string
--- @return fun()? cancel
--- @return true ok
function _impl:remove(udata, path) end

--- @param addr string
--- @param port integer
--- @param protocol "tcp" | "udp"
--- @return fun()? cancel
--- @return _impl.fd client
function _impl:connect(udata, addr, port, protocol) end
--- @param addr string
--- @param port integer
--- @param protocol "tcp" | "udp"
--- @param max_n integer
--- @return fun()? cancel
--- @return _impl.server server
function _impl:bind(udata, addr, port, protocol, max_n) end
--- @param name string
--- @param flags std.io.net.addrinfo_flags
--- @return fun()? cancel
--- @return string[] addrs
function _impl:getaddrinfo(udata, name, flags) end

--- @param argv string[]
--- @param env { [string]: string, [integer]: { [1]: string, [2]: string } }
--- @param cwd? string
--- @param stdin? boolean
--- @param stdout? boolean
--- @param stderr? boolean
--- @return fun()? cancel
--- @return { proc: _impl.process, stdin?: std.io.stream, stdout?: std.io.stream, stder?: std.io.stream }
function _impl:spawn(udata, argv, env, cwd, stdin, stdout, stderr) end

--- @param signal std.signal
--- @return true
function _impl:sig_on(signal) end
--- @param signal std.signal
--- @return true
function _impl:sig_off(signal) end
--- @return fun()? cancel
--- @return std.signal
function _impl:sig_wait(udata) end

--- @param kind "real" | "mono" | "cpu"
--- @return number
function _impl:time(kind) end

--- @param type "home" | "config" | "data" | "cache" | "runtime" | "cwd"
--- @return string
function _impl:getpath(type) end
--- @param name string
--- @return string
function _impl:env_get(name) end
--- @param name string
--- @param val string
--- @return true
function _impl:env_set(name, val) end
--- @return _impl.iterenv
function _impl:iterenv() end

--- Returns a callback + arguments to be called if successful
--- Returns nil
--- Returns nil + an error message if an error occurred
--- @param timeout? number
--- @return any udata
--- @return boolean ok
--- @return ...
function _impl:next(timeout) end

return _impl;

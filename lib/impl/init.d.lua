--- @meta impl
--- Declaration file for the expected functions an implementation shall provide

-- All "async" functions can short-circtuit by returning true + the return values.
-- Otherwise, they will return false, and later on, will return the udata + the results from poll()

--- @class _impl.file
local file = {};
--- @param offset integer
--- @param buff ffi.cdata*
--- @param n integer
--- @return boolean sync
--- @return integer? n
--- @return string? err
function file:read(udata, offset, buff, n) end
--- @param offset integer
--- @param buff ffi.cdata*
--- @param n integer
--- @return boolean sync
--- @return integer? n
--- @return string? err
function file:write(udata, offset, buff, n) end
--- @return boolean sync
--- @return true? ok
--- @return string? err
function file:flush(udata) end
--- @return boolean sync
--- @return std.io.stat? stat
--- @return string? err
function file:stat(udata) end
function file:close() end

--- @class _impl.stream
local stream = {};
--- @param buff ffi.cdata*
--- @param n integer
--- @return boolean sync
--- @return integer? n
--- @return string? err
function stream:read(udata, buff, n) end
--- @param buff ffi.cdata*
--- @param n integer
--- @return boolean sync
--- @return integer? n
--- @return string? err
function stream:write(udata, buff, n) end
--- @return boolean sync
--- @return true? ok
--- @return string? err
function stream:flush(udata) end
--- @return boolean sync
--- @return std.io.stat? stat
--- @return string? err
function stream:stat(udata) end
function stream:close() end

--- @class _impl.dir
local dir = {};

--- @return boolean sync
--- @return string? name
--- @return string? err
function dir:next(udata) end
function dir:close() end

--- @class _impl.server
local server = {};
--- @return boolean sync
--- @return { client: _impl.stream, ip: string, port: integer }? client
--- @return string? err
function server:next(udata) end
function server:close() end

--- @class _impl.iterenv_backend
local iterenv_backend = {};
--- @return string?, string?
function iterenv_backend:next() end
function iterenv_backend:close() end

--- @class _impl
--- @field stdin _impl.stream
--- @field stdout _impl.stream
--- @field stderr _impl.stream
local _impl = {};

--- @param path string
--- @param flags std.io.open_flags
--- @param mode integer
--- @return boolean sync
--- @return _impl.file? file
--- @return string? err
function _impl:open(udata, path, flags, mode) end
--- @param path string
--- @param mode integer
--- @return boolean sync
--- @return true? ok
--- @return string? err
function _impl:mkdir(udata, path, mode) end
--- @param path string
--- @return boolean sync
--- @return _impl.dir? dir
--- @return string? err
function _impl:opendir(udata, path) end

--- @param path string
--- @return boolean sync
--- @return true? ok
--- @return string? err
function _impl:delete(udata, path) end
--- @param path integer
--- @param mode integer
--- @return boolean sync
--- @return true? ok
--- @return string? err
function _impl:chmod(udata, path, mode) end
--- @param path integer
--- @param uid integer
--- @param gid integer
--- @return boolean sync
--- @return true? ok
--- @return string? err
function _impl:chown(udata, path, uid, gid) end

--- @param addr string
--- @param port integer
--- @param protocol "tcp" | "udp"
--- @return boolean sync
--- @return _impl.stream? client
--- @return string? err
function _impl:connect(udata, addr, port, protocol) end
--- @param addr string
--- @param port integer
--- @param protocol "tcp" | "udp"
--- @param max_n integer
--- @return boolean sync
--- @return _impl.server? server
--- @return string? err
function _impl:bind(udata, addr, port, protocol, max_n) end
--- @param name string
--- @param flags std.io.net.addrinfo_flags
--- @return boolean sync
--- @return string[]? addrs
--- @return string? err
function _impl:getaddrinfo(udata, name, flags) end

--- @return number
function _impl:realtime() end
--- @return number
function _impl:monotime() end

--- @param type "home" | "config" | "data" | "cache" | "runtime" | "cwd"
--- @return string?
--- @return string? err
function _impl:getpath(type) end
--- @param name string
--- @return string?
--- @return string? err
function _impl:getenv(name) end
--- @param name string
--- @param val string
--- @return true?
--- @return string? err
function _impl:setenv(name, val) end
--- @return _impl.iterenv_backend?
--- @return string? err
function _impl:iterenv() end

--- Returns a callback + arguments to be called if successful
--- Returns nil
--- Returns nil + an error message if an error occurred
--- @param timeout? number
--- @return any udata
--- @return ...
function _impl:next(timeout) end

return _impl;

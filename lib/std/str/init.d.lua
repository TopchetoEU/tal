--- @meta

--- @class std.str.backend
local std_backend = {};

--- @param ptr ffi.cdata*
--- @param n integer
--- @return integer
function std_backend:_read(ptr, n) end
--- @param buff string.buffer
function std_backend:_readto(buff) end
--- @return string?
function std_backend:_readtext() end

--- @param ptr ffi.cdata*
--- @param n integer
--- @return integer
function std_backend:_write(ptr, n) end
--- @param data string
function std_backend:_writetext(data) end

function std_backend:_close() end

function std_backend:_flush() end
--- @return std.io.stat
function std_backend:_stat() end
--- @param whence seekwhence
--- @param pos integer
--- @return integer
function std_backend:_seek(whence, pos) end
--- @param mode integer
function std_backend:_chmod(mode) end
--- @param uid integer
--- @param gid integer
function std_backend:_chown(uid, gid) end

--- @alias str std.str Nice alias for lazy ppl

--- @class std.str
local str = {};

--- @param ptr ffi.cdata*
--- @param n integer
--- @return integer? n If nil, indicates an EOF
function str:rawread(ptr, n) ierror "not supported" end
--- @param ptr ffi.cdata*
--- @param n integer
--- @return integer n
function str:rawwrite(ptr, n) ierror "not supported" end
--- @param whence "set" | "cur" | "end"
--- @param pos integer
--- @return integer
function str:seek(whence, pos) ierror "not supported" end
--- @return true _ Must be returned, so that `assert(self:flush())` doesn't error out
function str:flush() return true end
--- @return std.io.stat
function str:stat() ierror "not supported" end
--- @param mode integer
function str:rawchmod(mode) ierror "not supported" end
--- @param uid integer
--- @param gid integer
function str:chown(mode) ierror "not supported" end
--- @return true _ Must be returned, so that `assert(self:flush())` doesn't error out
function str:close() return true end

--- @param mode integer | string
function str:chmod(mode)
	if type(mode) == "string" then mode = assert(tonumber(mode, 8), "bad mode") end
	self:rawchmod(mode);
	return self;
end

local sig = require "std.sig";
local ffi = require "nat.ffi";
local buffer = require "string.buffer";

local utf8 = {};
-- /*
-- ** $Id: lutf8lib.c $
-- ** Standard library for UTF-8 manipulation
-- ** See Copyright Notice in lua.h
-- */

-- #define lutf8lib_c
-- #define LUA_LIB

-- #include "lprefix.h"


-- #include <limits.h>
-- #include <stdlib.h>
-- #include <string.h>

-- #include "lua.h"

-- #include "lauxlib.h"
-- #include "lualib.h"
-- #include "llimits.h"


-- #define MAXUNICODE	0x10FFFFu
local MAXUNICODE = 0x10FFFF;
-- #define MAXUTF		0x7FFFFFFFu
local MAXUTF = 0x7FFFFFFF;


local MSGInvalid = "invalid UTF-8 code";


-- #define iscont(c)	(((c) & 0xC0) == 0x80)
--- @param c integer
local function iscont(c)
	return (c & 0xC0) == 0x80;
end

--- For a given non-continuation byte, returns the amount of following bytes required to complete the byte to a valid utf8 sequence
--- @param c integer
--- @return integer cnt 0 if `c` is an ANSI char, `-1` if `c` is a continuation byte, `>= 1` if `c` is a utf8 begin byte
--- @return integer rem The remaining bits in the byte, that are the first n bits of the codepoint
function utf8.parsebyte(c, lax)
	-- 0b0xxxxxxx
	if c & 0x80 == 0x00 then return 0, c end
	-- 0b10xxxxxx
	if c & 0xC0 == 0x80 then return -1, c & 0x3F end
	-- 0b110xxxxx
	if c & 0xE0 == 0xC0 then return 1, c & 0x1F end
	-- 0b1110xxxx
	if c & 0xF0 == 0xE0 then return 2, c & 0x0F end
	-- 0b11110xxx
	if c & 0xF8 == 0xF0 then return 3, c & 0x07 end

	if not lax then error "invalid utf8 begin code" end

	-- 0b111110xx
	if c & 0xFC == 0xF8 then return 4, c & 0x03 end
	-- 0b1111110x
	if c & 0xFE == 0xFC then return 5, c & 0x01 end
	-- 0b11111110
	if c == 0xFE then return 6, 0 end

	return 7, 0;
end

--- @param str string
--- @param i? integer = 1
--- @param lax? boolean = false
function utf8.decode(str, i, lax)
	i = table.absindex(str, i or 1);
	if i < 1 or i > #str then sig.error("i", "out of bounds") end

	local n, res = utf8.parsebyte(str:byte(i), lax);
	if n == -1 and not lax then error "illegal utf8 sequence" end

	for _ = 1, n do
		if i > #str then
			if lax then res <<= 6 end
			error(errors.eof);
		else
			local n, curr = utf8.parsebyte(str:byte(i), lax);
			if n ~= -1 and not lax then error "expected utf8 continuation byte" end

			res <<= 6;
			res |= curr;
		end
	end

	return res;
end
--- @param c? integer
--- @param lax? boolean = false If true, c may be bigger than 2^21, and it will be encoded with 5+ bytes
function utf8.encode(c, lax)
	if c < 0 then sig.error("c", "out of range") end

	local res = {};
	local n = 0;
	local addmask = 0x80;
	local overlay = 0x00;

	while c >= 0x80 do
		-- We phyiscally cannot encode larger codepoints
		if addmask == 0 then error "encoded char too long" end

		table.insert(res, 1, string.byte((c & 0x3f) | 0x80));
		c >>= 6;
		overlay |= addmask;
		addmask >>= 1;
		n += 1;
	end

	if n > 3 and not lax then error "encoded char too long" end

	table.insert(res, 1, c | overlay);

	return table.concat(res);
end

--- @param str string
--- @param n integer
--- @param start? integer = n >= 0 ? 1 : #str + 1
function utf8.offset(str, n, start)
	start = table.absindex(str, n >= 0 and 1 or #str + 1);
	if start <= 0 or start > #str then
		sig.error("start", "out of bounds");
	end

	if n == 0 then
		local i = start;

		while i > 1 do
			if utf8.parsebyte(str:byte(i)) ~= -1 then break end
			i -= 1;
		end

		return i;
	end

	if start > #str and utf8.parsebyte(str:byte(start)) == -1 then
		sig.error("start", "in between of utf8 sequence");
	end

	if n > 0 then
		local i = start;
		for _ = 1, n - 1 do
			if i > #str then return nil end

			local n = utf8.parsebyte(str:byte(i));
			if n == -1 then error "invalid utf8 seqence" end
			i += n + 1;
		end

		return i;
	else
		local i = start;

		for _ = 1, -n do
			while i > 1 do
				i -= 1;
				if i < 1 then return nil end

				if utf8.parsebyte(str:byte(i)) ~= -1 then break end
			end
		end

		return i;
	end
end
--- @param str string
--- @param f? integer = 1
--- @param l? integer = -1
--- @param lax? boolean = false
function utf8.len(str, f, l, lax)
	f = table.absindex(str, f or 1);
	if f < 1 or f > #str then sig.error("f", "out of bounds") end

	l = table.absindex(str, l or -1);
	if l < 1 or l > #str then sig.error("l", "out of bounds") end

	local len = 0;

	local i = f;
	while i <= l do
		local n = utf8.parsebyte(str:byte(i), lax);
		if n == -1 and not lax then error "illegal utf8 sequence" end

		i += n + 1;
		len += 1;
	end

	return len;
end

--- @param str string
--- @param f? integer = 1
--- @param l? integer = f
--- @param lax? boolean = false
--- @return integer[]
function utf8.tcodepoint(str, f, l, lax)

	f = table.absindex(str, f or 1);
	if f < 1 or f > #str then sig.error("f", "out of bounds") end

	l = table.absindex(str, l or f);
	if l < 1 or l > #str then sig.error("l", "out of bounds") end

	local i = f;

	local parts = {};

	while i <= l do
		local n, res = utf8.parsebyte(str:byte(i), lax);
		if n == -1 and not lax then error "illegal utf8 sequence" end
		i += 1;

		for _ = 1, n do
			local n, curr = utf8.parsebyte(str:byte(i), lax);
			if n ~= -1 and not lax then error "expected utf8 continuation byte" end
			i += 1;

			pprint(n, curr, i);

			pprint(res);
			res <<= 6;
			pprint(res);
			res |= curr;
			pprint(res);
		end

		table.insert(parts, res);
	end

	return parts;
end
--- Since this works with variadics, luajit cannot optimize this
--- For single characters use `utf8.decode`, for multiples use `utf8.tcodepoint`
--- @param str string
--- @param f? integer = 1
--- @param l? integer = f
--- @param lax? boolean = false
--- @return integer ...
function utf8.codepoint(str, f, l, lax)
	return table.unpack(utf8.tcodepoint(str, f, l, lax));
end
--- Extended over the lua, `f` and `l` define the range of iteration
--- The iterator itself returns a third variable, `ok`, which is false if the codepoint returned is not valid
--- If `lax` is false, the third iterator result is always `true` and may be ignored
--- @param str string
--- @param lax? boolean = false
--- @param f? integer = 1
--- @param l? integer = -1
function utf8.codes(str, lax, f, l)
	f = table.absindex(str, f or 1);
	l = table.absindex(str, l or -1);

	if lax then
		--- @param i integer
		--- @param str string
		return function (i, str)
			if not i or i > l then return nil end
			return utf8.decode(str, i, lax);
		end, str, f;
	else
		--- @param i integer
		--- @param str string
		return function (i, str)
			if not i or i > l then return nil end
			local i, c, ok = utf8.decode(str, i, lax);
			if not ok then error "invalid utf8 sequence" end
			return i, c, true;
		end, str, f;
	end
end

--- A table version of utf8.char (use this, as varargs are not optimizable by luajit)
--- @param vals integer[]
--- @param lax? boolean = false
function utf8.tchar(vals, lax)
	local res = buffer.new(#vals);

	for i = 1, #vals do
		res:put(utf8.encode(vals[i], lax));
	end

	return res:tostring();
end
--- @param ... integer
function utf8.char(...)
	return utf8.tchar { ... };
end

--- @param f std.str
--- @param lax? boolean = false
function utf8.read(f, lax)
	local b = f:readbyte();
	if not b then return nil end

	local n, res = utf8.parsebyte(b, lax);
	if n == -1 and not lax then error "invalid utf8 sequence" end

	for _ = 1, n do
		b = f:readbyte();

		if not b then
			if lax then res <<= 6 end
			error(errors.eof);
		else
			local n, curr = utf8.parsebyte(b, lax);
			if n ~= -1 and not lax then error "expected utf8 continuation byte" end

			res <<= 6;
			res |= curr;
		end
	end

	return res;
end

utf8.charpattern = "[\0-\x7F\xC2-\xFD][\x80-\xBF]*";

return utf8


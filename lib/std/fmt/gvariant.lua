local ffi = require "nat.ffi";

--- @param str string
--- @param i integer
local function read_u8_le(str, i)
	if i > #str then error("out of range read " .. i .. " in #" .. #str) end
	return str:byte(i);
end
--- @param str string
--- @param i integer
local function read_u16_le(str, i)
	local a = read_u8_le(str, i);
	local b = read_u8_le(str, i + 1);
	return a | b << 8;
end
--- @param str string
--- @param i integer
local function read_u32_le(str, i)
	local a = ffi.cast("uint32_t", read_u16_le(str, i));
	local b = ffi.cast("uint32_t", read_u16_le(str, i + 2));
	return tonumber(a | b << 16);
end

--- @param str string
--- @param i integer
local function read_u8_be(str, i)
	if i > #str then error("out of range read " .. i .. " in #" .. #str) end
	return str:byte(i);
end
--- @param str string
--- @param i integer
local function read_u16_be(str, i)
	local a = read_u8_be(str, i);
	local b = read_u8_be(str, i + 1);
	return a << 8 | b;
end
--- @param str string
--- @param i integer
local function read_u32_be(str, i)
	local a = ffi.cast("uint32_t", read_u16_be(str, i));
	local b = ffi.cast("uint32_t", read_u16_be(str, i + 2));
	return tonumber(a << 16 | b);
end

--- @param str string
--- @param i integer
--- @return ffi.cdata* | integer
local function read_u64_be(str, i)
	local a = ffi.cast("uint64_t", read_u32_be(str, i));
	local b = ffi.cast("uint64_t", read_u32_be(str, i + 4));
	local res = a << 32 | b;

	if res < 0x10000000000000 then return assert(tonumber(res)) end
	return res;
end

--- @param str string
--- @param i integer
local function read_i8_be(str, i)
	local res = read_u8_le(str, i);
	if res > 127 then res -= 256 end
	return res;
end
--- @param str string
--- @param i integer
local function read_i16_be(str, i)
	local res = read_u16_le(str, i);
	if res > (1 << 15) - 1 then res -= 1 << 15 end
	return res;
end
--- @param str string
--- @param i integer
local function read_i32_be(str, i)
	return tonumber(ffi.cast("int32_t", read_u32_le(str, i))) --[[@as integer]];
end
--- @param str string
--- @param i integer
--- @return ffi.cdata* | integer
local function read_i64_be(str, i)
	local res = ffi.cast("int64_t", read_u64_be(str, i));
	if res > -0x10000000000000 and res < 0x10000000000000 then return assert(tonumber(res)) end
	return res;
end

--- @param str string
--- @param i integer
local function read_f64_be(str, i)
	local data = read_u64_be(str, i);

	local sign = data >> 63 ~= 0;
	local exp = tonumber((data >> 52) & 0x7FF);
	local man = 1 + tonumber(data & 0xFFFFFFFFFFFFF) / 0x10000000000000;

	local res;

	if exp == 2047 then
		if man == 1 then
			res = 1/0;
		else
			res = -0/0;
		end
	elseif exp == 0 then
		res = man - 1;
	else
		res = man * (2 ^ (exp - 1023));
	end

	if sign then
		return -res;
	else
		return res;
	end
end

local function alignof(i, n)
	return math.ceil((i - 1) / n) * n + 1;
end

--- @param buf string
--- @param s integer
--- @param e integer
--- @param i integer
local function read_offset(buf, s, e, i)
	if e - s + 1 < 256 then
		local res = read_u8_le(buf, e - i + 1);
		return res;
	elseif e - s + 1 < 65536 then
		local res = read_u16_le(buf, e - i * 2 + 1);
		return res;
	else
		local res = read_u32_le(buf, e - i * 4 + 1);
		return res;
	end
end
--- @param s integer
--- @param e integer
local function get_offset_size(s, e)
	if e - s + 1 < 256 then
		return 1;
	elseif e - s + 1 < 65536 then
		return 2;
	else
		return 4;
	end
end

--- @param fmt string
--- @param fmt_i integer
--- @return integer fmt_i
--- @return integer align
--- @return integer? size
local function parse_fmt(fmt, fmt_i)
	local c = fmt:at(fmt_i);

	if c == "b" then
		return fmt_i + 1, 1, 1;
	elseif c == "y" then
		return fmt_i + 1, 1, 1;
	elseif c == "n" then
		return fmt_i + 1, 2, 2;
	elseif c == "q" then
		return fmt_i + 1, 2, 2;
	elseif c == "i" then
		return fmt_i + 1, 4, 4;
	elseif c == "u" then
		return fmt_i + 1, 4, 4;
	elseif c == "x" then
		return fmt_i + 1, 8, 8;
	elseif c == "t" then
		return fmt_i + 1, 8, 8;
	elseif c == "d" then
		return fmt_i + 1, 8, 8;
	elseif c == "s" or c == "o" or c == "g" then
		return fmt_i + 1, 1;
	elseif c == "r" then
		return fmt_i + 1, 1;
	elseif c == "v" then
		return fmt_i + 1, 8;
	elseif c == "m" or c == "a" or c == "l" then
		local inner_align;
		fmt_i, inner_align = parse_fmt(fmt, fmt_i + 1);
		return fmt_i, inner_align;
	elseif c == "{" or c == "(" then
		fmt_i += 1;
		--- @type integer?
		local size = 0;
		local align = 1;

		while true do
			if c == "{" and fmt:at(fmt_i) == "}" then break end
			if c == "(" and fmt:at(fmt_i) == ")" then break end

			if fmt:at(fmt_i) == "$" then
				fmt_i = fmt:match("^%$.-:()", fmt_i);
				assert(fmt_i, "malformed gvariant format");
			end

			local inner_align, inner_size;
			fmt_i, inner_align, inner_size = parse_fmt(fmt, fmt_i);

			if not inner_size then
				size = nil;
			else
				size = alignof(inner_size + 1, inner_align) - 1 + inner_size;
			end

			if align < inner_align then align = inner_align end
		end

		fmt_i += 1;

		return fmt_i, align, size;
	else
		error "malformed gvariant format";
	end
end

--- @param fmt string
--- @param fmt_i integer
--- @param buf string
--- @param s integer
--- @param e integer
--- @return integer fmt_i
--- @return any? data
local function read_fmt(fmt, fmt_i, buf, s, e)
	local c = fmt:at(fmt_i);

	if c == "b" then
		return fmt_i + 1, buf:byte(s) == 1;
	elseif c == "y" then
		return fmt_i + 1, read_u8_be(buf, s);
	elseif c == "n" then
		return fmt_i + 1, read_i16_be(buf, s);
	elseif c == "q" then
		return fmt_i + 1, read_u16_be(buf, s);
	elseif c == "i" then
		return fmt_i + 1, read_i32_be(buf, s);
	elseif c == "u" then
		return fmt_i + 1, read_u32_be(buf, s);
	elseif c == "x" then
		return fmt_i + 1, read_i64_be(buf, s);
	elseif c == "t" then
		return fmt_i + 1, read_u64_be(buf, s);
	elseif c == "d" then
		return fmt_i + 1, read_f64_be(buf, s);
	elseif c == "s" or c == "o" or c == "g" then
		return fmt_i + 1, buf:sub(s, e - 1);
	elseif c == "r" then
		return fmt_i + 1, (buf:sub(s, e):gsub(".", function (c) return ("%02x"):format(string.byte(c)) end));
	elseif c == "v" then
		local format = buf:sub(s, e):match "%z([^%z]+)$";
		local _, res = read_fmt(format, 1, buf, s, e - 1 - #format);
		return fmt_i + 1, res;
	elseif c == "m" then
		local fmt_j, inner_align, inner_size = parse_fmt(fmt, fmt_i);

		if s > e then return fmt_j, nil end

		s = alignof(s, inner_align);
		if not inner_size then
			e -= 1;
		end

		return read_fmt(fmt, fmt_i, buf, s, e);
	elseif c == "a" then
		fmt_i += 1;
		c = fmt:at(fmt_i);

		if c == "y" then return fmt_i + 1, buf:sub(s, e) end

		local fmt_j, inner_align, inner_size = parse_fmt(fmt, fmt_i);

		s = alignof(s, inner_align);

		if s > e then
			return fmt_j, {};
		end

		local n;

		if inner_size then
			n = (e - s + 1) / inner_size;
		else
			local offset_size = get_offset_size(s, e);
			n = ((e - s + 1) - read_offset(buf, s, e, 1)) / offset_size;
		end
		local curr_s = s;

		assert(not (n % 1 > 0), "offset calculation error");
		assert(n > 0, "negative array length");
		n = math.floor(n);

		local res = {};
		for i = 1, n do
			local curr_e;

			if inner_size then
				curr_e = s + (i - 1) * inner_size;
			else
				curr_e = s + read_offset(buf, s, e, n - i + 1) - 1;
			end
			curr_s = alignof(curr_s, inner_align);

			if c == "{" then
				local _, tuple = read_fmt(fmt, fmt_i, buf, curr_s, curr_e);
				res[tuple[1]] = tuple[2];
			else
				local _, v = read_fmt(fmt, fmt_i, buf, curr_s, curr_e);
				res[i] = v;
			end

			curr_s = curr_e + 1;
		end

		return fmt_j, res;
	elseif c == "(" or c == "{" then
		local fmt_j, align = parse_fmt(fmt, fmt_i);
		if s > e then return fmt_j, {} end

		fmt_i += 1;

		s = alignof(s, align);

		local offset_size = get_offset_size(s, e);

		local res = {};
		local curr_s = s;

		local offset_i = 0;

		while true do
			if c == "(" and fmt:at(fmt_i) == ")" then break end
			if c == "{" and fmt:at(fmt_i) == "}" then break end

			local name = #res + 1;

			if fmt:at(fmt_i) == "$" then
				fmt_i += 1;
				name = fmt:match("^(.-):", fmt_i);
				assert(name, "invalid gvariant syntax");
				fmt_i += #name + 1;
			end

			local fmt_j, inner_align, inner_size = parse_fmt(fmt, fmt_i);

			curr_s = alignof(curr_s, inner_align);
			local curr_e;

			if inner_size then
				curr_e = curr_s + inner_size - 1;
			elseif fmt:at(fmt_j):find "[)}]" then
				curr_e = e - offset_size * offset_i;
			else
				offset_i += 1;
				curr_e = s + read_offset(buf, s, e, offset_i) - 1;
			end

			assert(curr_e - curr_s + 1 >= 0, "negative length segment");

			local fmt_j, val = read_fmt(fmt, fmt_i, buf, curr_s, curr_e);
			res[name] = val;

			curr_s = curr_e + 1;
			fmt_i = fmt_j;
		end

		fmt_i += 1;

		return fmt_i, res;
	else
		error "malformed gvariant format";
	end
end

--- @param fmt string
--- @param buf string
return function (fmt, buf)
	local _, res = read_fmt("(" .. fmt:gsub("[%s,]", "") .. ")", 1, buf, 1, #buf);
	return res;
end

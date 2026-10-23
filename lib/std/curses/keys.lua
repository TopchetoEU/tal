local fs = require "std.os.fs"
local ansi = require "std.curses.ansi";

--- @class std.curses.keys.evn
--- @class std.curses.keys.evn
--- @field evn "down" | "up" | "repeat"
--- @field key? integer Key code that was pressed
--- @field chr? integer UTF-8 codepoint which was inputted
--- @field mod integer

--- @class std.curses.keys
--- @field _rawend fun()
--- @field _queue std.curses.keys.evn[]
local keys = {};
keys.__index = keys;
keys.__metatable = "std.curses.keys";

keys.codes = {
	ESCAPE = 27,
	ENTER = 13,
	TAB = 9,
	BACKSPACE = 127,

	INSERT = 0xE002,
	DELETE = 0xE003,

	PAGE_UP = 0xE005,
	PAGE_DOWN = 0xE006,
	HOME = 0xE007,
	END = 0xE008,

	UP = 0xE00A,
	DOWN = 0xE00B,
	RIGHT = 0xE00C,
	LEFT = 0xE00D,

	CAPS_LOCK = 0xE00E,
	SCROLL_LOCK = 0xE00F,
	NUM_LOCK = 0xE010,

	PRINT_SCREEN = 0xE011,
	PAUSE = 0xE012,
	MENU = 0xE013,

	F1 = 0xE014,
	F2 = 0xE015,
	F3 = 0xE016,
	F4 = 0xE017,
	F5 = 0xE018,
	F6 = 0xE019,
	F7 = 0xE01A,
	F8 = 0xE01B,
	F9 = 0xE01C,
	F10 = 0xE01D,
	F11 = 0xE01E,
	F12 = 0xE01F,
	F13 = 0xE020,
	F14 = 0xE021,
	F15 = 0xE022,
	F16 = 0xE023,
	F17 = 0xE024,
	F18 = 0xE025,
	F19 = 0xE026,
	F20 = 0xE027,
	F21 = 0xE028,
	F22 = 0xE029,
	F23 = 0xE02A,
	F24 = 0xE02B,
	F25 = 0xE02C,
	F26 = 0xE02D,
	F27 = 0xE02E,
	F28 = 0xE02F,
	F29 = 0xE030,
	F30 = 0xE031,
	F31 = 0xE032,
	F32 = 0xE033,
	F33 = 0xE034,
	F34 = 0xE035,
	F35 = 0xE036,

	KP_0 = 0xE037,
	KP_1 = 0xE038,
	KP_2 = 0xE039,
	KP_3 = 0xE03A,
	KP_4 = 0xE03B,
	KP_5 = 0xE03C,
	KP_6 = 0xE03D,
	KP_7 = 0xE03E,
	KP_8 = 0xE03F,
	KP_9 = 0xE040,

	KP_DECIMAL = 0xE041,
	KP_DIVIDE = 0xE042,
	KP_MULTIPLY = 0xE043,
	KP_SUBTRACT = 0xE044,
	KP_ADD = 0xE045,
	KP_ENTER = 0xE046,
	KP_EQUAL = 0xE047,
	KP_SEPARATOR = 0xE048,
	KP_LEFT = 0xE049,
	KP_RIGHT = 0xE04A,
	KP_UP = 0xE04B,
	KP_DOWN = 0xE04C,
	KP_PAGE_UP = 0xE04D,
	KP_PAGE_DOWN = 0xE04E,
	KP_HOME = 0xE04F,
	KP_END = 0xE050,
	KP_INSERT = 0xE051,
	KP_DELETE = 0xE052,
	KP_BEGIN = 0xE053,

	MEDIA_PLAY = 0xE054,
	MEDIA_PAUSE = 0xE055,
	MEDIA_PLAY_PAUSE = 0xE056,
	MEDIA_REVERSE = 0xE057,
	MEDIA_STOP = 0xE058,
	MEDIA_FAST_FORWARD = 0xE059,
	MEDIA_REWIND = 0xE05A,
	MEDIA_TRACK_NEXT = 0xE05B,
	MEDIA_TRACK_PREVIOUS = 0xE05C,
	MEDIA_RECORD = 0xE05D,

	LOWER_VOLUME = 0xE05E,
	RAISE_VOLUME = 0xE05F,
	MUTE_VOLUME = 0xE060,

	LEFT_SHIFT = 0xE061,
	LEFT_CONTROL = 0xE062,
	LEFT_ALT = 0xE063,
	LEFT_SUPER = 0xE064,
	LEFT_HYPER = 0xE065,
	LEFT_META = 0xE066,

	RIGHT_SHIFT = 0xE067,
	RIGHT_CONTROL = 0xE068,
	RIGHT_ALT = 0xE069,
	RIGHT_SUPER = 0xE06A,
	RIGHT_HYPER = 0xE06B,
	RIGHT_META = 0xE06C,

	ISO_LEVEL3_SHIFT = 0xE06D,
	ISO_LEVEL5_SHIFT = 0xE06E,
};
keys.modifiers = {
	SHIFT = 1 << 0,
	ALT = 1 << 1,
	CTRL = 1 << 2,
	SUPER = 1 << 3,
	HYPER = 1 << 4,
	META = 1 << 5,
	CAPS_LOCK = 1 << 6,
	NUM_LOCK = 1 << 7,
};

-- Describes all translations from non-u suffixed1 ESC codes
local translations = {
	["2"] = keys.codes.INSERT,
	["3"] = keys.codes.DELETE,

	A = keys.codes.UP,
	B = keys.codes.DOWN,
	C = keys.codes.RIGHT,
	D = keys.codes.LEFT,
	["57427"] = keys.codes.KP_BEGIN, E = keys.codes.KP_BEGIN,

	["5"] = keys.codes.PAGE_UP, H = keys.codes.HOME,
	["6"] = keys.codes.PAGE_DOWN,
	["7"] = keys.codes.HOME,
	["8"] = keys.codes.END, F = keys.codes.END,

	["11"] = keys.codes.F1,
	["12"] = keys.codes.F2,
	["13"] = keys.codes.F3,
	["14"] = keys.codes.F4,
	["15"] = keys.codes.F5,
	["17"] = keys.codes.F6,
	["18"] = keys.codes.F7,
	["19"] = keys.codes.F8,
	["20"] = keys.codes.F9,
	["21"] = keys.codes.F10,
	["23"] = keys.codes.F11,
	["24"] = keys.codes.F12,
	["29"] = keys.codes.MENU,

	P = keys.codes.F1,
	Q = keys.codes.F2,
	R = keys.codes.F3,
	S = keys.codes.F4,
};

--- @return std.curses.keys.evn?
function keys:read()
	local c;

	if #self._queue > 0 then
		return table.remove(self._queue);
	end

	c = fs.stdin:readbyte();
	if not c then return nil end

	-- TODO: parse non-kitty codes
	local mod = 0;

	if c == 27 then
		c = fs.stdin:readbyte();
		if not c then
			table.insert(self._queue, { evn = "up", key = keys.codes.ESCAPE, mod = 0 });
			return { evn = "down", key = keys.codes.ESCAPE, mod = 0 };
		end

		if c == string.byte "[" or c == string.byte "O" then
			local args = {};
			local curr_arg = nil;

			while true do
				c = fs.stdin:readbyte();
				if not c then return nil end

				local sc = string.char(c);

				if sc:match "[0-9:]" then
					curr_arg = curr_arg and (curr_arg .. sc) or sc;
				elseif sc:match ";" then
					table.insert(args, curr_arg or "");
					curr_arg = "";
				else
					table.insert(args, curr_arg);
					args.cmd = sc;
					break;
				end
			end

			--- @type std.curses.keys.evn
			local evn = {
				evn = "down",
				mod = 0,
			};

			if args.cmd ~= "u" then
				evn.key = translations[args.cmd] or translations[args[1]];
			else
				local parts = table.from(args[1]:split ":" --[[@as fun(): string?]]);

				local lower = parts[1] and tonumber(parts[1]);
				local real = parts[2] and tonumber(parts[2]);
				local key = parts[3] and tonumber(parts[3]);

				evn.chr = real or lower;
				evn.key = key or lower;

				if evn.key >= 0xE000 and evn.key <= 0xE100 or evn.key == 127 or evn.key == 27 then
					evn.chr = nil;
				end

				if evn.key == keys.codes.KP_0 then
					evn.chr = string.byte "0";
				elseif evn.key == keys.codes.KP_1 then
					evn.chr = string.byte "1";
				elseif evn.key == keys.codes.KP_2 then
					evn.chr = string.byte "2";
				elseif evn.key == keys.codes.KP_3 then
					evn.chr = string.byte "3";
				elseif evn.key == keys.codes.KP_4 then
					evn.chr = string.byte "4";
				elseif evn.key == keys.codes.KP_5 then
					evn.chr = string.byte "5";
				elseif evn.key == keys.codes.KP_6 then
					evn.chr = string.byte "6";
				elseif evn.key == keys.codes.KP_7 then
					evn.chr = string.byte "7";
				elseif evn.key == keys.codes.KP_8 then
					evn.chr = string.byte "8";
				elseif evn.key == keys.codes.KP_9 then
					evn.chr = string.byte "9";
				elseif evn.key == keys.codes.KP_ADD then
					evn.chr = string.byte "+";
				elseif evn.key == keys.codes.KP_SUBTRACT then
					evn.chr = string.byte "-";
				elseif evn.key == keys.codes.KP_MULTIPLY then
					evn.chr = string.byte "*";
				elseif evn.key == keys.codes.KP_DIVIDE then
					evn.chr = string.byte "/";
				elseif evn.key == keys.codes.KP_ENTER then
					evn.chr = string.byte "\r";
				elseif evn.key == keys.codes.KP_EQUAL then
					evn.chr = string.byte "=";
				elseif evn.key == keys.codes.KP_DECIMAL then
					evn.chr = string.byte ".";
				end
			end

			if args[2] then
				local parts = table.from(args[2]:split ":" --[[@as fun(): string?]]) or {};

				if parts[1] then
					evn.mod = (tonumber(parts[1]) or 1) - 1;
				end

				if parts[2] == "2" then
					evn.evn = "repeat";
				elseif parts[2] == "3" then
					evn.evn = "up";
				end
			end

			if (evn.mod & (keys.modifiers.CTRL | keys.modifiers.ALT)) ~= 0 then
				evn.chr = nil;
			end


			return evn;
		end

		mod |= keys.modifiers.ALT;
	end

	fs.stdin:unreadbyte(c);

	local chr = fs.stdin:readutf8(true);
	if not chr then return nil end

	-- From my crude experimentation:
	-- - Ctrl+[letter] -> the number of the letter
	-- - Ctrl+2 -> 0
	-- - Ctrl+3-7 -> 27-31
	-- - Ctrl+8 -> 127
	-- - Ctrl+Backspace -> 8
	-- - Ctrl+[ -> 27
	-- - Ctrl+\ -> 28
	-- - Ctrl+] -> 29

	-- We will ignore Ctrl+[number] and implement the letters, [, \ and ]

	local key;

	if chr == 0 then
		mod |= keys.modifiers.CTRL;
		key = 48;
	elseif chr >= 1 and chr <= 26 then
		mod |= keys.modifiers.CTRL;
		key = chr + 96;
	-- 27 is also the indicator for an ALT key, so we can't really do this
	-- elseif chr == 27 then
	-- 	key = keys.codes.ESCAPE;
	elseif chr == 28 then
		mod |= keys.modifiers.CTRL;
		key = string.byte "\\";
	elseif chr == 29 then
		mod |= keys.modifiers.CTRL;
		key = string.byte "]";
	elseif chr == 30 then
		mod |= keys.modifiers.CTRL;
		key = string.byte "6";
	elseif chr == 31 then
		mod |= keys.modifiers.CTRL;
		key = string.byte "/";
	end

	if (mod & (keys.modifiers.CTRL | keys.modifiers.ALT)) ~= 0 then
		chr = nil;
	end

	table.insert(self._queue, { evn = "up", chr = chr, key = key, mod = mod });
	--- @type std.curses.keys.evn
	return { evn = "down", chr = chr, key = key, mod = mod };
end

function keys:iter()
	return keys.read, self;
end

function keys:fin()
	io.stderr:write(ansi.keycode_end);
	self._rawend();
end

function keys.new()
	local rawend = fs.ttyraw();
	io.stderr:write(ansi.keycode_begin);

	return setmetatable({ _rawend = rawend, _queue = {} }, keys);
end

return keys;

local ffi = require "nat.ffi";
local str = require "std.str";

--- @type std.curses.colors
local ansi = {};

local colors = {
	black = 0,
	red = 1,
	green = 2,
	yellow = 3,
	blue = 4,
	magenta = 5,
	cyan = 6,
	white = 7,
};

--- @param cmd string
--- @param ... integer | string
function ansi.gen_seq(cmd, ...)
	return "";
end

--- @param foreground boolean
--- @param col { r: integer, g: integer, b: integer } | string
function ansi.gen_color(foreground, col)
	return "";
end
function ansi.gen_pos_set(row, column)
	return "";
end
--- @param row_ch integer
--- @param col_ch integer
function ansi.gen_pos_move(row_ch, col_ch)
	return "";
end
--- @param mode "line" | "screen" | "all" = "screen"
function ansi.gen_clear(mode)
	return "";
end

ansi.reset = "";
ansi.bold = "";
ansi.dim = "";
ansi.italic = "";
ansi.underline = "";
ansi.blink = "";
ansi.strike = "";

ansi.no_italic = "";
ansi.no_underline = "";
ansi.no_blink = "";
ansi.no_strike = "";

return ansi;

local ffi = require "nat.ffi";
local str = require "std.str";

--- @class std.curses.colors
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
	return "\27[" .. table.concat({ ... }, ";") .. cmd;
end

--- @param foreground boolean
--- @param col { r: integer, g: integer, b: integer } | string
function ansi.gen_color(foreground, col)
	if type(col) == "table" then
		if foreground then
			return ansi.gen_seq("m", 38, 2, col.r, col.g, col.b);
		else
			return ansi.gen_seq("m", 48, 2, col.r, col.g, col.b);
		end
	elseif type(col) == "string" then
		local name = col:lower();
		local bright = name:match("^light_(.+)$");
		local code;
		if bright then
			code = colors[bright] + 90;
		else
			code = colors[name] + 30;
		end

		if not foreground then
			code = code + 10;
		end

		return ansi.gen_seq("m", code);
	else
		error(errors.never);
	end
end
function ansi.gen_pos_set(row, column)
	return ansi.gen_seq("H", row, column);
end
--- @param row_ch integer
--- @param col_ch integer
function ansi.gen_pos_move(row_ch, col_ch)
	local parts = {};

	if row_ch < 0 then
		table.insert(parts, ansi.gen_seq("A", -row_ch));
	end
	if row_ch > 0 then
		table.insert(parts, ansi.gen_seq("B", row_ch));
	end

	if col_ch < 0 then
		table.insert(parts, ansi.gen_seq("D", -col_ch));
	end
	if col_ch > 0 then
		table.insert(parts, ansi.gen_seq("C", col_ch));
	end

	return table.concat(parts);
end
--- @param mode "line" | "screen" | "all" = "screen"
function ansi.gen_clear(mode)
	mode = mode or "screen";

	if mode == "screen" then
		return ansi.gen_seq("J", 2);
	elseif mode == "all" then
		return ansi.gen_seq("J", 3);
	elseif mode == "line" then
		return ansi.gen_seq("K", 2);
	else
		error(errors.never);
	end
end

ansi.reset = ansi.gen_seq("m", 0);
ansi.bold = ansi.gen_seq("m", 1);
ansi.dim = ansi.gen_seq("m", 2);
ansi.italic = ansi.gen_seq("m", 3);
ansi.underline = ansi.gen_seq("m", 4);
ansi.blink = ansi.gen_seq("m", 5);
ansi.strike = ansi.gen_seq("m", 9);

-- ansi.no_dim = format("m", 22);
ansi.no_italic = ansi.gen_seq("m", 23);
ansi.no_underline = ansi.gen_seq("m", 24);
ansi.no_blink = ansi.gen_seq("m", 25);
ansi.no_strike = ansi.gen_seq("m", 29);

return ansi;

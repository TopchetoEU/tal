local keys = require "std.con.keys";
local utf8 = require "std.fmt.utf8";
local ansi = require "std.con.ansi";

--- @param k std.con.keys
local function pmain(k)

	io.stderr:write(ansi.gen_clear "screen");
	io.stderr:write(ansi.gen_clear "all");
	io.stderr:write(ansi.gen_pos_set(1, 1));
	print "VERY crude example editor, start editing...";

	--- @type string[][]
	local lines = {{"H", "e", "l", "l", "o", ",", " ", "w", "o", "r", "l", "d", "!"}};
	local row = 1;
	local col = 1;

	for evn in k:iter() do
		evn.mod &= 0xF;

		if evn.evn ~= "up" then
			if evn.key == string.byte "c" and (evn.mod & keys.modifiers.CTRL) ~= 0 then
				break;
			end

			if evn.key == keys.codes.ENTER and evn.mod == 0 then
				local before = table.move(lines[row], 1, col - 1, 1, {});
				local after = table.move(lines[row], col, #lines[row], 1, {});
				table.insert(lines, row, before);
				row += 1;
				lines[row] = after;
				col = 1;
			elseif evn.key == keys.codes.TAB and evn.mod == 0 then
				for _ = 1, 4 do
					table.insert(lines[row], col, " ");
					col += 1;
				end
			elseif evn.key == keys.codes.UP and evn.mod == 0 then
				row -= 1;
				if row < 1 then row = 1 end
			elseif evn.key == keys.codes.DOWN and evn.mod == 0 then
				row += 1;
				if row > #lines then row = #lines end
			elseif evn.key == keys.codes.LEFT and evn.mod == 0 then
				col -= 1;
				if col < 1 then
					if row > 1 then
						row -= 1;
						col = #lines[row] + 1;
					else
						col = 1;
					end
				end
			elseif evn.key == keys.codes.RIGHT and evn.mod == 0 then
				col += 1;
				if col > #lines[row] + 1 then
					if row < #lines then
						row += 1;
						col = 1;
					else
						col = #lines[row] + 1;
					end
				end
			elseif evn.key == keys.codes.HOME then
				col = 1;
			elseif evn.key == keys.codes.END then
				col = #lines[row] + 1;
			elseif evn.key == keys.codes.DELETE then
				if col >= #lines[row] + 1 then
					col = #lines[row] + 1;

					if row < #lines then
						local next = table.remove(lines, row + 1);
						table.move(next, 1, #next, #lines[row] + 1, lines[row]);
					end
				else
					table.remove(lines[row], col)
				end
			elseif evn.key == keys.codes.BACKSPACE then
				if col <= 1 then
					if row > 1 then
						row -= 1;
						col = #lines[row] + 1;
						local next = table.remove(lines, row + 1);
						table.move(next, 1, #next, #lines[row] + 1, lines[row]);
					end
				else
					col -= 1;
					table.remove(lines[row], col);
				end
			elseif evn.chr then
				if col > #lines[row] + 1 then
					col = #lines[row] + 1;
				end

				table.insert(lines[row], col, utf8.encode(evn.chr));
				col += 1;
			end
		end

		io.stderr:write(ansi.gen_pos_set(1, 1));
		io.stderr:write(ansi.gen_clear "screen");
		io.stderr:write(ansi.gen_clear "all");

		for _, line in ipairs(lines) do
			for _, c in ipairs(line) do
				io.stderr:write(c);
			end

			io.stderr:write "\r\n";
		end

		io.stderr:write(ansi.gen_pos_set(row, col));
	end
end

return function ()
	local k = keys.new();

	local ok, err = spcall(pmain, k);
	if not ok then eprint(err) end

	k:fin();
end

local base64 = {};
local masks = { 0x1, 0x3, 0x7, 0xF, 0x1F, 0x3F, 0x7F, 0xFF, 0x1FF, 0x3FF, 0x7FF, 0xFFF };

local function extract(v, from, width)
	return bit.band(bit.rshift(v, from), masks[width]);
end

--- @param str string
function base64.encode(str)
	local alphabet = {
		[0] = "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
		"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
		"0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
		"+", "/", "="
	};

	local parts = {};
	local k, n = 1, #str;
	local lastn = n % 3;

	for i = 1, n - lastn, 3 do
		local a, b, c = str:byte(i, i + 2);
		local v = a * 0x10000 + b * 0x100 + c;
		parts[k] = alphabet[extract(v, 18, 6)] .. alphabet[extract(v, 12, 6)] .. alphabet[extract(v, 6, 6)] .. alphabet[extract(v, 0, 6)];
		k = k + 1;
	end

	if lastn == 2 then
		local a, b = str:byte(n - 1, n);
		local v = a * 0x10000 + b * 0x100;
		parts[k] = alphabet[extract(v, 18, 6)] .. alphabet[extract(v, 12, 6)] .. alphabet[extract(v, 6, 6)] .. alphabet[64];
	elseif lastn == 1 then
		local v = str:byte(n) * 0x10000;
		parts[k] = alphabet[extract(v, 18, 6)] .. alphabet[extract(v, 12, 6)] .. alphabet[64] .. alphabet[64];
	end

	return table.concat(parts);
end

return base64;

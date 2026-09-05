local json = require "std.fmt.json";
local utils = {};

--- @param stream std.strtxt
function utils.read_string(stream)
	local res = stream:read "l";
	return res and res:unquote();
end

--- @param stream std.strtxt
--- @param str string
function utils.write_string(stream, str)
	stream:write(str:quote(), "\n");
end
-- --- @param stream std.io.stream
-- function utils.read_string(stream)
-- 	local slen, err = stream:read(4);
-- 	if not slen then return nil, err end

-- 	local len =
-- 		string.byte(slen, 1) +
-- 		string.byte(slen, 2) * 256 +
-- 		string.byte(slen, 3) * 256 * 256 +
-- 		string.byte(slen, 4) * 256 * 256 * 256;

-- 	return stream:read(len);
-- end

-- --- @param stream std.io.stream
-- --- @param str string
-- function utils.write_string(stream, str)
-- 	local len = #str;
-- 	local len_str = "";

-- 	for i = 1, 4 do
-- 		len_str = len_str .. string.char(len % 256);
-- 		len = len - len % 256;
-- 		len = len / 256;
-- 	end

-- 	local slen, err = stream:write(len_str);
-- 	if not slen then return nil, err end

-- 	return stream:write(str);
-- end

function utils.print_event(evn)
	if evn.type == "system" then
		print(evn.msg);
	elseif evn.type == "join" then
		print(evn.who .. " joined the chat");
	elseif evn.type == "leave" then
		print(evn.who .. " left the chat");
	elseif evn.type == "shout" then
		print("!!!<" .. evn.from .. "> " .. evn.msg);
	elseif evn.type == "msg" then
		print("<" .. evn.from .. "> " .. evn.msg);
	else
		print("Event of unknown type: " .. json.stringify(evn, "\t"));
	end
end

return utils;

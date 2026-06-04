local buffer = require "string.buffer";

---@diagnostic disable: cast-local-type

local ack_codes = {
	"connection Refused: unacceptable protocol version",
	"connection Refused: identifier rejected",
	"connection Refused: server unavailable",
	"connection Refused: bad user name or password",
	"connection Refused: not authorized",
};

--- @param data string
--- @param i integer
local function read_uint8(data, i)
	if i > #data then error("unexpected EOF") end
	return i + 1, data:byte(i);
end
--- @param data string
--- @param i integer
local function read_uint16(data, i)
	if i + 1 > #data then error("unexpected EOF") end
	return i + 2, data:byte(i) * 256 + data:byte(i + 1);
end
--- @param data string
--- @param i integer
local function read_utf8(data, i)
	if i + 1 > #data then error("unexpected EOF") end
	local len = data:byte(i) * 256 + data:byte(i + 1);
	i = i + 2;

	if i + len - 1 > #data then error("unexpected EOF") end
	return i + len, data:sub(i, i + len - 1);
end

local function to_read(next_chunk)
	local remaining = nil;

	-- wtf
	return function (n)
		if n == 0 then return "" end
		if next_chunk == nil then return nil end

		local res = {};
		local i;

		if remaining ~= nil then
			i = #remaining;
			res[1] = remaining;
		else
			i = 0;
		end

		while i < n do
			local curr = next_chunk();
			if curr == nil then
				remaining = nil;
				next_chunk = nil;
				local str = table.concat(res, "");
				if str == "" then
					return nil;
				else
					return "";
				end
			end

			i = i + #curr;
			res[#res + 1] = curr;
		end

		local last = table.remove(res);

		local overshot = i - n;
		local used = #last - overshot;

		remaining = last:sub(used + 1);
		res[#res + 1] = last:sub(1, used);
		local val = table.concat(res, "");
		assert(#val == n, "Incorrect len");
		return val;
	end
end

local function raw_packet_reader(next_chunk)
	local reader = to_read(next_chunk);

	local function read_byte()
		local char = reader(1);
		if char == nil then return nil end
		return char:byte(1);
	end

	return function()
		if reader == nil then return nil end

		local byte = read_byte();
		if byte == nil then
			reader = nil;
			return nil;
		end
		local type, flags = byte << 4, byte & 0x0F;

		local len, n = 0, 0;

		repeat
			local curr = read_byte();
			if not curr then error "unexpected EOF" end

			len |= (curr & 0x7F) << n;
			n += 7;
		until bit.band(curr, 0x80) == 0;

		local body = reader(len);

		return type, flags, body;
	end
end

local function read_pk_connect(buff)
	local i, name, version, flags, keepalive_max, client_id, will_topic, will_msg, username, password;

	i, name = read_utf8(buff, 1);
	if name ~= "MQIsdp" then error("protocol name is not 'MQIsdp', found '" .. name .. "' instead") end

	i, version = read_uint8(buff, i);
	if version ~= 3 then error("protocol version is not '3', found '" .. version .. "' instead") end

	i, flags = read_uint8(buff, i);

	local clean_session = (flags & 2) ~= 0;
	local will = (flags & 4) ~= 0;
	local will_qos = (flags & 24) >> 3;
	local will_retain = (flags & 32) ~= 0;
	local has_password = (flags & 64) ~= 0;
	local has_username = (flags & 128) ~= 0;

	i, keepalive_max = read_uint16(buff, i);

	i, client_id = read_utf8(buff, i);
	if will then
		i, will_topic = read_utf8(buff, i);
		i, will_msg = read_utf8(buff, i);
	end
	if has_username then i, username = read_utf8(buff, i) end
	if has_password then i, password = read_utf8(buff, i) end

	return {
		type = "connect",
		clean_session = clean_session,

		keepalive_max = keepalive_max,
		client_id = client_id,
		username = username,
		password = password,

		will = will and {
			topic = will_topic,
			msg = will_msg,
			qos = will_qos,
			retain = will_retain
		} or nil,
	};
end
local function read_pk_conack(buff)
	local i = 1;
	local code, msg;

	i = read_uint8(buff, i);
	i, code = read_uint8(buff, i);

	if code == 0 then
		msg = "success";
	else
		msg = ack_codes[code] or "reserved code given";
	end

	return {
		type = "ack",
		code = code,
		msg = msg,
	};
end
local function read_pk_publish(buff, flags)
	local retain = (flags & 1) ~= 0;
	local qos = (flags >> 1) & 3;
	local dup = (flags & 8) ~= 0;

	local i = 1;
	local topic, msg_id;

	i, topic = read_utf8(buff, i);
	i, msg_id = read_uint16(buff, i);

	local data = buff:sub(i);

	return {
		type = "publish",
		retain = retain,
		qos = qos,
		dup = dup,
		topic = topic,
		id = msg_id,
		data = data,
	};
end
local function read_pk_puback(buff)
	local _, id = read_uint16(buff, 1);

	return {
		type = "puback",
		id = id,
	};
end
local function read_pk_pubrec(buff)
	local _, id = read_uint16(buff, 1);

	return {
		type = "pubrec",
		id = id,
	};
end
local function read_pk_pubrel(buff)
	local _, id = read_uint16(buff, 1);

	return {
		type = "pubrel",
		id = id,
	};
end
local function read_pk_pubcomp(buff)
	local _, id = read_uint16(buff, 1);

	return {
		type = "pubcomp",
		id = id,
	};
end
local function read_pk_subscribe(buff)
	local i = 1;
	local id;
	local topics = {};

	i, id = read_uint16(buff, i);

	while i < #buff do
		local name, qos;
		i, name = read_utf8(buff, i);
		i, qos = read_uint8(buff, i);
		table.insert(topics, { name = name, qos = qos });
	end

	return {
		type = "subscribe",
		id = id,
		topics = topics,
	};
end
local function read_pk_suback(buff)
	local i = 1;
	local id;
	local granted_qos = {};

	i, id = read_uint16(buff, i);

	while i < #buff do
		local qos;
		qos, i = read_uint8(buff, i);
		table.insert(granted_qos, qos);
	end

	return {
		type = "suback",
		id = id,
		granted_qos = granted_qos,
	};
end
local function read_pk_unsubscribe(buff)
	local i = 1;
	local id;
	local topics = {};

	i, id = read_uint16(buff, i);

	while i < #buff do
		local name;
		i, name = read_utf8(buff, i);
		table.insert(topics, name);
	end

	return {
		type = "unsubscribe",
		id = id,
		topics = topics,
	};
end
local function read_pk_unsuback(buff)
	local _, id = read_uint16(buff, 1);

	return {
		type = "unsuback",
		id = id,
	};
end
local function read_pk_pingreq()
	return { type = "pingreq" };
end
local function read_pk_pingresp()
	return { type = "pingresp" };
end
local function read_pk_disconnect()
	return { type = "disconnect" };
end

local readers = {
	read_pk_connect,
	read_pk_conack,
	read_pk_publish,
	read_pk_puback,
	read_pk_pubrec,
	read_pk_pubrel,
	read_pk_pubcomp,
	read_pk_subscribe,
	read_pk_suback,
	read_pk_unsubscribe,
	read_pk_unsuback,
	read_pk_pingreq,
	read_pk_pingresp,
	read_pk_disconnect,
};

local function packet_reader(next_chunk)
	local raw_packets = raw_packet_reader(next_chunk);

	return function ()
		if raw_packets == nil then return nil end

		local type, flags, buff = raw_packets();
		if type == nil then
			raw_packets = nil;
			return nil;
		end

		local reader = readers[type];
		if reader == nil then
			error(table.concat { "Unknown packet type '", type, "'" });
		end

		return reader(buff, flags);
	end
end

local function pk_wrap(type, flags, parts)
	local res = buffer.new();
	res:put(string.char(type * 16 + flags));

	local len = #parts;

	repeat
		local byte = len & 0x7F;
		len >>= 7;
		if len ~= 0 then
			byte = byte | 0x80;
		end

		res:put(string.char(byte));
	until len == 0;

	res:put(parts);
	return tostring(res);
end

local writers = {};
function writers.connect(pk)
	local flags = 0;

	if pk.clean_session then flags = flags + 2 end
	if pk.password then flags = flags + 64 end
	if pk.username then flags = flags + 128 end

	if pk.will then
		flags = flags + 4;
		if pk.will.retian then flags = flags + 32 end
		flags = flags + bit.band(pk.will.qos, 3) * 8;
	end

	local parts = buffer.new();
	parts:put "\x06\x00MQIsdp";
	parts:put(string.char(
		3, flags,
		pk.keepalive_max >> 8, pk.keepalive_max & 0xFF,
		#pk.client_id >> 8, #pk.client_id & 0xFF
	));
	parts:put(pk.client_id);

	if pk.will then
		parts:put(string.char(#pk.will.topic >> 8, #pk.will.topic), pk.will.topic);
		parts:put(string.char(#pk.will.msg >> 8, #pk.will.msg), pk.will.msg);
	end
	if pk.username then
		parts:put(string.char(#pk.username >> 8, #pk.username), pk.username);
	end
	if pk.password then
		parts:put(string.char(#pk.password >> 8, #pk.password), pk.password);
	end

	return pk_wrap(1, 0, parts);
end
function writers.ack(pk)
	return pk_wrap(2, 0, string.char(0, pk.code or 0));
end
function writers.publish(pk)
	local flags = ((pk.qos or 0) & 3) << 1;
	if pk.retain then flags = flags | 1 end
	if pk.dup then flags = flags | 8 end

	return pk_wrap(3, flags,
		string.char(#pk.topic >> 8, #pk.topic & 0xFF) .. pk.topic ..
		string.char(pk.id >> 8, pk.id & 0xFF) ..
		pk.data
	);
end
function writers.puback(pk)
	return pk_wrap(4, 2, string.char(pk.id >> 8, pk.id & 0xFF));
end
function writers.pubrec(pk)
	return pk_wrap(5, 0, string.char(pk.id >> 8, pk.id & 0xFF));
end
function writers.pubrel(pk)
	return pk_wrap(6, 0, string.char(pk.id >> 8, pk.id & 0xFF));
end
function writers.pubcomp(pk)
	return pk_wrap(7, 0, string.char(pk.id >> 8, pk.id & 0xFF));
end
function writers.subscribe(pk)
	local parts = buffer.new();
	parts:put(string.char(pk.id >> 8, pk.id & 0xFF));

	for i = 1, #pk.topics do
		parts:put(string.char(#pk.topics[i].name >> 8, #pk.topics[i].name & 0xFF), pk.topics[i].name, string.char(pk.topics[i].qos));
	end

	return pk_wrap(8, 2, parts);
end
function writers.suback(pk)
	local parts = buffer.new();
	parts:put(string.char(pk.id >> 8, pk.id & 0xFF));

	for i = 1, #pk.topics do
		parts:put(string.char(pk.granted_qos[i]));
	end

	return pk_wrap(9, 0, parts);
end
function writers.unsubscribe(pk)
	local parts = buffer.new();
	parts:put(string.char(pk.id >> 8, pk.id & 0xFF));

	for i = 1, #pk.topics do
		parts:put(string.char(#pk.topics[i] >> 8, #pk.topics[i] & 0xFF), pk.topics[i]);
	end

	return pk_wrap(10, 2, parts);
end
function writers.unsuback(pk)
	return pk_wrap(11, 0, string.char(pk.id >> 8, pk.id & 0xFF));
end
function writers.pingreq()
	return pk_wrap(12, 0, "");
end
function writers.pingresp()
	return pk_wrap(13, 0, "");
end
function writers.disconnect()
	return pk_wrap(14, 0, "");
end

local function write_packet(pk)
	local writer = writers[pk.type];
	if writer == nil then
		error(table.concat { "Unknown packet type '", pk.type or "(nil)", "'" });
	end

	return writer(pk);
end

return {
	read = packet_reader,
	write = write_packet,
};

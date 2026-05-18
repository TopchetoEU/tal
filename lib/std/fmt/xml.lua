--- @alias xml_node_raw { tag: string, attribs: { [string]: string }, [integer]: xml_element }
--- @alias xml_element string | xml_node

--- @class xml_node
--- @field tag string
--- @field attribs { [string]: string }
--- @field [integer] xml_element
local xml_node = {};
xml_node.__index = xml_node;
xml_node.__metatable = "std.fmt.xml_node";

--- @param name string?
function xml_node:get_all(name)
	--- @type xml_node[]
	local res = {};

	for _, el in ipairs(self) do
		if type(el) ~= "string" and (not name or el.tag == name) then
			res[#res + 1] = el;
		end
	end

	return res;
end

--- @param name string
function xml_node:get(name)
	local res = self:get_all(name);
	if #res == 0 then
		error("node '" .. name .. "' not found");
	elseif #res > 1 then
		error("multiple nodes '" .. name .. "' exist");
	else
		return res[1];
	end
end

--- @param name string
--- @return xml_node[]
function xml_node:query_all(name)
	local tag, id, classes, attribs;
	local rem = name;

	local function get_tag(rem)
		local tag, res_rem = rem:match "^([^%s#%.%[%]]+)%s*(.*)$";
		if tag then return res_rem, tag end
		return rem;
	end
	local function get_class(rem)
		local class, res_rem = rem:match "^%.([^%s#%.%[%]]+)%s*(.*)$";
		if class then return res_rem, class end
		return rem;
	end
	local function get_id(rem)
		local id, res_rem = rem:match "^#([^%s#%.%[%]]+)%s*(.*)$";
		if id then return res_rem, id end
		return rem;
	end
	local function get_attrib(rem)
		local inner, res_rem = rem:match "^%[%s*([^%]]+)%s*%]%s*(.*)$";
		if not inner then return rem end

		local prop, val = inner:match "^(.-)%s*=%s*(.-)$";
		if prop then
			return res_rem, prop, val;
		else
			return res_rem, inner;
		end
	end

	rem, tag = get_tag(rem);
	rem, id = get_id(rem);

	while true do
		local class, key, val;
		rem, class = get_class(rem);
		if class then
			classes = classes or {};
			classes[class] = 0;
		else
			rem, key, val = get_attrib(rem);
			if key then
				attribs = attribs or {};
				attribs[key] = val or true;
			else
				break;
			end
		end
	end

	if #rem > 0 then error "invalid query" end

	local res = {};

	local function match(el)
		if type(el) == "string" then return false end
		if tag and el.tag ~= tag then return false end
		if id and el.attribs.id ~= id then return false end
		if classes then
			if not el.attribs.class then return false end

			for name in el.attribs.class:gmatch "[^%s]+" do
				if classes[name] then
					classes[name] = classes[name] + 1;
				end
			end

			local ok = true;

			for k, v in pairs(classes) do
				if classes[k] == 0 then
					ok = false;
				end

				classes[k] = 0;
			end

			if not ok then return false end
		end

		if attribs then
			for k, v in pairs(attribs) do
				if v == true then
					if not el.attribs[k] then return false end
				else
					if el.attribs[k] ~= v then return false end
				end
			end
		end

		return true;
	end

	for i = 1, #self do
		if match(self[i]) then
			table.insert(res, self[i]);
		end
	end

	return res;
end

--- @param name string
--- @return xml_node
function xml_node:query(name)
	local res = self:query_all(name);
	if #res == 1 then
		return res[1];
	else
		error("no single element with the query found", 2);
	end
end

--- @param name string
--- @return xml_node
function xml_node:query_first(name)
	local res = self:query_all(name);
	if #res >= 1 then
		return res[1];
	else
		return nil;
	end
end

--- @return string
function xml_node:text()
	if #self == 0 then
		return "";
	elseif #self == 1 and type(self[1]) == "string" then
		--- @diagnostic disable-next-line: return-type-mismatch
		return self[1];
	else
		error "not a text-only node";
	end
end

function xml_node:to_string(level)
	level = level or 0;
	local indent = ("\t"):rep(level);

	local lines = { self.tag .. " {" };

	for k, v in pairs(self.attribs) do
		table.insert(lines, indent .. "\t" .. k .. " = " .. v);
	end

	for i = 1, #self do
		local child = self[i];
		if type(child) == "string" then
			table.insert(lines, indent .. "\t" .. child);
		else
			table.insert(lines, indent .. "\t" .. child:to_string(level + 1));
		end
	end

	if #lines == 1 then
		return self.tag .. "{ }";
	end

	table.insert(lines, indent .. "}");

	return table.concat(lines, "\n");
end

function xml_node:__tostring()
	return self:to_string();
end

--- @param raw xml_node_raw
--- @return xml_node
function xml_node.new(raw)
	local res = setmetatable({
		tag = raw.tag,
		attribs = raw.attribs or {},
	}, xml_node);

	table.move(raw, 1, #raw, 1, res);

	return res;
end

--- @param entity string
local function parse_entity(entity)
	if entity == "amp" then return "&" end
	if entity == "lt" then return "<" end
	if entity == "gt" then return ">" end
	if entity == "quot" then return "\"" end
	if entity == "nbsp" then return "\194\160" end
	local hex = entity:match "#x(.*)";
	if hex then return string.char(assert(tonumber(hex, 16))) end
	return "&" .. entity .. ";";
end

local function skip_spaces(raw, i)
	local next_i = raw:find("[^%s]", i);
	if next_i then return next_i end

	if raw:find("^%s", i) then
		local match = raw:match("^%s*", i);
		if match then return i + #match end
	else
		return i;
	end
end

local function parse_tag(raw, i, state)
	i = skip_spaces(raw, i);

	local tag = raw:match("^[%w0-9%-_:]+", i);
	if tag == nil then
		if state.relaxed then
			return nil, i;
		else
			error("expected tag name near '" .. raw:sub(i, i + 25) .. "'")
		end
	end

	i = i + #tag;

	local attribs = {};

	while true do
		i = skip_spaces(raw, i);

		local all, key, _, val = raw:match("^(([%w0-9%-_:]-)%s*=%s*(['\"])(.-)%3%s*)", i);
		if all then
			attribs[key] = val;
			i = i + #all;
		elseif state.relaxed then
			all, key, val = raw:match("^(([%w0-9%-_:]+)%s*=%s*([^/<>%s]+))", i);
			if all then
				attribs[key] = val;
				i = i + #all;
			else
				all, key = raw:match("^(([%w0-9%-_:]+)%s*)", i);
				if all then
					attribs[key] = "";
					i = i + #all;
				else
					break;
				end
			end
		end
	end

	return { tag = tag, attribs = attribs }, i;
end

local function parse_part(raw, i, state)
	local prev_i = i;
	i = skip_spaces(raw, i);
	if i > prev_i and state.rawtext_n > 0 then
		return { type = "text", text = raw:sub(prev_i, i - 1), space = true }, i;
	end
	local j = i;

	repeat
		local comment_end;

		if raw:sub(i, i + 3) == "<!--" then
			i = i + 4;

			comment_end = raw:find("-->", i);
			if comment_end then
				i = comment_end + 3;
			else
				i = #raw + 1;
			end

			i = skip_spaces(raw, i);
		end
	until not comment_end;

	local fallback = false;

	if i > #raw then
		return { type = "eof" }, i;
	elseif (state.start or state.relaxed) and raw:sub(i, i + 1) == "<?" then
		i = i + 2;

		local tag;
		tag, i = parse_tag(raw, i, state);

		if tag then
			if raw:sub(i, i + 1) == "!>" then
				i = i + 2;

				return { type = "version", tag = tag.tag, attribs = tag.attribs }, i;
			end
		elseif not state.relaxed then
			error("malformed XML near '" .. raw:sub(i, i + 25) .. "'");
		end

		fallback = true;
	elseif (state.start or state.relaxed) and raw:sub(i, i + 1) == "<!" then
		i = i + 2;

		local tag;
		tag, i = parse_tag(raw, i, state);
		if tag then
			if raw:sub(i, i) == ">" then
				i = i + 1;
				return { type = "version", tag = tag.tag, attribs = tag.attribs }, i;
			elseif not state.relaxed then
				error("malformed XML near '" .. raw:sub(i, i + 25) .. "'");
			end
		end

		fallback = true;
	elseif raw:sub(i, i + 1) == "</" then
		i = i + 2;
		i = skip_spaces(raw, i);

		local tag = raw:match("[%w0-9%-_:]+", i);
		if tag then
			i = i + #tag;

			if raw:sub(i, i) == ">" then
				i = i + 1;
				return { type = "end", tag = tag }, i;
			elseif not state.relaxed then
				error("malformed closing tag near '" .. raw:sub(i, i + 25) .. "'");
			end
		elseif not state.relaxed then
			error("expected closing tag name near '" .. raw:sub(i, i + 25) .. "'")
		end

		fallback = true;
	elseif raw:sub(i, i) == "<" then
		i = i + 1;

		local tag;
		tag, i = parse_tag(raw, i, state);
		if tag then
			if raw:sub(i, i + 1) == "/>" then
				i = i + 2;
				return { type = "small", tag = tag.tag, attribs = tag.attribs }, i;
			elseif raw:sub(i, i) == ">" then
				i = i + 1;
				return { type = "begin", tag = tag.tag, attribs = tag.attribs }, i;
			elseif not state.relaxed then
				error("malformed opening tag near '" .. raw:sub(i, i + 25) .. "'");
			end
		end

		fallback = true;
	end

	i = j;

	local text_parts = {};

	if fallback then
		table.insert(text_parts, raw:sub(i, i));
		i = i + 1;
	end

	while i <= #raw do
		local text_end = raw:find("<", i);

		local text_part = raw:sub(i, text_end and text_end - 1 or #raw)
			:match "^%s*(.-)%s*$"
			:gsub("&(.-);", parse_entity);

		if state.rawtext_n == 0 then
			text_part = text_part:gsub("%s+", " ");
		end

		if text_part ~= "" then
			text_parts[#text_parts + 1] = text_part;
		end

		if not text_end then i = #raw + 1 break end

		i = text_end or #raw;

		local comment_end;

		if raw:sub(i, i + 3) == "<!--" then
			i = i + 4;

			comment_end = raw:find("-->", i);
			if comment_end then
				i = comment_end + 3;
			else
				i = #raw + 1;
			end

			i = skip_spaces(raw, i);
		else
			break
		end
	end

	if #text_parts > 0 then
		return { type = "text", text = table.concat(text_parts, " ") }, i;
	elseif i > #raw then
		return { type = "eof" }, i;
	else
		error("malformed XML near '" .. raw:sub(i, i + 25) .. "'");
	end
end

local function is_in_list(tag, attribs, list)
	if not list then return false end

	if list[tag] then
		return true;
	end
	for i = 1, #list do
		if list[i](tag, attribs) then
			return true;
		end
	end

	return false;
end
local function fix_list(list)
	local res = {};
	if list then
		for k, v in pairs(list) do
			if type(k) == "number" then
				if type(v) == "function" then
					table.insert(res, v);
				else
					res[v] = true;
				end
			else
				res[k] = true;
			end
		end
	end

	return res;
end

--- @alias xml.classifier { [integer]: string | (fun(tag: string, attribs: table<string, string>): boolean), [string]: true }

--- @class xml.options
--- @field relaxed boolean
--- @field self_closing xml.classifier
--- @field raw_contents xml.classifier
--- @field no_children xml.classifier

--- @param raw string
--- @param settings? xml.options | "html"
--- @return xml_node
local function parse(raw, settings)
	if settings == "html" then
		settings = {
			relaxed = true,
			self_closing = {
				"area", "base", "br", "col", "embed", "hr", "img", "input", "meta", "param", "source", "track", "wbr",
				function (tag, attribs) return tag == "script" and attribs.src ~= nil end,
				function (tag, attribs) return tag == "link" and attribs.href ~= nil end,
				-- function (tag, attribs) end,
			},
			raw_contents = { "code", "pre", "textarea" },
			no_children = { "script", "style" },
		};
	end

	settings = settings or {};

	local state = {
		start = true,
		rawtext_n = 0,
		relaxed = settings.relaxed or false,
		self_closing = fix_list(settings.self_closing),
		no_children = fix_list(settings.no_children),
		raw_contents = fix_list(settings.raw_contents),
	};

	--- @type xml_node
	local document = xml_node.new { tag = "document", attribs = {} };
	local curr_node = document;
	local stack = {};
	local i = 1;

	while true do
		local part;
		part, i = parse_part(raw, i, state);
		if part.type == "eof" then
			break;
		elseif part.type == "text" then
			if not state.relaxed and #stack == 0 then
				error("text may not appear outside a tag (near '" .. raw:sub(i, i + 25) .. "')");
			elseif part.space and #curr_node == 0 then
			else
				if type(curr_node[#curr_node]) == "string" then
					curr_node[#curr_node] = curr_node[#curr_node] .. part.text;
				else
					table.insert(curr_node, part.text);
				end
			end
		elseif part.type == "version" then
			curr_node.attribs.type = part.tag;
			curr_node.attribs.version = part.attribs.version;
		elseif part.type == "begin" then
			local new_node = xml_node.new { tag = part.tag, attribs = part.attribs };
			table.insert(curr_node, new_node);

			if is_in_list(part.tag, part.attribs, state.raw_contents) then
				state.rawtext_n = state.rawtext_n + 1;
			end

			if is_in_list(part.tag, part.attribs, state.no_children) then
				local start_i = i;
				local end_part;
				while true do
					local end_i = i - 1;
					end_part, i = parse_part(raw, i, state);
					if end_part.type == "end" and end_part.tag == part.tag or end_part.type == "eof" then
						table.insert(new_node, raw:sub(start_i, end_i));
						break;
					end
				end
			elseif not is_in_list(part.tag, part.attribs, state.self_closing) then
				curr_node = new_node;
				table.insert(stack, new_node);
			end
		elseif part.type == "end" then
			if not state.relaxed then
				if part.tag ~= curr_node.tag then
					error("closing tag '" .. part.tag .. "' doesn't match most recent opening tag '" .. curr_node.tag .. "'");
				else
					if is_in_list(curr_node.tag, curr_node.attribs, state.raw_contents) then
						state.rawtext_n = state.rawtext_n - 1;
					end

					table.remove(stack);
					curr_node = stack[#stack];
				end
			else
				local found_i;

				for i = #stack, 1, -1 do
					if stack[i].tag == part.tag then
						found_i = i;
						break;
					end
				end

				if found_i then
					for i = #stack, found_i, -1 do
						if is_in_list(stack[i].tag, stack[i].attribs, state.raw_contents) then
							state.rawtext_n = state.rawtext_n - 1;
						end

						table.remove(stack);
					end

					curr_node = stack[#stack] or document;
				end
			end
		elseif part.type == "small" then
			curr_node[#curr_node + 1] = xml_node.new { tag = part.tag, attribs = part.attribs };
		else
			error "wtf";
		end
	end

	if not state.relaxed and #stack > 0 then
		error("tag '" .. curr_node.tag .. "' was left open");
	end

	return document;
end

return {
	parse = parse,
	parse_entity = parse_entity,
	node = xml_node.new,
};

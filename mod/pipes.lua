local io = io or require "io";
local exports = {};

--- The default buffer size used by read operations
exports.BUFF_SIZE = 4096;

--- @alias Reader fun(n: number, no_throw?: boolean): string?, string?
--- @alias Writer fun(data: string | nil, no_throw?: boolean): true?, string?

--- Creates a reader from the path
--- @param path string
--- @return Reader? result
function exports.reader(path, force_file)
	if path == "-" and not force_file then return exports.stdin end
	return exports.reader_from(io.open(path, "rb"))
end
--- @param f? file*
--- @return Reader? result
function exports.reader_from(f, ...)
	f = assert(f, ...);
	return function (n)
		if n == nil then n = exports.BUFF_SIZE end

		if n < 0 then
			if f ~= nil then
				f:close();
				f = nil;
			end
		elseif f == nil then
			error("File closed", 2);
		else
			local res = f:read(n);

			if res == nil then
				f:close();
				f = nil;
				return "";
			else
				return res;
			end
		end
	end
end

--- Creates a writer from the path
--- @param path string
--- @return Writer? result
function exports.writer(path, force_file)
	if path == "-" and not force_file then return exports.stdout end
	return exports.writer_from(io.open(path, "wb"))
end
--- @param f? file*
--- @return Writer? result
function exports.writer_from(f, ...)
	f = assert(f, ...);
	return function (data)
		if data == nil then
			if f ~= nil then
				f:close();
				f = nil;
			end

			return true, nil;
		elseif f == nil then
			error("File closed", 2);
		else
			local res, w_err = f:write(data);

			if res == nil then
				error(w_err, 2);
			else
				return true;
			end
		end
	end
end

--- Writes the full contents of src to dst. Since src is read until its end, it will be closed after this function
--- @param src Reader
--- @param dst Writer
--- @param close_dst boolean? Wether or not to close dst after copying
function exports.copy(src, dst, close_dst)
	local res, buff, err, failed;

	while true do
		buff, err = src(4096, true);

		if buff == nil and err ~= nil then
			error(err, 2);
		elseif buff == nil or buff == "" then
			break;
		else
			res, err = dst(buff, true)
			if res == nil then
				error(err, 2);
			end
		end

	end

	if close_dst then
		res, err = dst(nil, true);

		if res == nil then
			error(err, 2);
		end
	end

	if failed then
		error(err, 2);
	end
end

function exports.loader(...)
	local arr = {...};
	local i = 1;

	return function ()
		while true do
			local el = arr[i];

			if el == "" then
				i = i + 1;
			elseif el == nil then
				return nil;
			elseif type(el) == "function" then
				local buff = el();
				if buff ~= "" then
					return buff;
				else
					i = i + 1;
				end
			elseif type(el) == "string" then
				i = i + 1;
				return el;
			else
				error("Loader may consist only of strings and functions");
			end
		end
	end
end

exports.stdin = exports.writer_from(io.stdin);
exports.stdout = exports.writer_from(io.stdout);
exports.stderr = exports.writer_from(io.stderr);

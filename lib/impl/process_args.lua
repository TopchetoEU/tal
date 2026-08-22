local process_args = {};

process_args.tag = "impl.udata_tag";

local metatable = { __metatable = process_args.tag };

function process_args.wrap_udata(udata, cb)
	return setmetatable({
		tag = process_args.tag,
		udata = udata,
		process_args = cb,
	}, metatable);
end

return process_args;

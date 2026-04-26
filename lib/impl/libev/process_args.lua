local process_args = {};

process_args.wrap_tag = {};

function process_args.wrap_udata(udata, cb)
	return {
		tag = process_args.wrap_tag,
		udata = udata,
		process_args = cb,
	};
end

return process_args;

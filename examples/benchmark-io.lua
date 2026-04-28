-- Demonstrates tal's raw IO speed

return function ()
	local buff = ("\0"):rep(1024 * 1024);

	for i = 1, 1024 do
		io.stdout:write(buff);
	end
end

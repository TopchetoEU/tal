return function (glob)
	require ".polyfills"(glob);
	require ".array"(glob);
	require ".coro"(glob);
	require ".env"(glob);
	require ".function"(glob);
	require ".printing"(glob);
	require ".string"(glob);
	require ".utils"(glob);
end

# IO model

TAL completely replaces lua's IO model. However, the new APIs are mostly compatible with the stock lua functions.

## Streams

A main construct, called a "stream" is used to describe anything you `read()` or `write()` to. They *roughly* correlate to file descriptors, and are what are returned from `io.open`.

You can create your own streams, using `stream.new`:

```lua
local str = stream.new {
	read = function (self, ptr, n)
		ffi.copy(ptr, "test", math.min(n, 4));
		return math.min(n, 4);
	end,
};
```

In the future, a more sensible, string-based API will be added, but for now, if you want to create a stream, you will have to work with the buffer-based API.

## Networking

A module, named `std.io.net` contains all functions, relating to raw networking:

- `net.connect` - opens a client TCP/UDP connection to a given port
- `net.bind` - opens a server on a given port, returns a server
- `net.getaddrinfo` - resolves a name to an IP address
- `server:next` - returns the next accepted connection (it is reccomended that you process further requests in a fork)

## Errors

Most IO APIs will throw errors as plain lua errors (not via return values). Exceptions are `io.open` and `fs.stat`, but you can call them with `assert`, like PUC lua IO functions.

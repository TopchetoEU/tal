# Streams API

Most IO-heavy code will need some sort of API to read and write chunks of data, be that from the internet, a file or something else entirely. TAL provides that in the form of its `std.str` API.

All stream implementations must conform to the `std.str` type and inherit it, using `setmetatable(my_stream_metatable, require "std.str")`. This base metatable will implement some of the functions of a stream, which your stream doesn't support.

There is a core type of stream, which supports the basic operations (read, write, seek, stat, chmod, chown and close). A stream however is required only to implement `close`.

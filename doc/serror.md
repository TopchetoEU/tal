# Stackful errors

A usual issue in lua regarding error handling is that `pcall` swallows stack traces. This makes it significantly harder to debug, in the case you need to rethrow the error from pcall (most often when you want to do finalization work). This is why TAL defines a set of functions to catch errors 'stackfully', and rethrow them as such.

## `spcall` - stackful protected call

It behaves just like `pcall`, but if an error has occured, after the error, a stack trace is also returned:

```lua
local ok, err, trace = spcall(my_func);
```

## `srethrow` - stackful rethrow

Throws an error that `spcall` will understand. Note that this will throw a special object error, which will confuse `pcall` lower in the call stack. Errors thrown with `srethrow` will emit both the initial stack trace and the rethrow stack trace, appended by `spcall`.

## `sxpcall` - stackful protected call with an error handle

It behaves just like `xpcall`, but if an error occurs, an error handle will be called on top of the error call stack. The handle has the possibility of receiving a stack trace alongside the error, as `sxpcall` could catch a rethrown error. The handle returns the transformed error value as its first return value, and the second is the transformed stack trace. That is either `nil`, which tells `sxpcall` to generate a stack trace, `true`, which generates no stack trace (useful when you don't need one) or a string, which will be used as the result stack trace.

## `serrnew` and `serrunpack`

These functions are not exposed as globals and are only accessible via the `std.errors` module. They are used to create and unpack the intermediate representation of a stackful error. These are useful for working with non-stackful rethrowing lua code:

```lua
local ok, err = coroutine.resume(...);
if not ok then
	return false, errors.serrunpack(err);
else
	return true;
end
```

Utils for doing FFI stuff. Mostly to keep lua value & callback references.

Use these, especially for callbacks, so that valuable luajit callback slots aren't wasted.

Note that all IDs, returned by these facilities are guaranteed to be non-zero, so feel free to treat zero as an invalid value.

## Pointers

The pointer manager is a global mapper of native object pointers to their wrapper counterparts. The wrapper object could be any lua value, except nil (I usually do custom FFI structs, as those fast GC free semantics).

A pointer manager will be necessary mostly when working with callbacks, which receive a context pointer (and of course, a single callback can be active at a time).

The table is weak value-wise, so it won't keep your lua values alive!

## Objects

The object manager is not too unlike lua's `luaL_ref` mechanism. It boils down to a mapping from integers to lua values. The integers are automatically assigned in ascending order from 1 (so 0 can be used as an invalid value).

This can be used to keep references to lua values in unmanaged code. Note that this register will keep your lua values alive, you need to manually remove them from the table by their ID (`objects.del(id)`).

There are some important caveats: you must not create cyclic references using this mechanism, as this would prevent any of the underlying values' finalizers to be called, as all of them have an erroneous strong reference and the lua GC can't collect them.

Example usage:

```lua
local struct = ffi.new "struct { int ref_a; int ref_b; }";

struct.ref_a = objects.add { a = 1, b = 2};
struct.ref_b = objects.add { "test1", "test2" };

pprint(objects.get(struct.ref_a)); -- { a = 1, b = 2 }
pprint(objects.get(struct.ref_b)); -- { "test1", "test2" }

objects.del(struct.ref_a);
objects.del(struct.ref_b);

-- GC can now reclaim both objects
```

## Callbacks

The callback wrapper allows you to use a basically infinite amount of callbacks per call site (side-stepping luajit's relatively low hard limit of callbacks) are usually created per call site (aka for each place you would need a callback, you will need to create a callbacks object).

This works on top of the global object manager mentioned above - the same IDs are used for the functions. However, we need a way to retrieve the intended function to be called. This is done by retrieving the function's ID from the arguments. How that is done is up to you - it could be via user values, passed to the callback or stored in a wrapper, associated to a context pointer, passed to the callback.

Example usage (with userdata):

```lua

ffi.cdef [[
	typedef void (*my_callback_t)(void *udata);

	void my_func(my_callback_t cb, void *udata);
]];

local my_callback = callbacks.new(
	"my_callback_t",
	function (udata) return tonumber(ffi.cast("size_t", udata)) end,
);

local id = my_callback:add(function () print "test" end);

ffi.my_lib.my_cb_func(my_callback.ptr, ffi.cast("void*", id)); -- our callback will get printed

my_callback:del(id);
-- The cb function is now reclaimable
```

Example use (with pointers):


Example usage:

```lua

ffi.cdef [[
	typedef struct my_ctx *my_ctx_t;

	typedef void (*my_callback_t)(void *udata);

	void my_func(my_ctx_t ctx, my_callback_t cb);
]];

local libexample = ffi.load "example";

local my_callback = callbacks.new(
	"my_callback_t",
	-- Key getter
	function (ctx) return pointers.get(ctx).cb end,
	-- Argument fixer
	function (ctx) return pointers.get(ctx) end,
);

local my_class = {};
my_class.__index = my_class;

function my_class.new()
	local ptr = ...;
	local self = { ptr = ptr, ...some other stuff };
	return pointers.reg(ptr, self);
end

function my_class:my_func(cb)
	self.cb = my_callback:add(cb);
	libexample.my_func(self.ptr, my_callback.ptr);
	my_callback:del(self.cb);
end
```

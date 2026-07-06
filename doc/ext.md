# Extensions

TAL extends standard lua semantics quite a lot, but the semantics of stock lua are mostly kept.

## Column numbers

TAL's custom compiler emits column numbers as well. However, luajit is build to work strictly with line numbers only. For this purpose, a `std.debug.mapping` module has been added, in which mappings of raw line numbers -> locations are added. On the other hand, the compiler emits lua code, in which each locatable element is emitted on its own line, so that luajit can report different lines, so the mappings can work.

Additionally, `load`, `loadfile`, `loadstring`, `dofile`, `debug.traceback`, `debug.sethook`, `debug.getinfo`, `error` and `assert` have been wrapped to use these mappings, so that regular lua code can see correct line numbers, but TAL code can use additional column numbers.

## Syntax extensions

- Bitwise operators: &, |, ~, <<, >>
- Assignment operators: +=, -=, \*=. /=, //=, %=, &=, |=, ^=, <<=, >>=
- C-like boolean operators: &&, ||, !, !=
- Parenless parameterless function literal: `my_func begin stm1; stm2; stm3; end` <=> `my_func(function(...) stm1; stm2; stm3; end)`
- `_ENV` to `getfenv` and `setfenv` translations

## `table` methods

Some much needed methods have been written into the global table lib:

- `table.absindex(tab, i, def)` - Converts `i` to a bounded index inside `tab`. `def` is the default value, if `i` is `nil`. Works on strings as well.
- `table.insertall(tab, other)` - Appends all entries of `other` to `tab`. Overload with index not yet implemented
- `table.delete(tab, val, maxn, rev)` - Deletes at most `maxn` (by default 1, negatives are interpreted like `#tab - maxn`) elements in `tab`, equal to `val`. If `rev` is specified, searches from the opposite side
- `table.deleteall(tab, other, maxn, rev)` - Executes `table.delete` on `tab` for each element of `other`. All semantics from `table.delete` apply
- `table.find(tab, val, rev, first, last)` - Returns the index of `val` in `tab` between `first` (by default 1) and `last` (by default -1). If element is not found, returns `nil`.
- `table.mk(tab)` - Equivalent to `setmetatable(tab, table)`

NOTE: please use these only for small tables, as they get quite inefficient for more elements (hundreds and thousands). Eventually, a more efficient, but unordered `set` util, mirroring the `table` functions will be implemented.

Also, `__index` and `__metatable` fields have been added to the table lib, so that it can serve as a metatable.

## Package roots

The `package.searchpath` algorithm has been extended to interpret `@` as a replace spot for a set of "roots". When a package path segment contains `@`, it is replaced with every element from `package.roots`, and for each resultant path, it is being tried as a file path.

For example, for a path `@/?.lua;@/?/init.lua` and a root set of `test1` and `test2`, and a name of `module`, the list of tested files will be:

- test1/module.lua
- test2/module.lua
- test1/module/init.lua
- test2/module/init.lua

The same goes for the C module path resolution, as well as the FFI path resolution. All of these are customizable via env variables:

- LUA_ROOTS - `package.roots`
- LUA_CROOTS - `package.croots`
- FFI_ROOTS - `ffi.roots`

Each of the above-mentioned roots are arrays of strings. They are created with `table.mk`, so you can use all `table.*` methods on them. In most cases, you probably want to use `roots:insert[all]` and `roots:delete[all]`.

## Package wildcards (TBD)

**NOTE: This is something to be done in the future**

the `*` symbol in a package path is interpreted as a bash-like wildcard. Each path segment that contains it will be listed with the OS's utilities. For example, for the path `/lib/lua/*/?.lua;/lib/lua/*/?/init.lua` and the module name `test`, and for the folders `a`, `b` and `c` in `/lib/lua`, the following files will be tested:

- /lib/lua/a/test.lua
- /lib/lua/b/test.lua
- /lib/lua/c/test.lua
- /lib/lua/a/test/init.lua
- /lib/lua/b/test/init.lua
- /lib/lua/c/test/init.lua

Of course, wildcards work with any other prefixes in the path (so `my/path/prefix*suffix/?.lua` is a valid package path).

*Why?*

Some people might want to organize packages like this:

```
lib/lua
+- pkg1
|  +- ...lua files
+- pkg2
|  +- ...lua files
+- pkg3
   +- ...lua files
```

And this tool lets you do that. Note that having two or more segments with wildcards will hit your performance.

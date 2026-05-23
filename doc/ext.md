# Extensions

TAL extends standard lua semantics quite a lot, but the semantics of stock lua are mostly kept.

## Column numbers

TAL's custom compiler emits column numbers as well. However, luajit is build to work strictly with line numbers only. For this purpose, a `std.debug.mapping` module has been added, in which mappings of raw line numbers -> locations are added. On the other hand, the compiler emits lua code, in which each locatable element is emitted on its own line, so that luajit can report different lines, so the mappings can work.

Additionally, `load`, `loadfile`, `loadstring`, `dofile`, `debug.traceback`, `debug.sethook`, `debug.getinfo`, `error` and `assert` have been wrapped to use these mappings, so that regular lua code can see correct line numbers, but TAL code can use additional column numbers.

## Syntax extensions

- Bitwise operators: &, |, ~, <<, >>
- Assignment operators: +=, -=, *=. /=, //=, %=, &=, |=, ^=, <<=, >>=
- C-like boolean operators: &&, ||, !, !=
- Parenless parameterless function literal: `my_func begin stm1; stm2; stm3; end` <=> `my_func(function(...) stm1; stm2; stm3; end)`
- `_ENV` to `getfenv` and `setfenv` translations

## Package roots

The `package.searchpath` algorithm has been extended to interpret `@` as a replace spot for a set of "roots". When a package path segment contains `@`, it is replaced with every entry from `package.roots`, and for each resultant path, it is being tried as a file path.

For example, for a path `@/?.lua;@/?/init.lua` and a root set of `test1` and `test2`, and a name of `module`, the list of tested files will be:

- test1/module.lua
- test2/module.lua
- test1/module/init.lua
- test2/module/init.lua

The same goes for the C module path resolution, as well as the FFI path resolution. All of these are customizable via env variables:

- LUA_ROOTS - `package.roots`
- LUA_CROOTS - `package.croots`
- FFI_ROOTS - `ffi.roots`

Each of the abovementioned roots are an instance of `std.package.roots`, of which you can call the `add` and `del` functions, which respectively add or remove a root.

*Why not `table.insert(package.roots, "my-root")`?*

Because we want to gracefully handle the same root being added twice. The `std.package.roots` instance will keep each root at most once, and keeps a count of each root.

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

- `lib/lua`
	- `pkg1`
		- ...lua files
	- `pkg2`
		- ...lua files
	- `pkg3`
		- ...lua files

And this tool lets you do that. Note that having two or more segments with wildcards will hit your performance.

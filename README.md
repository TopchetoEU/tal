# TAL - TopchetoEU's Atrocious Lua

**THIS IS THE LAST VERSION BEFORE v0.3.X!!**

A runtime, based on luajit. This runtime adds the following features:

- An async I/O API, using my own alternative to libuv (libev), combined with lua's coroutines
- Networking & SSL, under the same abstraction the IO library uses (std.io.stream)
- A compiler, written in lua, that brings some newer syntax features to luajit (most notably bit ops)
- A nicer REPL with `readline` and history support
- Nice value printing! (no more `for k, v in pairs(obj) do print(k, v)`)
- Some synchronization primitives, to make the Java devs happy (mutexes, conditions and go-like pipes)
- A lot of utilities I have built for myself over the years - "json", "path" for path manipulation and "argp" for parsing argv

***HUGE BIG RED LETTER SCARY WARNING***: This project is VERY EARLY ALPHA. The code is largely untested and still somewhat fragile. Working with it is not for the faint of heart.

***WINDOWS IS NOT ~~(officially)~~ SUPPORTED*** If you want to run this on Windows, you probably could, but you are on your own here. Most of the code has been written with eventual windows support at some point, but no effort has been put to testing and making Windows fully function. Expect to debug quite a lot of lua and C, if you do decide to run this natively on windows.

## Installing

You can use the makefile to build all required libraries (`libev` and `luajit`) and copy them into your system.

The makefile has two variables:
- `SYSLIBS` - if set to "yes", skips dependency building and assumes your system already has them installed (luajit is still built, as there is a degree of customization)
- `PREFIX` - where to store the results (by default set to `/usr/local/lib`)

## Usage

The runtime is used through the CLI `tal` command. It works pretty much like the `lua` command, for more details, read the `--help` output.

By default, the script is run as a script - exactly how lua does it. However, tal extends lua's CLI options with a `--module` (`-m`) option, which works more like python's flag bearing the same name. `-m` will resolve the module and will call the function it returns with the rest of the argb arguments. For a reference, see the included examples, which are all modules.

## Built-in compiler

The built-in compiler will give you some of the new stuff from lua 5.2+ (whatever is easily implementable anyways). Note that it is still somewhat slow (shouldn't matter if you use the bundler).

It is loaded pretty early in the startup process, so almost all of the packages (except for the compiler itself + some other early dependencies) will be compiled by luajit's built-in compiler.

One of the main benefits of the custom compiler, except the syntax extensions is that it reports columns, in addition to lines. All APIs that work with code locations are wrapped to return column numbers as well.

Here are some of the features that it adds on top luajit's syntax:
- `+=`, `-=` and friends
- Pow operator (uses `math.pow`), integer division operator (does `math.floor(a / b)`) and bitwise operators (they call `bit.*` functions underneath)
- `_ENV` - calls getfenv and setfenv underneath, unless a `_ENV` variable is defined (broken, I would strongly advise you to use luajit's functions instead and not stress-test my shitty polyfill...)

Future plans for extending the syntax:
- `if local` and `while local` constructs (go-style condition declarations)
- `if condition return` and `if condition break`

Currently unsupported:
- `continue`
- `<close>` and `<const>` variable tags
- lua 5.5's `global` directive

## Built-in bundler

A useful tool was included, which takes your application + all its dependencies and bundles them into a single executable. You can use it like this:

```sh
tal -m tal.bundle -o output-name -c gcc my.entry.name
```

This will walk your application's dependency tree, compile all modules to luajit bytecode, generate C code that loads all of that code and starts it and then pass it to a `cc` executable you have in your path to compile it.

**NOTE:** most code will use libev.so, so you will need to include it either next to the executable or in /usr/lib. You will see this same warning printed by the tool itself.

## Incompatibilities

An active effort has been made to NOT break existing lua libraries that are replaced. Still, IO functions specifically are now yielding, so existing code that calls them at places where you can yield will break (so no io.stderr:write in xpcall).

`print` has been left stock, so that you can still have an easy tool to debug code with, without going thru the complexities of TAL.

If you do find other incompatibilities, they are most likely bugs, so please do report them as issues.

## Documentation

[Here](./doc/index.md)

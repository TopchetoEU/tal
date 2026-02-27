# TAL - TopchetoEU's Atrocious Lua

I am very sorry for the hastily written README, I will refactor it.

***BIG NOTE NUMERO NIL:*** This is a project I use for myself. If you decide (for some ungodly reason) to use this project, you use it at your own sanity's risk

***BIG NOTE NUMERO UNO:*** As the name suggest, I *STRONGLY* suggest that you ***DO NOT*** use this in production.

***BIG NOTE NUMERO DOS:*** The project supports **ONLY** Linux (and probably Mac, IDK tho). I plan to support Windows, but it's not a priority for me

A runtime, based on luajit. This runtime adds the following features:

- An async I/O API, using libuv (node's I/O event loop thingie), combined with lua's threads
- Wrappers on top of coroutines, called generators. Coroutines are only delegated to low-level work
- A nicer REPL with `readline` and history support
- Nice value printing! (no more `for k, v in pairs(obj) do print(k, v)`)
- Module imports are now relative to the program entry, instead of the CWD (you can run your lua programs from anywhere without much hassle!)
- Backwards-compatible with *most* lua code
- Some utility modules, like "json", "path" for path manipulation and "args" for CLI args reading

## Installing

NOTE: currently, libsodium is not used, but will be in the future.

You can use the makefile to build all required libraries (`libev`, `libsodium` and `luajit`) and copy them into your system.

The makefile has two variables:
- `SYSLIBS` - if set to "yes", skips dependency building and assumes your system already has them installed (luajit is still built, as there is a degree of customization)
- `PREFIX` - where to store the results (by default set to `/usr/local/lib`)

## Usage

The runtime is used through the CLI `tal` command. It works pretty much like the `lua` command, for more details, read the `--help` output.

By default, the script is run as a script - the whole function is executed as if inside a main function. You can run the file as a module, using the `-m` flag (like python). This will call the exported value from the module as a function, with the argv arguments passed to the function as arguments.

## Module system

The module system is basically stock lua, but imports, if relative, are relative to the entrypoint, not the working dir. The module exports what the lua file returns.

## LuaLS support

I've written some ad-hoc meta modules, but 1. the type definitions are shitty and 2. I never managed to get the LuaLS addon working at all :/

## Documentation

Currently, documentation is virtually inexistent. Use `--help` where applicable, otherwise, go spelunking trough the code (I'm sorry, but read big note numero nil).

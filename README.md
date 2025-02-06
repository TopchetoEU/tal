# TAL - TopchetoEU's Atrocious Lua

I am very sorry for the hastily written README, I will refactor it.

***BIG NOTE NUMERO NIL:*** This is a project I use for myself. If you decide (for some ungodly reason) to use this project, you use it at your own sanity's risk
***BIG NOTE NUMERO UNO:*** As the name suggest, I *STRONGLY* suggest that you ***DO NOT*** use this in production.
***BIG NOTE NUMERO DOS:*** The project supports **ONLY** Linux (and probably Mac, IDK tho). I plan to support Windows, but it's not a priority for me

This is a pseudo-runtime for lua, written in lua. Most importantly, it includes the following shinies:

- The event loop (as it stands it's pretty useless, because there aren't any async functions)
- Pseudo-arrays (objects with a special prototypes with some nice-to-have functions)
- Symmetric coroutines by default, via a modified version of "coro" (avoids some painful problems with asymmetric coroutines)
- A nicer REPL with better values display (via the "pprint" function, aka pretty-print)
- A better module system (C modules not yet supported), that provides relative imports and global scope isolation
- Some utility modules, like "json", "path" for path manipulation and "args" for CLI args reading

## Installing

The included Makefile can be used to copy the necessary files where they need to be - on linux machines, it should be enough to run `make install`. This command will copy `tal` into `~/.local/bin` and will copy the stdlibs into `~/.local/lib/.tal_mod`. Feel free to do that manually

## Usage

The runtime is used through the CLI `tal` command. It works pretty much like the `lua` command, for more details, read the `--help` output.

One major difference is that the executed file will be imported as a module, and it is expected that it either:

- Exports the main function
- Exports a field `main` that is a function or
- Defines a `main` global that is a function

You can still write scripts that don't exports a main function, but they won't be able to accept CLI arguments.

## Module system

The module system is inspired both by CommonJS and Lua's module system. I believe that I have achieved a pretty nice balance between both.

You have two ways of importing modules - with `import` and with `require`. Using `import` requires you specify the real "path" to the module, aka "./my/precious/module.lua". On the other hand, `require` supports the lua-styled syntax - ".my.precious.module". Note that to use relative imports you need to prefix the module ID with at least one dot. Every additional prefix dot equates to one `../` prepended to the id. Example: `.a.b.c -> ./a/b/c.lua`, `..a.b -> ../a/b.lua`, `...a.b -> ../../a/b`.

If the imported ID doesn't start with `./`, `../` or `/`, it will be searched for in the `module.path` array. If it isn't found there, an error will occur. On the other hand, if the ID has one of these prefixes, it won't be searched in the `module.path` folders. This ensures that you know exactly which module you are importing.

Exporting can happen in several ways:

- Just returning - this works exactly how lua's module system would - it will override the default `exports` object with the return value. Note that if you return zero values, no overriding will occur. This has the best IDE support
- Assigning to the `exports` global - like NodeJS's module system, `exports` is a reference to the default `module.exports` object. This has no IDE support
- Assigning to the `module.exports` field - will work like CommonJS
- Assigning to `module.returns` - this will expect the return of `box`, aka a tuple with an integer `n` field. In this way, you can specify what values will be returned by an eventual `import` of the module. This is how the values, `return`-ed by the module are stored
- By using the `export` function - this function accepts one object and will assign all of its fields to `module.exports`. This has *no* IDE support, and frankly, IDK if it's possible.

## Existing code support

none. don't even try.

## LuaLS support

I've written some ad-hoc meta modules, but 1. the type definitions are shitty and 2. I never managed to get the LuaLS addon working at all :/

## Documentation

Currently, documentation is virtually inexistent. Use `--help` where applicable, otherwise, go spelunking trough the code (I'm sorry, but read big note numero nil).

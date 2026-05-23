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

--- @meta promise

local exports = {};

--- Adds a message on the event loop to be executed later
--- @param ... fun()
function exports.push(...) end

--- Adds the "main" function as a message and starts execution of the event loop (unless it's already running)
--- The "main" function is called with the given arguments
--- @param main fun(...)
function exports.run(main, ...) end

--- Will suspend the execution of the current message and will continue to the next
--- Tip: saving the current thread with "coro.running()" and then transferring back to it works
function exports.interrupt() end

return exports;

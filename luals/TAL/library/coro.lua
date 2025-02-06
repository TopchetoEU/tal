--- @meta

--- @class coro
coro = {};

--- Creates a symmetric coroutine from the function
--- @param func function
--- @return thread
function coro.create(func) end

--- @return thread th The currently running thread
--- @return boolean is_main Whether or not this is the main thread
function coro.running() end

--- Gets the status of the thread
--- @param th thread
--- @return
--- | "running" -- The thread is the currently running one
--- | "suspended" -- The thread is not running, but may be resumed
--- | "normal" -- Is active but not running.
--- | "dead" -- The coroutine is not running and can't be resumed
function coro.status(th) end

--- Transfers the execution to the given thread
--- @param th thread The thread to transfer execution to
--- @param ... any The arguments to pass to the thread
--- @return boolean ok Whether or not the thread yielded normally
--- @return ... Result if ok is true, the error if ok is false
function coro.ptransfer(th, ...) end

--- Transfers the execution to the given thread
--- @param th thread The thread to transfer execution to
--- @param ... any The arguments to pass to the thread
--- @return ... The yielded values form the function
function coro.transfer(th, ...) end

--- Transfers the execution to the given thread
--- @param f fun(yield: fun(...): nil, ...): ... Wrapped function
--- @return fun(...): ...
function coro.wrap(f) end

--- @param f fun(yield: (fun(...): ...), ...): ...
--- @return fun(...): fun(...): ...
function coro.gen(f) end

--- Prematurely kills the coroutine
--- @param th thread
--- @return boolean ok
--- @return string? err
function coro.close(th) end

--- @class coroutine
coroutine = {};

--- Creates a asymmetric coroutine from the function
--- @param func function
--- @return thread
function coroutine.create(func) end

--- @return thread th The currently running thread
--- @return boolean is_main Whether or not this is the main thread
function coroutine.running() end

--- Gets the status of the thread
--- @param th thread
--- @return
--- | "running" -- The thread is the currently running one
--- | "suspended" -- The thread is not running, but may be resumed
--- | "normal" -- Is active but not running.
--- | "dead" -- The coroutine is not running and can't be resumed
function coroutine.status(th) end

--- Transfers to the coroutine asymmetrically; If it uses an asymmetric yield it will transfer to this coroutine
--- @param th thread The thread to transfer execution to
--- @param ... any The arguments to pass to the thread
--- @return boolean ok Whether or not the thread yielded normally
--- @return ... Result if ok is true, the error if ok is false
function coroutine.resume(th, ...) end

--- Yields to the calling coroutine
--- @param ... any The arguments to pass to the thread
--- @return ... The yielded values form the function
function coroutine.yield(...) end

--- Transfers the execution to the given thread
--- @param f fun(...): ... Wrapped function
--- @return fun(...): ...
function coroutine.wrap(f) end

--- Prematurely kills the coroutine
--- @param th thread
--- @return boolean ok
--- @return string? err
function coroutine.close(th) end

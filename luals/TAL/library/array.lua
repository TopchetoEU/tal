--- @meta

--- @alias array<T> { [integer]: T } | arraylib

--- @class arraylib
arrays = {};

--- Converts the object to an array by putting "arrays" as its metatable
--- @generic T
--- @param obj { [integer]: T }
--- @return array<T>
--- @overload fun(val: string): array<string>
function array(obj) end

--- Converts the string to an array of characters
--- @param str string
--- @return array<string>
function array(str) end

--- Returns all the given arrays, concatenated to one
--- @generic T
--- @param ... T[]
--- @return array<T>
function arrays.concat(...) end

--- @generic T
--- @param self T[]
--- @param ... T[]
--- @return self
function arrays.append(self, ...) end

--- Adds all the given elements to the end of this array
--- @generic T
--- @param self T[]
--- @param ... T[]
--- @return self
function arrays.push(self, ...) end

--- Removes the last element of the array and returns it
--- @generic T
--- @param self array<T>
--- @return T val? The removed element, or nil if none
function arrays:pop() end

--- Returns the last element of the array
--- @generic T
--- @param self array<T>
--- @return T val? The last element of this array, or nil of none
function arrays:peek() end

--- Removes the first element of this array
--- @generic T
--- @param self array<T>
--- @return T val? The last element of this array, or nil of none
function arrays.shift(self) end

--- Adds all the given elements to the end of this array
--- @generic T
--- @param self T[]
--- @param ... T[]
--- @return self
function arrays.unshift(self, ...) end

--- Returns the result of mapping the values in table t through the function f
--- @generic In, Out
--- @param self In[]
--- @param f fun(val: In, i: integer, self: self): Out
--- @param mutate? boolean If true, will operate directly on the given array
--- @return Out[] arr
function arrays.map(self, f, mutate) end

--- Like arrays:map, but will expect the function to return arrays, and will :append them to the result array instead
--- @generic In, Out
--- @param self In[]
--- @param f fun(val: In, i: integer, self: self): Out[]
--- @return Out[] arr
function arrays.flat_map(self, f) end

--- Sorts the array in ascending order
--- @generic T
--- @param self T[]
--- @param f? fun(a: T, b: T): boolean A "less than" function, aka, a < b
--- @param copy? boolean If true will operate on a copy of the array
--- @return T[]
function arrays.sort(self, f, copy) end

--- Finds the index of the given element, or nil if it doesn't exist
--- @generic T
--- @param self T[]
--- @param f? fun(val: T, i: integer, self: self): T The predicate
--- @return integer?
function arrays.find_i(self, f) end

--- Sets each value from b to e to val in the given array
--- @generic T
--- @param self T[]
--- @param b? integer
--- @param e? integer
--- @return self
function arrays.fill(self, val, b, e) end

--- Every element from start to stop is removed from this array and are replaced with the given elements
--- @generic T
--- @param self T[]
--- @param b? integer
--- @param e? integer
--- @param ... T
--- @return self
function arrays.splice(self, b, e, ...) end

--- Returns the subarray from b to e
--- @generic T
--- @param self T[]
--- @param b? integer
--- @param e? integer
--- @return T[]
function arrays.slice(self, b, e) end

--- Equivalent of table.concat(self, sep, b, e)
--- @param sep string? Separator (defaults to empty)
--- @param b number? First element to take (defaults to beginning)
--- @param e number? Last element to take (defaults to end)
function arrays:join(sep, b, e) end

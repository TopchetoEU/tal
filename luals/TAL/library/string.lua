--- @meta

--- Splits the given string with the given delimiter
--- @param self string
--- @param sep string The delimiter to split by. Defaults to an empty string
--- @return array<string>
function string.split(self, sep)end

--- Gives the character at the specified position
--- @param self string
--- @param i integer
--- @return string
function string.at(self, i)end

--- string.format("%q", self)
--- @param self string
--- @return string
function string.quote(self)end

--- Quotes the string, making it safe to pass to a shell script (unix only!!!)
--- @param self string
--- @return string
function string.quotesh(self)end

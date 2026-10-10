local ansi = require "std.curses.ansi";
local mutex = require "std.sync.mutex";

--- @class std.curses.prog
--- @field private _backend std.strtxt
--- @field private _lines boolean[]
--- @field private _cursor integer
--- @field private _max_i integer
--- @field private _mut std.sync.mutex
local prog = {};
prog.__index = prog;
prog.__metatable = "std.curses.prog";

--- Allocate a line, create new if no sparce line exists
--- @return integer
function prog:alloc()
	self._mut:lock();
	for i, occupied in ipairs(self._lines) do
		if not occupied then
			self._lines[i] = true;
			self._mut:unlock();
			return i;
		end
	end

	table.insert(self._lines, true);
	self._max_i = #self._lines;
	self._mut:unlock();
	return #self._lines;
end
--- Free a line
--- @param i integer
function prog:free(i)
	self._mut:lock();
	if i == #self._lines then
		table.remove(self._lines);
	else
		self._lines[i] = false;
	end
	self._mut:unlock();
end
--- Print text at the given line
--- @param i integer
--- @return string
function prog:print(i, text)
	self._mut:lock();
	self._backend:write(ansi.gen_pos_move(i - self._cursor, 0), ansi.gen_clear("line"), text, "\n");
	self._cursor = i + 1;
	self._mut:unlock();
end
--- Finish the progress tracker, move the cursor after the last line
--- @return string
function prog:finish()
	self._mut:lock();
	self._backend:write(ansi.gen_pos_move(self._max_i + 1 - self._cursor, 0), "\n");
	self._mut:unlock();
end

--- @param backend std.strtxt
function prog.new(backend)
	return setmetatable({ _lines = {}, _cursor = 1, _max_i = 0, _mut = mutex.new(), _backend = backend }, prog);
end

return prog;

--- @meta promise

--- @alias promise<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10> promiselib | { when: fun(ful: fun(p1: T1, p2: T2, p3: T3, p4: T4, p5: T5, p6: T6, p7: T7, p8: T8, p9: T9, p10: T10), rej: fun(err)) }

--- @class promiselib
local promise = {};
promise.__index = promise;

--- @generic T1, T2, T3, T4, T5, T6, T7, T8, T9, T10
--- @param on_ful? fun(p1: T1, p2: T2, p3: T3, p4: T4, p5: T5, p6: T6, p7: T7, p8: T8, p9: T9, p10: T10)
--- @param on_rej? fun(err: any)
function promise:when(on_ful, on_rej) end

--- @generic T1, T2, T3, T4, T5, T6, T7, T8, T9, T10
--- @param self promise<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>
--- @returns T1, T2, T3, T4, T5, T6, T7, T8, T9, T10
function promise:await() end

--- @generic T1, T2, T3, T4, T5, T6, T7, T8, T9, T10
--- @param func fun(ful: fun(v: T1, v: T2, v: T3, v: T4, v: T5, v: T6, v: T7, v: T8, v: T9, v: T10), rej: fun(val: any))
--- @return promise<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>
function promise.mk(func) end

--- @generic T1, T2, T3, T4, T5, T6, T7, T8, T9, T10
--- @param p1? T1
--- @param p2? T2
--- @param p3? T3
--- @param p4? T4
--- @param p5? T5
--- @param p6? T6
--- @param p7? T7
--- @param p8? T8
--- @param p9? T9
--- @param p10? T10
--- @return promise<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>
function promise.resolve(p1, p2, p3, p4, p5, p6, p7, p8, p9, p10) end

--- @param err any
--- @return promise<any>
function promise.reject(err)
	return promise.mk(function (_, rej)
		if err and type(err.when) == "function" then
			err:when(rej, rej);
		else
			rej(err);
		end
	end);
end

return promise;

-- Naive fibonacci profiling and test stack.
-- params: [n]
package.path = "src/?.lua"
local Profiler = require("ELProfiler")

local n = ...
n = tonumber(n) or 35

local function fib(n)
  if n < 2 then
    return n
  else
    return fib(n-2)+fib(n-1)
  end
end

print("[test fibonacci]")
Profiler.start(0.01, 3)
print("fib("..n..") = "..fib(n))
io.write(Profiler.format(Profiler.stop()))

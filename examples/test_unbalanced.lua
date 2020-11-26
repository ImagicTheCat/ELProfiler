-- Test unbalanced measures.
-- params: [n]
package.path = "src/?.lua"
local Profiler = require("ELProfiler")

local n = ...
n = tonumber(n) or 1e7

local function a(n) return n*n end
local function b(n) return n*n*n end
local function c(n) return n*n*n*n*n end
local function d(n) return n*n*n*n*n*n*n*n*n end
local fs = {a,b,c,d}

do
  print("[test 4 funcs sequence]")
  Profiler.start()
  for i=1,n do a(i) b(i) c(i) d(i) end
  io.write(Profiler.format(Profiler.stop()))
end
print()
do
  print("[test 4 funcs random]")
  Profiler.start()
  for i=1,n do fs[math.random(1,4)](i) end
  io.write(Profiler.format(Profiler.stop()))
end

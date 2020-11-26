-- Test clock precision resilience.
-- params: [n]
package.path = "src/?.lua"
local Profiler = require("ELProfiler")

local n = ...
n = tonumber(n) or 1e7

local function a(n) return n+n end
local function b(n) return n+n end
local function c(n) return n+n end
local function d(n) return n+n end
local fs = {a,b,c,d}

local p_precision = -1 
local function clock()
  return p_precision > 0 and math.floor(os.clock()/p_precision)*p_precision or os.clock()
end
Profiler.setClock(clock)

local function test(precision)
  p_precision = precision
  print("[test 4 balanced funcs sequence]", "clock precision", precision)
  Profiler.start()
  for i=1,n do a(i) b(i) c(i) d(i) end
  io.write(Profiler.format(Profiler.stop()))
  print()
end

test(-1)
test(0.001)
test(0.01)
test(0.1)
test(1)

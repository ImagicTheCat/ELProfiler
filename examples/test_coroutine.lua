-- Test coroutine measures.
-- params: [n]
package.path = "src/?.lua"
local Profiler = require("ELProfiler")

local n = ...
n = tonumber(n) or 1e7

local function a(n) return n+n end
local function b(n) return n+n end
local function c(n) return n+n end
local function d(n) return n+n end

do
  print("[test 4 funcs balanced sequence]")
  Profiler.start()
  local co = coroutine.create(function()
    for i=1,n do a(i) b(i) c(i) d(i) end
  end)
  if not jit then Profiler.watch(co) end
  coroutine.resume(co)
  io.write(Profiler.format(Profiler.stop()))
end
print()
do
  print("[test 4 funcs balanced sequence (collaborative)]")
  Profiler.start()
  local co = coroutine.create(function(i)
    while true do
      a(i) b(i) c(i) d(i)
      i = coroutine.yield()
    end
  end)
  if not jit then Profiler.watch(co) end
  for i=1,n do coroutine.resume(co, i) end
  io.write(Profiler.format(Profiler.stop()))
end

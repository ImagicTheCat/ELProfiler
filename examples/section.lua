-- add package path for the example
package.path = ";../src/?.lua;"..package.path

local ELProfiler = require("ELProfiler")

ELProfiler.start("manual")

local nf, ni = ...
nf, ni = tonumber(nf), tonumber(ni)

ELProfiler.sb("s:init")
local funcs = {}
for i=1,nf do
  funcs[i] = function(a) return math.pow(a,i) end
end
ELProfiler.se()

ELProfiler.sb("s:compute")
for i=1,ni do
  ELProfiler.sb("s:compute:it")
  local f = funcs[math.random(1,nf)]
  local r = f(i)
  ELProfiler.se()
end
ELProfiler.se()

local pdata = ELProfiler.stop()
print("== PROFILE ==")
print(ELProfiler.format(pdata))

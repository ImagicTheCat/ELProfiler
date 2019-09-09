-- add package path for the example
package.path = ";../src/?.lua;"..package.path

local ELProfiler = require("ELProfiler")

ELProfiler.start()

local nf, ni = ...
nf, ni = tonumber(nf), tonumber(ni)

local funcs = {}
for i=1,nf do
  funcs[i] = function(a) return math.pow(a,i) end
end

for i=1,ni do
  local f = funcs[math.random(1,nf)]
  local r = f(i)
end

local pdata = ELProfiler.stop()
print("== PROFILE ==")
print(ELProfiler.format(pdata))

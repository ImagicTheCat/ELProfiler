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

for id, block in pairs(pdata.blocks) do
  print(id, block.calls, block.time, block.sub_time, block.time-block.sub_time)
  for sub_block, data in pairs(block.sub_blocks) do
    print("-> ", sub_block.id, data.time, data.calls)
  end
end

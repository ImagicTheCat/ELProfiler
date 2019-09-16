-- add package path for the example
package.path = ";../src/?.lua;"..package.path

local ELProfiler = require("ELProfiler")

ELProfiler.start("manual")

ELProfiler.sb("A")
ELProfiler.sb("B")
ELProfiler.sb("A")

for i=0,1e9 do
  local b = i*i
end

ELProfiler.se("A")
ELProfiler.se("B")
ELProfiler.se("A")

local pdata = ELProfiler.stop()
print("== PROFILE ==")
print(ELProfiler.format(pdata))

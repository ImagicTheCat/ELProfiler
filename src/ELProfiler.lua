-- ELProfiler (https://github.com/ImagicTheCat/ELProfiler)
-- license: MIT
-- author: ImagicTheCat
 
local ELProfiler = {}

local running = false

-- map of block id string => {.calls, .total_time, .time, .sub_blocks}
local blocks = {} 

local debug_getinfo = debug.getinfo
local table_insert = table.insert
local table_concat = table.concat

-- append blocks id to list, stack ascending order
local function parse_stack(list, start_level)
  start_level = start_level+1

  local info = debug_getinfo(start_level, "nS")
  while info do
    table_insert(list, table_concat({info.what, info.namewhat, info.name or "", info.short_src, info.linedefined}, ":"))

    -- next
    start_level = start_level+1
    info = debug_getinfo(start_level, "nS")
  end
end

-- debug hook
local function hook(t)
  if t == "call" then
    local stack = {}
    parse_stack(stack, 2)

    -- get/create block
    local block = blocks[stack[1]]
    if not block then
      block = {
        calls = 0,
        total_time = 0,
        time = 0
      }

      blocks[stack[1]] = block
    end

    block.calls = block.calls+1
  elseif t == "return" then
  end
end

-- API

-- start profiling
function ELProfiler.start()
  if running then
    ELProfiler.stop()
  end

  running = true
  debug.sethook(hook, "cr")
end

-- stop profiling
-- return profile data
function ELProfiler.stop()
  if running then
    running = false
    debug.sethook()

    local rdata = {blocks = blocks}
    blocks = {}
    return rdata
  end
end

return ELProfiler

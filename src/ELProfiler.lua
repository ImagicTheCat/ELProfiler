-- ELProfiler (https://github.com/ImagicTheCat/ELProfiler)
-- license: MIT
-- author: ImagicTheCat
 
local ELProfiler = {}

local running = false

-- map of block id string => {}
local blocks = {} 

local debug_getinfo = debug.getinfo
local table_insert = table.insert
local table_concat = table.concat
local clock = os.clock

-- append blocks id to list, stack ascending order
-- max: maximum stack index, nil to disable
local function parse_stack(list, start_level, max)
  start_level = start_level+1
  max = max+1

  local info = debug_getinfo(start_level, "nS")
  while info do
    table_insert(list, table_concat({info.what, info.namewhat, info.name or "", info.short_src, info.linedefined}, ":"))

    -- next
    start_level = start_level+1
    if not max or start_level <= max then
      info = debug_getinfo(start_level, "nS")
    else
      info = nil
    end
  end
end

-- debug hook
local function hook(t)
  if t == "call" then
    local stack = {}
    parse_stack(stack, 2, 2)

    -- get/create block
    local block = blocks[stack[1]]
    if not block then
      block = {
        id = stack[1],
        calls = 0,
        time = 0,
        sub_time = 0,
        first_call_time = 0,
        sub_blocks = {},
        depth = 0
      }

      blocks[stack[1]] = block
    end

    block.calls = block.calls+1
    block.depth = block.depth+1
    if block.depth == 1 then
      block.first_call_time = clock()
    end
  elseif t == "return" then
    local stack = {}
    parse_stack(stack, 2, 3)

    local block = blocks[stack[1]]
    if block then
      block.depth = block.depth-1
      if block.depth == 0 then
        local delta = clock()-block.first_call_time
        block.time = block.time+delta

        local super_block = (stack[2] and blocks[stack[2]] or blocks.record)
        if super_block then
          super_block.sub_time = super_block.sub_time+delta

          -- get/create sub block
          local sub_blocks = super_block.sub_blocks
          local sub_block = sub_blocks[block]
          if not sub_block then
            sub_block = {
              time = 0,
              calls = 0
            }

            sub_blocks[block] = sub_block
          end

          sub_block.time = sub_block.time+delta
          sub_block.calls = sub_block.calls+1
        end
      end
    end
  end
end

-- API

-- start profiling
function ELProfiler.start()
  if running then
    ELProfiler.stop()
  end

  running = true
  blocks.record = { -- record block (origin)
    id = "record",
    calls = 1,
    time = 0,
    sub_time = 0,
    first_call_time = clock(),
    sub_blocks = {},
    depth = 0
  }

  debug.sethook(hook, "cr")
end

-- stop profiling
-- return profile data
function ELProfiler.stop()
  if running then
    running = false
    debug.sethook()
    blocks.record.time = clock()-blocks.record.first_call_time

    local rdata = {blocks = blocks}
    blocks = {}
    return rdata
  end
end

-- set clock function
-- f_clock(): should return the current execution time reference (a number)
function ELProfiler.setClock(f_clock)
  clock = f_clock
end

return ELProfiler

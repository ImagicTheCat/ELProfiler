-- ELProfiler (https://github.com/ImagicTheCat/ELProfiler)
-- license: MIT
-- author: ImagicTheCat
 
local ELProfiler = {}

local running = false

-- map of block id string => {}
local blocks = {} 
local s_stack = {} -- section stack

local debug_getinfo = debug.getinfo
local table_insert = table.insert
local table_concat = table.concat
local table_remove = table.remove
local clock = os.clock
local mode

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

local function block_begin(id, super_block)
  -- get/create block
  local block = blocks[id]
  if not block then
    block = {
      id = id,
      calls = 0,
      time = 0,
      sub_time = 0,
      first_call_time = 0,
      sub_blocks = {},
      depth = 0
    }

    blocks[id] = block
  end

  block.calls = block.calls+1
  block.depth = block.depth+1
  if block.depth == 1 then
    block.first_call_time = clock()
  end

  if super_block then
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

    sub_block.calls = sub_block.calls+1
  end
end

local function block_end(id, super_block)
  local block = blocks[id]
  if block then
    block.depth = block.depth-1
    if block.depth == 0 then
      local delta = clock()-block.first_call_time
      block.time = block.time+delta

      if super_block then
        super_block.sub_time = super_block.sub_time+delta

        -- get/create sub block
        local sub_block = super_block.sub_blocks[block]
        sub_block.time = sub_block.time+delta
      end
    end
  end
end

-- debug hook
local function hook(t)
  if t == "call" then
    local stack = {}
    parse_stack(stack, 2, 3)
    block_begin(stack[1], stack[2] and blocks[stack[2]] or blocks.record)
  elseif t == "return" then
    local stack = {}
    parse_stack(stack, 2, 3)
    block_end(stack[1], stack[2] and blocks[stack[2]] or blocks.record)
  end
end

-- API

-- start profiling
-- mode: string
--- "hook": debug hook events (default)
--- "manual": no events, manual sections sb/se
function ELProfiler.start(mode)
  if not mode then mode = "hook" end

  if running then
    ELProfiler.stop()
  end

  mode = mode
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

  if mode == "hook" then
    debug.sethook(hook, "cr")
  end
end

-- stop profiling
-- return profile data {}
--- blocks: map of block id => block
---- block: {}
----- id: block id
----- calls: number of call
----- time: time spent
----- sub_time: time spent by sub blocks
----- sub_blocks: map of block => data
------ data: {}
------- calls: number of call of this sub block inside this block
------- time: time spent in this sub block inside this block
function ELProfiler.stop()
  if running then
    running = false
    if mode == "hook" then
      debug.sethook()
    end
    blocks.record.time = clock()-blocks.record.first_call_time

    local rdata = {blocks = blocks}
    blocks = {}
    s_stack = {}
    mode = nil
    return rdata
  end
end

-- set clock function
-- the default function is os.clock
-- f_clock(): should return the current execution time reference (a number)
function ELProfiler.setClock(f_clock)
  clock = f_clock
end

-- section begin
-- id: custom block id
function ELProfiler.sb(id)
  local s_id = s_stack[#s_stack]
  block_begin(id, s_id and blocks[s_id] or blocks.record)
  table_insert(s_stack, id)
end

-- section end
function ELProfiler.se()
  local id = table_remove(s_stack)
  local s_id = s_stack[#s_stack]
  block_end(id, s_id and blocks[s_id] or blocks.record)
end

return ELProfiler

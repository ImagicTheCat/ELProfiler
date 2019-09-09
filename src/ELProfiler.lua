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
-- mode: (optional) string
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

-- complete string with spaces to reach n
-- left: if true, left padding
local function pad_string(str, n, left)
  if left then
    return string.rep(" ", n-string.len(str))..str
  else
    return str..string.rep(" ", n-string.len(str))
  end
end

-- return percent notation from factor
local function factor_to_percent(v)
  return pad_string((math.floor(v*10000)/100).."%", 6, true)
end

-- create text report from profile data
-- mode: (optional) string
--- "spent_tree": blocks by descending time spent with sub blocks (+calls) (default)
--- "real_list": blocks by descending "real" time spent (+calls)
-- threshold: (optional) minimum time factor (0.01 => 1%) required for a block to be displayed (default -1)
-- return formatted string
function ELProfiler.format(profile_data, mode, threshold)
  if not mode then mode = "spent_tree" end
  if not threshold then threshold = -1 end

  local strs = {}

  if mode == "spent_tree" then
    local blocks = profile_data.blocks
    local list = {}

    local max_len = 0
    for id, block in pairs(blocks) do
      table.insert(list, block)
      if string.len(block.id) > max_len then max_len = string.len(block.id) end
    end

    table.sort(list, function(a, b)
      return a.time > b.time
    end)

    for _, block in ipairs(list) do
      local factor = block.time/blocks.record.time
      if factor < threshold then break end

      table.insert(strs, pad_string(block.id, max_len+3).."  "..factor_to_percent(factor).."  "..block.calls.."\n")

      local sub_list = {}
      for sub_block in pairs(block.sub_blocks) do
        table.insert(sub_list, sub_block)
      end

      table.sort(sub_list, function(a, b)
        return a.time > b.time
      end)

      for _, sub_block in ipairs(sub_list) do
        local data = block.sub_blocks[sub_block]
        table.insert(strs, "   "..pad_string(sub_block.id, max_len).."  "..factor_to_percent(sub_block.time/block.time).."  "..sub_block.calls.."\n")
      end
    end
  elseif mode == "real_list" then
    local blocks = profile_data.blocks
    local list = {}

    local max_len = 0
    for id, block in pairs(blocks) do
      table.insert(list, block)
      if string.len(block.id) > max_len then max_len = string.len(block.id) end
    end

    table.sort(list, function(a, b)
      return a.time-a.sub_time > b.time-b.sub_time
    end)

    for _, block in ipairs(list) do
      local factor = (block.time-block.sub_time)/blocks.record.time
      if factor < threshold then break end

      table.insert(strs, pad_string(block.id, max_len).."  "..factor_to_percent(factor).."  "..block.calls.."\n")
    end
  end

  return table.concat(strs)
end

return ELProfiler

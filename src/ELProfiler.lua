-- https://github.com/ImagicTheCat/ELProfiler
-- MIT license (see LICENSE or src/ELProfiler.lua)
--[[
MIT License

Copyright (c) 2019 ImagicTheCat

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local debug_getinfo, debug_sethook = debug.getinfo, debug.sethook
local table_insert = table.insert
local table_concat = table.concat
local math_max, math_floor = math.max, math.floor

local ELProfiler = {}
local running = false
local p_stack_depth, p_period, last_step_time, last_sample_time, ins_step, start_time
local clock = os.clock
local samples = {}

-- Stack dump used as sample identifier.
-- start: start level
-- depth: max dump depth
-- return stack dump string
local function dump_stack(start, depth)
  local dump = {}
  local i = 0
  local info = debug_getinfo(start, "nS")
  while info and i < depth do
    -- dump stack entry
    table_insert(dump, table_concat({info.what, info.short_src, info.linedefined, info.name or ""}, ":"))
    -- next
    i = i+1
    info = debug_getinfo(start+i, "nS")
  end
  return table_concat(dump, "\n")
end

-- Debug hook.
local function hook()
  -- compute step delta time
  local time = clock()
  local dt = time-last_step_time
  last_step_time = time
  -- compute instruction step to approximate the sampling period
  if dt > 0 then -- the delta time is used to compute the approximation
    ins_step = math_max(math_floor(ins_step/dt*p_period), 1)
  else -- the instruction step is exponentially increased to prevent hook overhead
    ins_step = ins_step*2
  end
  debug_sethook(hook, "", ins_step)
  -- Sampling.
  -- Allow sampling error by 30%: prevent oversampling when late and prevent
  -- undersampling when early.
  local sampling_dt = time-last_sample_time
  if sampling_dt >= p_period*0.3 then
    if sampling_dt <= p_period*1.3 then
      local id = dump_stack(3, p_stack_depth)
      samples[id] = (samples[id] or 0)+1
    end
    last_sample_time = time
  end
end

-- Start profiling.
-- period: (optional) sampling period in seconds (default: 0.01 => 10ms/100Hz)
-- stack_depth: (optional) stack dump depth (default: 1)
function ELProfiler.start(period, stack_depth)
  ELProfiler.stop()
  running = true
  p_period = period or 0.01
  p_stack_depth = stack_depth or 1
  start_time = clock()
  last_step_time, last_sample_time = start_time, start_time
  ins_step = 1
  debug.sethook(hook, "", ins_step)
end

-- Stop profiling.
-- return profile data {} or nil if not running
--- duration: profile duration in seconds
--- samples_count: total number of samples
--- samples: map of stack dump identifier string => number of samples
function ELProfiler.stop()
  if running then
    running = false
    debug.sethook()
    -- build data
    local duration = clock()-start_time
    local total_samples = 0
    for _, count in pairs(samples) do total_samples = total_samples+count end
    --- add missed samples
    local missed = math.max(math.floor(duration/p_period)-total_samples, 0)
    if missed > 0 then samples["?"] = (samples["?"] or 0)+missed end
    local data = {
      duration = duration,
      samples_count = total_samples+missed,
      samples = samples
    }
    samples = {}
    return data
  end
end

-- Set clock function.
-- (the default function is os.clock)
--
-- f_clock(): should return the current execution time reference in seconds
function ELProfiler.setClock(f_clock)
  clock = f_clock
end

-- Create text report from profile data.
-- threshold: (optional) minimum samples fraction required (0.01 => 1%, default: 0)
-- return formatted string
function ELProfiler.format(profile_data, threshold)
  if not threshold then threshold = 0 end
  local strs = {}
  -- output header
  table.insert(strs, "Profile: "..profile_data.duration.."s, "..profile_data.samples_count.." samples\n")
  -- sort entries
  local entries = {}
  for id, count in pairs(profile_data.samples) do
    table.insert(entries, {id, count})
  end
  table.sort(entries, function(a, b) return a[2] > b[2] end)
  -- output entries
  for _, entry in ipairs(entries) do
    local fraction = entry[2]/profile_data.samples_count
    if fraction < threshold then break end
    local percent_text = string.format("%6.2f", fraction*100).."%"
    local empty_text = string.rep(" ", #percent_text)
    local first = true
    -- output each stack entry
    for stack_entry in string.gmatch(entry[1], "[^\n]+") do
      -- value
      if first then table.insert(strs, percent_text); first = false
      else table.insert(strs, empty_text) end
      -- stack entry
      table.insert(strs, " "..stack_entry.."\n")
    end
  end
  return table.concat(strs)
end

return ELProfiler

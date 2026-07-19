-- Community Stream Deck+ Remote Lua Codec
-- Bidirectional CC surface for Trevliga Spel MIDI + dual loopMIDI ports.
-- Channel 1 (0-based nibble 0):
--   Demo knobs CC 20-23, Buttons CC 30-33
--   Fury params CC 40-68, Mod Wheel CC 1, Pitch Bend (e0)
--
-- Fury sync: dump all feedback CCs when Fury scope enables; soft-takeover
-- on inbound Fury CCs so stale Deck dials cannot yank params to zero.

g_fury_by_index = {}
g_fury_cc_to_index = {}
g_fury_volume_index = 0
g_fury_scope_was_enabled = false
g_fury_dirty = {}
g_fury_last_sent = {}
g_fury_last_physical = {}
-- Once pickup succeeds, stay latched so fast Deck spins are not blocked by
-- lagging get_item_value (crossing-style pickup sticks when Reason lags).
g_fury_synced = {}
g_fury_last_input_ms = {}
g_fury_settle_ms = 150

function fury_queue_index(index)
  if g_fury_by_index[index] ~= nil then
    g_fury_dirty[index] = true
  end
end

function fury_queue_all()
  for index, _ in pairs(g_fury_by_index) do
    g_fury_dirty[index] = true
  end
end

function fury_item_enabled(index)
  -- Stock codecs treat this as boolean; be explicit for safety.
  local en = remote.is_item_enabled(index)
  return en == true or en == 1
end

function fury_get_value(index)
  local value = remote.get_item_value(index)
  if value == nil then
    return nil
  end
  return value
end

function fury_make_feedback_midi(meta, value)
  if value == nil then
    return nil
  end
  if meta.kind == "pb" then
    local v = math.floor(value)
    if v < 0 then v = 0 end
    if v > 16383 then v = 16383 end
    local lo = math.floor(v % 128)
    local hi = math.floor(v / 128)
    return remote.make_midi(string.format("e0 %02x %02x", lo, hi))
  end
  local v = math.floor(value + 0.5)
  if v < 0 then v = 0 end
  if v > 127 then v = 127 end
  return remote.make_midi(string.format("b0 %02x %02x", meta.cc, v))
end

function fury_pickup_band(max_val)
  if max_val ~= nil and max_val <= 10 then
    return 0
  end
  return 10
end

-- Soft takeover until first lock: match within band, or cross Reason's value.
-- After lock (g_fury_synced), callers must not use this — pass all CCs through.
function fury_pickup_allows(data_value, reason_value, last_physical, max_val)
  if reason_value == nil then
    return false
  end
  local band = fury_pickup_band(max_val)
  if last_physical == nil or last_physical < 0 then
    local diff = data_value - reason_value
    if diff < 0 then diff = -diff end
    return diff <= band
  end
  -- Crossing OR jump that lands past the target (fast absolute CC bursts).
  if last_physical < reason_value and data_value >= reason_value then
    return true
  end
  if last_physical > reason_value and data_value <= reason_value then
    return true
  end
  if last_physical == reason_value then
    return true
  end
  local diff = data_value - reason_value
  if diff < 0 then diff = -diff end
  return diff <= band
end

function remote_init()
  local items =
  {
    {name="Knob 1", input="value", output="value", min=0, max=127},
    {name="Knob 2", input="value", output="value", min=0, max=127},
    {name="Knob 3", input="value", output="value", min=0, max=127},
    {name="Knob 4", input="value", output="value", min=0, max=127},

    {name="Button 1", input="button", output="value"},
    {name="Button 2", input="button", output="value"},
    {name="Button 3", input="button", output="value"},
    {name="Button 4", input="button", output="value"},

    {name="Volume", input="value", output="value", min=0, max=127},
    {name="Glide", input="value", output="value", min=0, max=127},
    {name="Bend Range", input="value", output="value", min=0, max=127},
    {name="Mono Mode", input="value", output="value", min=0, max=1},
    {name="Sub Level", input="value", output="value", min=0, max=127},
    {name="Detune", input="value", output="value", min=0, max=127},
    {name="Reese", input="value", output="value", min=0, max=127},
    {name="FM Amount", input="value", output="value", min=0, max=127},
    {name="Osc Shape", input="value", output="value", min=0, max=3},
    {name="Growl", input="value", output="value", min=0, max=127},
    {name="Vowel", input="value", output="value", min=0, max=127},
    {name="Bite", input="value", output="value", min=0, max=127},
    {name="Cutoff", input="value", output="value", min=0, max=127},
    {name="Resonance", input="value", output="value", min=0, max=127},
    {name="Wobble Rate", input="value", output="value", min=0, max=127},
    {name="Synced Rate", input="value", output="value", min=0, max=10},
    {name="Wobble Depth", input="value", output="value", min=0, max=127},
    {name="Sync Mode", input="value", output="value", min=0, max=1},
    {name="Wobble Shape", input="value", output="value", min=0, max=3},
    {name="Shape Pre", input="value", output="value", min=0, max=127},
    {name="Drive", input="value", output="value", min=0, max=127},
    {name="Fold", input="value", output="value", min=0, max=127},
    {name="Crush", input="value", output="value", min=0, max=127},
    {name="Width", input="value", output="value", min=0, max=127},
    {name="Limiter", input="value", output="value", min=0, max=127},
    {name="Punch Amount", input="value", output="value", min=0, max=127},
    {name="Punch Decay", input="value", output="value", min=0, max=127},
    {name="Amp Attack", input="value", output="value", min=0, max=127},
    {name="Amp Release", input="value", output="value", min=0, max=127},
    {name="Mod Wheel", input="value", output="value", min=0, max=127},
    {name="Pitch Bend", input="value", output="value", min=0, max=16383},
  }
  remote.define_items(items)

  -- Parallel tables: index order matches define_items (1-based). Fury starts at 9.
  local fury_names =
  {
    "Volume", "Glide", "Bend Range", "Mono Mode",
    "Sub Level", "Detune", "Reese", "FM Amount", "Osc Shape",
    "Growl", "Vowel", "Bite", "Cutoff", "Resonance",
    "Wobble Rate", "Synced Rate", "Wobble Depth", "Sync Mode", "Wobble Shape",
    "Shape Pre", "Drive", "Fold", "Crush", "Width", "Limiter",
    "Punch Amount", "Punch Decay", "Amp Attack", "Amp Release",
    "Mod Wheel", "Pitch Bend",
  }
  local fury_ccs =
  {
    40, 41, 42, 43,
    44, 45, 46, 47, 48,
    49, 50, 51, 52, 53,
    54, 55, 56, 57, 58,
    59, 60, 61, 62, 63, 64,
    65, 66, 67, 68,
    1, -1,
  }
  local fury_max =
  {
    127, 127, 127, 1,
    127, 127, 127, 127, 3,
    127, 127, 127, 127, 127,
    127, 10, 127, 1, 3,
    127, 127, 127, 127, 127, 127,
    127, 127, 127, 127,
    127, 16383,
  }

  g_fury_by_index = {}
  g_fury_cc_to_index = {}
  g_fury_dirty = {}
  g_fury_last_sent = {}
  g_fury_last_physical = {}
  g_fury_synced = {}
  g_fury_last_input_ms = {}
  g_fury_scope_was_enabled = false
  g_fury_volume_index = 9

  local i = 1
  while i <= table.getn(fury_names) do
    local index = 8 + i
    local cc = fury_ccs[i]
    local kind = "cc"
    if cc < 0 then
      kind = "pb"
      cc = 0
    end
    g_fury_by_index[index] =
    {
      name = fury_names[i],
      cc = cc,
      kind = kind,
      max = fury_max[i],
    }
    g_fury_last_physical[index] = -1
    g_fury_synced[index] = false
    g_fury_last_input_ms[index] = 0
    if kind == "cc" then
      g_fury_cc_to_index[cc] = index
    end
    i = i + 1
  end

  local inputs =
  {
    {pattern="b0 14 xx", name="Knob 1"},
    {pattern="b0 15 xx", name="Knob 2"},
    {pattern="b0 16 xx", name="Knob 3"},
    {pattern="b0 17 xx", name="Knob 4"},

    {pattern="b0 1e xx", name="Button 1", value="x/127"},
    {pattern="b0 1f xx", name="Button 2", value="x/127"},
    {pattern="b0 20 xx", name="Button 3", value="x/127"},
    {pattern="b0 21 xx", name="Button 4", value="x/127"},

    {pattern="b0 28 xx", name="Volume"},
    {pattern="b0 29 xx", name="Glide"},
    {pattern="b0 2a xx", name="Bend Range"},
    {pattern="b0 2b xx", name="Mono Mode"},
    {pattern="b0 2c xx", name="Sub Level"},
    {pattern="b0 2d xx", name="Detune"},
    {pattern="b0 2e xx", name="Reese"},
    {pattern="b0 2f xx", name="FM Amount"},
    {pattern="b0 30 xx", name="Osc Shape"},
    {pattern="b0 31 xx", name="Growl"},
    {pattern="b0 32 xx", name="Vowel"},
    {pattern="b0 33 xx", name="Bite"},
    {pattern="b0 34 xx", name="Cutoff"},
    {pattern="b0 35 xx", name="Resonance"},
    {pattern="b0 36 xx", name="Wobble Rate"},
    {pattern="b0 37 xx", name="Synced Rate"},
    {pattern="b0 38 xx", name="Wobble Depth"},
    {pattern="b0 39 xx", name="Sync Mode"},
    {pattern="b0 3a xx", name="Wobble Shape"},
    {pattern="b0 3b xx", name="Shape Pre"},
    {pattern="b0 3c xx", name="Drive"},
    {pattern="b0 3d xx", name="Fold"},
    {pattern="b0 3e xx", name="Crush"},
    {pattern="b0 3f xx", name="Width"},
    {pattern="b0 40 xx", name="Limiter"},
    {pattern="b0 41 xx", name="Punch Amount"},
    {pattern="b0 42 xx", name="Punch Decay"},
    {pattern="b0 43 xx", name="Amp Attack"},
    {pattern="b0 44 xx", name="Amp Release"},
    {pattern="b0 01 xx", name="Mod Wheel"},
    {pattern="e0 xx yy", name="Pitch Bend", value="y*128 + x"},
  }
  remote.define_auto_inputs(inputs)

  local outputs =
  {
    {name="Knob 1", pattern="b0 14 xx", x="value"},
    {name="Knob 2", pattern="b0 15 xx", x="value"},
    {name="Knob 3", pattern="b0 16 xx", x="value"},
    {name="Knob 4", pattern="b0 17 xx", x="value"},

    {name="Button 1", pattern="b0 1e xx", x="127*value"},
    {name="Button 2", pattern="b0 1f xx", x="127*value"},
    {name="Button 3", pattern="b0 20 xx", x="127*value"},
    {name="Button 4", pattern="b0 21 xx", x="127*value"},

    {name="Volume", pattern="b0 28 xx", x="value"},
    {name="Glide", pattern="b0 29 xx", x="value"},
    {name="Bend Range", pattern="b0 2a xx", x="value"},
    {name="Mono Mode", pattern="b0 2b xx", x="value"},
    {name="Sub Level", pattern="b0 2c xx", x="value"},
    {name="Detune", pattern="b0 2d xx", x="value"},
    {name="Reese", pattern="b0 2e xx", x="value"},
    {name="FM Amount", pattern="b0 2f xx", x="value"},
    {name="Osc Shape", pattern="b0 30 xx", x="value"},
    {name="Growl", pattern="b0 31 xx", x="value"},
    {name="Vowel", pattern="b0 32 xx", x="value"},
    {name="Bite", pattern="b0 33 xx", x="value"},
    {name="Cutoff", pattern="b0 34 xx", x="value"},
    {name="Resonance", pattern="b0 35 xx", x="value"},
    {name="Wobble Rate", pattern="b0 36 xx", x="value"},
    {name="Synced Rate", pattern="b0 37 xx", x="value"},
    {name="Wobble Depth", pattern="b0 38 xx", x="value"},
    {name="Sync Mode", pattern="b0 39 xx", x="value"},
    {name="Wobble Shape", pattern="b0 3a xx", x="value"},
    {name="Shape Pre", pattern="b0 3b xx", x="value"},
    {name="Drive", pattern="b0 3c xx", x="value"},
    {name="Fold", pattern="b0 3d xx", x="value"},
    {name="Crush", pattern="b0 3e xx", x="value"},
    {name="Width", pattern="b0 3f xx", x="value"},
    {name="Limiter", pattern="b0 40 xx", x="value"},
    {name="Punch Amount", pattern="b0 41 xx", x="value"},
    {name="Punch Decay", pattern="b0 42 xx", x="value"},
    {name="Amp Attack", pattern="b0 43 xx", x="value"},
    {name="Amp Release", pattern="b0 44 xx", x="value"},
    {name="Mod Wheel", pattern="b0 01 xx", x="value"},
    {name="Pitch Bend", pattern="e0 xx yy", x="bit.band(value,127)", y="bit.rshift(value,7)"},
  }
  remote.define_auto_outputs(outputs)
end

function remote_set_state(changed_items)
  if changed_items == nil then
    return
  end

  local enabled = false
  if g_fury_volume_index > 0 and fury_item_enabled(g_fury_volume_index) then
    enabled = true
  end

  if enabled and (g_fury_scope_was_enabled == false) then
    fury_queue_all()
    for index, _ in pairs(g_fury_by_index) do
      g_fury_last_physical[index] = -1
      g_fury_last_sent[index] = nil
      g_fury_synced[index] = false
      g_fury_last_input_ms[index] = 0
    end
  end
  g_fury_scope_was_enabled = enabled

  if enabled == false then
    return
  end

  local now = remote.get_time_ms()
  local i = 1
  while i <= table.getn(changed_items) do
    local item_index = changed_items[i]
    fury_queue_index(item_index)
    -- Re-arm pickup only for external Reason changes (not our own handle_input echo).
    if g_fury_by_index[item_index] ~= nil and g_fury_synced[item_index] then
      local elapsed = now - g_fury_last_input_ms[item_index]
      if elapsed > g_fury_settle_ms then
        local meta = g_fury_by_index[item_index]
        local reason_value = fury_get_value(item_index)
        local phys = g_fury_last_physical[item_index]
        if reason_value ~= nil and phys ~= nil and phys >= 0 then
          local diff = phys - reason_value
          if diff < 0 then diff = -diff end
          if diff > fury_pickup_band(meta.max) then
            g_fury_synced[item_index] = false
          end
        end
      end
    end
    i = i + 1
  end
end

function remote_deliver_midi(maxbytes, port)
  local events = {}
  if port ~= nil and port ~= 1 then
    return events
  end

  local used = 0
  local budget = 1024
  if maxbytes ~= nil then
    budget = maxbytes
  end

  for index, meta in pairs(g_fury_by_index) do
    if g_fury_dirty[index] then
      g_fury_dirty[index] = nil
      if fury_item_enabled(index) then
        local value = fury_get_value(index)
        if value ~= nil then
          local last = g_fury_last_sent[index]
          if last == nil or last ~= value then
            local msg = fury_make_feedback_midi(meta, value)
            if msg ~= nil then
              local nbytes = 3
              if used + nbytes <= budget then
                table.insert(events, msg)
                used = used + nbytes
                g_fury_last_sent[index] = value
              else
                -- Keep dirty for next tick if buffer full.
                g_fury_dirty[index] = true
              end
            end
          end
        end
      end
    end
  end

  return events
end

function remote_process_midi(event)
  -- Soft takeover for Fury CCs (channel 1). Pitch Bend stays on auto-input.
  -- Use raw bytes (Launchkey style) instead of yy match wildcards.
  if event == nil then
    return false
  end
  if event[1] ~= 176 then
    return false
  end

  local cc = event[2]
  local data = event[3]
  local index = g_fury_cc_to_index[cc]
  if index == nil then
    return false
  end

  if fury_item_enabled(index) == false then
    return true
  end

  local meta = g_fury_by_index[index]
  local reason_value = fury_get_value(index)
  local last_phys = g_fury_last_physical[index]
  if last_phys == nil then
    last_phys = -1
  end

  -- Latched: pass every CC through (Stream Deck absolute bursts lag Reason otherwise).
  if g_fury_synced[index] then
    remote.handle_input({ time_stamp = event.time_stamp, item = index, value = data })
    g_fury_last_input_ms[index] = remote.get_time_ms()
    g_fury_last_physical[index] = data
    return true
  end

  if fury_pickup_allows(data, reason_value, last_phys, meta.max) then
    remote.handle_input({ time_stamp = event.time_stamp, item = index, value = data })
    g_fury_synced[index] = true
    g_fury_last_input_ms[index] = remote.get_time_ms()
  end
  g_fury_last_physical[index] = data
  return true
end

function remote_probe()
  local control_surfaces = {}
  return control_surfaces
end

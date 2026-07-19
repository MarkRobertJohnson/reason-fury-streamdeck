-- Community Stream Deck+ Remote Lua Codec
-- Bidirectional CC surface for Trevliga Spel MIDI + dual loopMIDI ports.
-- Channel 1 (0-based nibble 0):
--   Demo knobs CC 20-23, Buttons CC 30-33
--   Fury params CC 40-68, Mod Wheel CC 1, Pitch Bend (e0)

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

    -- Fury (Local Developer / com.local.Fury) - item name = remotable name
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

    -- Fury CC 40-68 (0x28-0x44), Mod Wheel CC 1, Pitch Bend
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
    -- Items with min/max matching MIDI range: use x="value" (not 127*value).
    -- 127*value overflows the data byte and trips Recon asserts (MIDIUtils.cpp).
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
    -- Reason Remote expressions use Lua bit library (see Mackie codec), not bitand/bitshift.
    {name="Pitch Bend", pattern="e0 xx yy", x="bit.band(value,127)", y="bit.rshift(value,7)"},
  }
  remote.define_auto_outputs(outputs)
end

-- No hardware identity; surface is added manually in Preferences.
function remote_probe()
  local control_surfaces = {}
  return control_surfaces
end

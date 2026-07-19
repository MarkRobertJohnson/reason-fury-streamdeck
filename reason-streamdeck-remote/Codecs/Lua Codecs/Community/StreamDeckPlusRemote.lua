-- Community Stream Deck+ Remote Lua Codec
-- Bidirectional CC surface for Trevliga Spel MIDI + dual loopMIDI ports.
-- Channel 1 (0-based nibble 0): Knobs CC 20-23, Buttons CC 30-33.

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
  }
  remote.define_items(items)

  local inputs =
  {
    -- Absolute CC 0-127 on MIDI channel 1 (matches Stream Deck companion profile)
    {pattern="b0 14 xx", name="Knob 1"},
    {pattern="b0 15 xx", name="Knob 2"},
    {pattern="b0 16 xx", name="Knob 3"},
    {pattern="b0 17 xx", name="Knob 4"},

    {pattern="b0 1e xx", name="Button 1", value="x/127"},
    {pattern="b0 1f xx", name="Button 2", value="x/127"},
    {pattern="b0 20 xx", name="Button 3", value="x/127"},
    {pattern="b0 21 xx", name="Button 4", value="x/127"},
  }
  remote.define_auto_inputs(inputs)

  local outputs =
  {
    -- Knobs declare min=0 max=127, so `value` is already 0..127 for MIDI xx.
    -- Using 127*value here overflows the data byte and trips Recon asserts
    -- (MIDIUtils.cpp) when sending feedback to loopMIDI.
    {name="Knob 1", pattern="b0 14 xx", x="value"},
    {name="Knob 2", pattern="b0 15 xx", x="value"},
    {name="Knob 3", pattern="b0 16 xx", x="value"},
    {name="Knob 4", pattern="b0 17 xx", x="value"},

    -- Buttons are normalized 0..1
    {name="Button 1", pattern="b0 1e xx", x="127*value"},
    {name="Button 2", pattern="b0 1f xx", x="127*value"},
    {name="Button 3", pattern="b0 20 xx", x="127*value"},
    {name="Button 4", pattern="b0 21 xx", x="127*value"},
  }
  remote.define_auto_outputs(outputs)
end

-- No hardware identity; surface is added manually in Preferences.
function remote_probe()
  local control_surfaces = {}
  return control_surfaces
end

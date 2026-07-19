# Reason Remote — Reference

## Install directory layout

User/custom surfaces (this project):

```text
%PROGRAMDATA%\Propellerhead Software\Remote\
  Codecs\Lua Codecs\<Manufacturer>\
    Something.luacodec
    Something.lua
    Something.png
  Maps\<Manufacturer>\
    <Manufacturer> <Model>.remotemap

%APPDATA%\Propellerhead Software\Remote\
  (same Codecs / Maps layout — install to both)
```

Stock surfaces also live under the app install, e.g.:

```text
<Reason or Recon install>\Remote\
  DefaultMaps\
  DefaultCodecs\
  BuiltinMaps\
```

Reason and Reason Recon share ProgramData Remote. Recon error dialogs may say "Reason Recon Remote Mapping file" even when the file is the normal `.remotemap`.

Optional: some installs also accept a copy under Recon’s `Remote\DefaultMaps\<Manufacturer>\` (requires write access to Program Files).

## Codec files

| File | Role |
| --- | --- |
| `.luacodec` | `remote_supported_control_surfaces()` — manufacturer, model, source lua, picture, in_ports, out_ports |
| `.lua` | `remote_init()` — items, auto inputs, auto outputs |
| `.png` | Preference dialog icon (keep ~96×96) |

### Lua essentials

```lua
function remote_init()
  remote.define_items({
    {name="Knob 1", input="value", output="value", min=0, max=127},
    -- ...
  })
  remote.define_auto_inputs({
    {pattern="b0 14 xx", name="Knob 1"},  -- CC 20 ch1
    -- ...
  })
  remote.define_auto_outputs({
    {name="Knob 1", pattern="b0 14 xx", x="127*value"},
    -- ...
  })
end
```

- `b0` = MIDI channel 1 (0-based nibble).
- Knobs with `min=0, max=127` typically omit `value=` on inputs (raw `xx`).
- Buttons often use `value="x/127"`.
- Feedback requires `output="value"` on items **and** matching `define_auto_outputs`.
- For items with `min=0, max=127`, use `x="value"` in auto_outputs (not `127*value`). Wrong scaling overflows MIDI data bytes and can assert in Recon Logging builds (`MIDIUtils.cpp`).

Manufacturer/model strings in `.luacodec` must match the remotemap header fields exactly.

## Remotemap format (tabs required)

Stock header pattern:

```text
Propellerhead Remote Mapping File
File Format Version<TAB>1.0.0
Control Surface Manufacturer<TAB>Community
Control Surface Model<TAB>Stream Deck+ Remote
Map Version<TAB>1.0.0

Scope<TAB>Propellerheads<TAB>Combinator
//<TAB>Control Surface Item<TAB>Key<TAB>Remotable Item<TAB>Scale<TAB>Mode
Map<TAB>Knob 1<TAB><TAB>Rotary 1
```

- **Scope** is three fields: `Scope`, manufacturer (often `Propellerheads`), device name.
- **Map** lines: control item, empty Key, remotable item; optional Scale/Mode columns.
- Spaces instead of tabs → control surface errors / ignored map.

### Filename

Must be `{Manufacturer} {Model}.remotemap`:

| Wrong | Right |
| --- | --- |
| `Stream Deck+ Remote.remotemap` | `Community Stream Deck+ Remote.remotemap` |

## Ports vs Fury External Bus

| | Fury Bus | Remote demo | Fury Remote |
| --- | --- | --- | --- |
| Reason prefs | Sync → External Control Bus A | MIDI → control surface | Same Community surface |
| Cable | `loopMIDI Port` | Port 1 in / Port 2 out | Port 1 in / Port 2 out |
| Deck profile | Reason - Fury | Reason - Remote | Reason - Fury Remote |
| Feedback | No | Yes | Yes |
| Scope / CCs | Fury `midi_cc_chart` | Combinator etc. / 20–23 | `Local Developer` / `com.local.Fury` / 40–68 |

Never assign the same virtual port as both Remote In and Remote Out.

### Fury Remote notes

- Export: `reason-streamdeck-remote/Fury.remoteinfo.txt`
- CC table: `reason-streamdeck-remote/fury-remote-cc-map.md`
- Codec item `max` must match discrete remotables when Deck uses Fixed steps (not always 127).
- Continuous remotables are often `0–4194304`; Remote scales from codec `0–127`.

## Symptom → fix

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Manufacturer missing from Add manually | Codec not installed or app not restarted | `install-remote.ps1`; full quit/restart |
| *"Reason Recon Remote Mapping file cannot be found for Community Stream Deck+ Remote"* | Wrong map filename or map not in Maps\Community | Use `Community Stream Deck+ Remote.remotemap`; reinstall both roots |
| Ports / OK greyed out | Same as missing map | Fix filename; restart |
| Control surface error (Info) | Bad tabs / Scope lines / invalid remotables | Compare to stock tab format; simplify Scope |
| MIDI acts twice / jumps | Easy MIDI still enabled on Port 1/2 | Uncheck Easy MIDI for those ports |
| No feedback to Deck | Out port unset, same In/Out port, or Deck In wrong | Out=Port 2; Deck `smi`=Port 2, `smo`=Port 1 |
| Deck profile missing | Separate issue | See [streamdeck-profiles](../streamdeck-profiles/SKILL.md) |
| *"Control surface inactivated"* / did not respond properly | Invalid auto_output expression (e.g. `bitand`/`bitshift`) | Use `bit.band(value,127)` / `bit.rshift(value,7)` for Pitch Bend; reinstall codec; full restart |
| Surface OK but no Fury mapping | Wrong Scope manufacturer/model | Export Device Remote Info; Fury is `Local Developer` / `com.local.Fury` |

## Repo pointers

| Path | Role |
| --- | --- |
| [`reason-streamdeck-remote/install-remote.ps1`](../../../reason-streamdeck-remote/install-remote.ps1) | Install codec+map to ProgramData + AppData |
| [`reason-streamdeck-remote/Codecs/Lua Codecs/Community/`](../../../reason-streamdeck-remote/Codecs/Lua%20Codecs/Community/) | `.luacodec` / `.lua` / `.png` |
| [`reason-streamdeck-remote/Maps/Community/`](../../../reason-streamdeck-remote/Maps/Community/) | `Community Stream Deck+ Remote.remotemap` |
| [`reason-streamdeck-remote/build-remote-profile.ps1`](../../../reason-streamdeck-remote/build-remote-profile.ps1) | Demo Deck profile (Reason - Remote) |
| [`reason-streamdeck-remote/build-fury-remote-profile.ps1`](../../../reason-streamdeck-remote/build-fury-remote-profile.ps1) | Fury Maximize Deck profile (Reason - Fury Remote) |
| [`reason-streamdeck-remote/install-streamdeck-profile.ps1`](../../../reason-streamdeck-remote/install-streamdeck-profile.ps1) | Install Deck profile (`-ProfileName` / `-SourceRelative`) |
| [`reason-streamdeck-remote/fury-remote-cc-map.md`](../../../reason-streamdeck-remote/fury-remote-cc-map.md) | Fury codec CC ↔ page |
| [`reason-streamdeck-remote/README.md`](../../../reason-streamdeck-remote/README.md) | User-facing install steps |
| [streamdeck-profiles skill](../streamdeck-profiles/SKILL.md) | Deck-side `.sdProfile` invariants |

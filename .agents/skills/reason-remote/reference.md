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

If a copy exists under Recon’s `Remote\DefaultMaps\<Manufacturer>\`, keep it hash-identical to the repo map after edits (Logging builds have been seen to retain a stale copy).

## Codec files

| File | Role |
| --- | --- |
| `.luacodec` | `remote_supported_control_surfaces()` — manufacturer, model, source lua, picture, in_ports, out_ports |
| `.lua` | `remote_init()` plus optional `remote_set_state` / `remote_deliver_midi` / `remote_process_midi` |
| `.png` | Preference dialog icon (keep ~96×96) |

Manufacturer/model strings in `.luacodec` must match the remotemap header fields exactly.

### Lua essentials

```lua
function remote_init()
  remote.define_items({
    {name="Knob 1", input="value", output="value", min=0, max=127},
  })
  remote.define_auto_inputs({
    {pattern="b0 14 xx", name="Knob 1"},  -- CC 20 ch1
  })
  remote.define_auto_outputs({
    {name="Knob 1", pattern="b0 14 xx", x="value"},  -- NOT 127*value for 0..127 items
  })
end
```

- `b0` = MIDI channel 1 (0-based nibble).
- Knobs with `min=0, max=127` typically omit `value=` on inputs (raw `xx`).
- Buttons often use `value="x/127"` and auto_output `x="127*value"`.
- Feedback requires `output="value"` on items **and** matching `define_auto_outputs` (and/or manual `make_midi` dump).

### Auto-output scaling (do not regress)

| Item min/max | auto_output `x=` | Notes |
| --- | --- | --- |
| `0` / `127` (typical knob) | `"value"` | `127*value` overflows MIDI byte → Recon ASSERT |
| Button normalized 0..1 | `"127*value"` | Correct for buttons |
| Pitch Bend `0` / `16383` | `x="bit.band(value,127)"` `y="bit.rshift(value,7)"` | **Not** `bitand` / `bitshift` |

## CC reservation (Community Stream Deck+ Remote)

Keep blocks disjoint when adding instruments:

| CC range | Owner |
| --- | --- |
| 20–23 | Demo Knob 1–4 (Combinator / generic scopes) |
| 30–33 | Demo Button 1–4 |
| 40–68 | Fury Maximize params |
| 1 | Mod Wheel (Fury Performance; standard) |
| PB (e0) | Pitch Bend |

When adding the next instrument, pick the next free block (e.g. 70+) and document it in a `*-remote-cc-map.md`.

## Remotemap format (tabs required)

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

- **Scope** is three fields: `Scope`, manufacturer, device/model from Export Device Remote Info.
- **Map** lines: codec item, empty Key, remotable item; optional Scale/Mode.
- Spaces instead of tabs → control surface errors / ignored map.
- Filename must be `{Manufacturer} {Model}.remotemap` → `Community Stream Deck+ Remote.remotemap`.

### Scope examples

| Device | Scope manufacturer | Scope model |
| --- | --- | --- |
| Combinator | `Propellerheads` | `Combinator` |
| Fury (RE) | `Local Developer` | `com.local.Fury` |

Never guess RE scopes — always export.

## Initial sync + soft takeover (reusable pattern)

Canonical code: [`StreamDeckPlusRemote.lua`](../../../reason-streamdeck-remote/Codecs/Lua%20Codecs/Community/StreamDeckPlusRemote.lua).

### Scope-enable dump

1. After `define_items`, record 1-based indices for every item in the new Scope (and a sentinel, e.g. first continuous param).
2. In `remote_set_state(changed_items)`:
   - If sentinel transitions to enabled → queue **all** Scope items; reset last-sent / last-physical.
   - Also queue any Scope index present in `changed_items`.
3. In `remote_deliver_midi(maxbytes, port)` (Out port `1`):
   - For each dirty enabled item, `value = remote.get_item_value(index)`.
   - **If `value == nil`, skip** (do not call `math.floor` / `make_midi`).
   - Emit `b0 <cc> <value>` or packed `e0` for Pitch Bend; honor `maxbytes`; re-dirty if buffer full.
   - Return `events` table (empty when idle).

Keep `define_auto_outputs` for incremental change feedback; dump covers create/select.

### Soft takeover

1. In `remote_process_midi`, detect channel-1 CC (`event[1] == 176`).
2. If CC belongs to this Scope’s map:
   - If item not enabled → return `true` (consume; do not fall through to auto-input).
   - Compare Deck `event[3]` to `remote.get_item_value(item)` with Launchkey-style crossing logic.
   - Only then `remote.handle_input({ time_stamp=..., item=..., value=... })`.
   - Always update last-physical; return `true`.
3. Leave other CCs to `define_auto_inputs` (return `false`).

Pickup band: ~10 for continuous 0–127; `0` (exact/cross) when item `max <= 10`.

### Stream Deck half

- Profile ports: `smo=loopMIDI Port 1`, `smi=loopMIDI Port 2`.
- Encoders use **codec** CCs, not External Bus chart CCs.
- Fixed-step dials for discrete remotables; Multi slots each get their own codec CC.
- Follow [streamdeck-profiles](../streamdeck-profiles/SKILL.md) (Device.UUID, no UTF-8 BOM, UPPERCASE page folders).

## Ports vs External Bus

| | External Bus profile | Remote demo | Instrument Remote (e.g. Fury) |
| --- | --- | --- | --- |
| Reason prefs | Sync → Bus A | MIDI → control surface | Same Community surface |
| Cable | `loopMIDI Port` | Port 1 in / Port 2 out | Port 1 in / Port 2 out |
| Feedback | No | Yes | Yes + scope dump |
| CCs | Device `midi_cc_chart` | Codec 20–23 | Dedicated codec block |

Never assign the same virtual port as both Remote In and Remote Out.

## Mistake log (do not repeat)

| Mistake | What happened | Correct approach |
| --- | --- | --- |
| Spaces in remotemap | Control surface errors / ignored maps | Tabs only |
| Map named `Stream Deck+ Remote.remotemap` | "Mapping file cannot be found"; ports greyed | `Community Stream Deck+ Remote.remotemap` |
| auto_output `x="127*value"` on 0..127 knobs | Recon ASSERT `MIDIUtils.cpp` | `x="value"` |
| Pitch Bend `bitand` / `bitshift` | Surface inactivated on launch | `bit.band` / `bit.rshift` |
| Relying only on `define_auto_outputs` for create/select | Deck dials stay at 0; first turn yanks device | Scope-enable dump + soft takeover |
| `math.floor(remote.get_item_value(...))` without nil check | Surface inactivated on launch / select | Nil-guard; skip until value exists |
| Reusing External Bus chart CCs in Remote codec | Wrong bindings; confusion with Bus profile | Separate CC block; document in `*-remote-cc-map.md` |
| Guessing RE Scope as `Propellerheads <Name>` | No mapping when device focused | Export Device Remote Info |
| Skipping Recon `DefaultMaps` stale copy | Confusing map mismatches on Logging builds | Sync DefaultMaps when present |
| Same loopMIDI port for In and Out | Feedback loop / chaos | Port 1 in, Port 2 out |
| Leaving Easy MIDI on Port 1/2 | Double-handling / jumps | Uncheck Easy MIDI for Remote ports |

## Symptom → fix

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Manufacturer missing from Add manually | Codec not installed or app not restarted | `install-remote.ps1`; full quit/restart |
| *"Remote Mapping file cannot be found…"* | Wrong map filename or map not in Maps\Community | Exact Manufacturer+Model filename; reinstall both roots |
| Ports / OK greyed out | Same as missing map | Fix filename; restart |
| Control surface error (Info) | Bad tabs / Scope / invalid remotables | Stock tab format; export-backed Scope |
| MIDI acts twice / jumps | Easy MIDI still on Port 1/2 | Uncheck Easy MIDI |
| No feedback to Deck | Out unset, same In/Out, or Deck In wrong | Out=Port 2; Deck `smi`=Port 2, `smo`=Port 1 |
| Deck profile missing / unloadable | Profile invariants | [streamdeck-profiles](../streamdeck-profiles/SKILL.md) |
| *"Control surface inactivated"* | Lua error in codec | PB formulas; nil-guard dump path; reinstall; restart |
| Surface OK but device unmapped | Wrong Scope manufacturer/model | Export Device Remote Info |
| Deck dials stale after create/select | Auto-outputs only on change | Implement dump + soft takeover for that Scope |

## Repo pointers

| Path | Role |
| --- | --- |
| [`install-remote.ps1`](../../../reason-streamdeck-remote/install-remote.ps1) | Install codec+map to ProgramData + AppData |
| [`StreamDeckPlusRemote.lua`](../../../reason-streamdeck-remote/Codecs/Lua%20Codecs/Community/StreamDeckPlusRemote.lua) | Reference codec (dump + pickup + Fury) |
| [`Maps/Community/`](../../../reason-streamdeck-remote/Maps/Community/) | `Community Stream Deck+ Remote.remotemap` |
| [`Fury.remoteinfo.txt`](../../../reason-streamdeck-remote/Fury.remoteinfo.txt) | Example Export Device Remote Info |
| [`fury-remote-cc-map.md`](../../../reason-streamdeck-remote/fury-remote-cc-map.md) | Example CC ↔ page table |
| [`build-fury-remote-profile.ps1`](../../../reason-streamdeck-remote/build-fury-remote-profile.ps1) | Example multi-page Remote Deck profile |
| [`install-streamdeck-profile.ps1`](../../../reason-streamdeck-remote/install-streamdeck-profile.ps1) | Install Deck profile (`-ProfileName` / `-SourceRelative`) |
| [`README.md`](../../../reason-streamdeck-remote/README.md) | User-facing install / coexistence |
| [streamdeck-profiles skill](../streamdeck-profiles/SKILL.md) | Deck-side `.sdProfile` invariants |

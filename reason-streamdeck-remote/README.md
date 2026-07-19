# Reason Stream Deck Remote Surface

Standalone **Reason Remote** control surface for Stream Deck+, with MIDI feedback. Independent of the [Reason-Fury External Bus profile](../README.md) — do not mix their virtual MIDI ports.

This is **not** an official Elgato or Reason Studios product. It registers in Preferences as:

- **Manufacturer:** Community  
- **Model:** Stream Deck+ Remote  

## What you get

| Piece | Role |
| --- | --- |
| Lua codec + `.luacodec` | Demo knobs/buttons + Fury params (CC in **and** out) |
| `.remotemap` | Must be named `Community Stream Deck+ Remote.remotemap`. Scopes: Combinator, SubTractor, NN-XT, Master Section, Mixer 14:2, **Fury** (`Local Developer` / `com.local.Fury`) |
| Companion Stream Deck profiles | **Reason - Remote** (demo) and **Reason - Fury Remote** (Maximize Fury layout) |

Feedback is **change / remap driven** (Reason pushes values when parameters change or the surface remaps). There is no on-demand “dump all values” button in Reason.

## Port conventions (do not collide with Fury Bus)

| Port | Direction | Used by |
| --- | --- | --- |
| `loopMIDI Port` | Deck → External Control Bus A | **Reason-Fury profile only** |
| `loopMIDI Port 1` | Stream Deck MIDI **Out** → Reason Remote **Input** | This project |
| `loopMIDI Port 2` | Reason Remote **Output** → Stream Deck MIDI **In** | This project |

Never use one port for both In and Out (MIDI feedback loop).

## MIDI map (channel 1)

| Control | CC | Codec item |
| --- | --- | --- |
| Demo encoders 1–4 | 20–23 | Knob 1–4 |
| Keypad Btn 1–4 | 30–33 | Button 1–4 |
| Fury Maximize params | 40–68 | See [`fury-remote-cc-map.md`](fury-remote-cc-map.md) |
| Mod Wheel | 1 | Mod Wheel |
| Pitch Bend | PB (e0) | Pitch Bend |

## Install

### Prerequisites

- Reason (Remote support)
- Stream Deck+ and [Trevliga Spel MIDI](https://trevligaspel.se/streamdeck/midi/index.php)
- `loopMIDI Port 1` and `loopMIDI Port 2` created in loopMIDI

There are **two** installs (do not skip the Reason one):

| Step | Script | Where it shows up |
| --- | --- | --- |
| A. Reason Remote codec + map | `install-remote.ps1` | Preferences → MIDI → Add manually → Manufacturer **Community** |
| B. Stream Deck companion profile | `build-*-profile.ps1` + `install-streamdeck-profile.ps1` | Stream Deck app → **Reason - Remote** or **Reason - Fury Remote** |

`build-*-profile.ps1` / `install-streamdeck-profile.ps1` alone will **not** add anything to Reason’s manufacturer list.

Works with **Reason** and **Reason Recon** (same `%PROGRAMDATA%\Propellerhead Software\Remote\` folder).

### 1. Install Remote codec + map (Reason / Recon)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-remote.ps1
```

**Fully quit and restart Reason Recon** after installing so codecs reload.

### 2. Add the surface in Reason / Recon

1. **Edit → Preferences → MIDI**
2. Under **Remote keyboards and control surfaces**, click **Add manually**
3. Manufacturer: **Community** (not “Stream Deck” / “Elgato”)
4. Model: **Stream Deck+ Remote**
5. **Input Port:** `loopMIDI Port 1`
6. **Output Port:** `loopMIDI Port 2` (required for feedback)
7. In **Easy MIDI Inputs**, **uncheck** Port 1 and Port 2 so Remote owns them exclusively
8. If ports/OK stay disabled with **Remote Mapping file cannot be found**, re-run `install-remote.ps1` and **fully restart** Recon. The map filename must be exactly `Community Stream Deck+ Remote.remotemap` (tab-delimited inside).

### 3. Install companion Stream Deck profile(s)

Guards: Device.UUID, no UTF-8 BOM, UPPERCASE on-disk page folder GUIDs. See [`.agents/skills/streamdeck-profiles`](../.agents/skills/streamdeck-profiles).

**Demo (4 knobs):**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build-remote-profile.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-streamdeck-profile.ps1 -Restart
```

**Fury two-way (Maximize pages):**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build-fury-remote-profile.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-streamdeck-profile.ps1 -ProfileName 'Reason - Fury Remote' -SourceRelative 'StreamDeck\Reason-Fury-Remote.sdProfile' -Restart
```

Or codec + both profiles:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-remote.ps1 -AlsoInstallProfile -Profile Both -RestartStreamDeck
```

In the **Stream Deck** app, select **Reason - Fury Remote** (or **Reason - Remote** for the Combinator demo).

### 4. Prove feedback

**Demo:** select a Combinator; turn Rotary 1 in Reason — Deck Knob 1 should move.

**Fury:** select a Fury instance (or drag one in). Within about a second, Deck dials should jump to match the patch (scope-enable dump) — you should not need to touch Fury first. Turn Cutoff on the device — Deck follows. Turn Deck Volume — Fury follows.

**Soft takeover:** if a Deck dial is still stale, turning it will not yank Fury until the dial crosses the real value (then it tracks normally).

Background Stream Deck pages may still look stale until you open them if the MIDI plugin only paints the active page; the dump still updates plugin state for navigation.

## Extending maps

1. In Reason, select a device → **File → Export Device Remote Info**
2. Copy remotable item names into [`Maps/Community/Community Stream Deck+ Remote.remotemap`](Maps/Community/Community%20Stream%20Deck+%20Remote.remotemap) under a new `Scope …` block
3. For Fury, remotables live in [`Fury.remoteinfo.txt`](Fury.remoteinfo.txt); Scope is `Local Developer` / `com.local.Fury` (not Propellerheads)
4. Re-run `install-remote.ps1` and restart Reason

Map lines are **tab-delimited**:

```text
Map<TAB>Volume<TAB><TAB>Volume
```

## Agents / maintainers

- Reason codec/map: [`.agents/skills/reason-remote`](../.agents/skills/reason-remote) — scaling playbook (export → Scope → CC block → dump + soft takeover), mistake log, install invariants.
- Stream Deck companion profile: [`.agents/skills/streamdeck-profiles`](../.agents/skills/streamdeck-profiles) (page GUID UPPERCASE folders, Device.UUID, no UTF-8 BOM).

After Deck profile install:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ..\verify-profile-load.ps1 -Name 'Reason - Fury Remote'
```

## Layout in this folder

```text
reason-streamdeck-remote/
  README.md
  fury-remote-cc-map.md           # Fury codec CC ↔ page table
  Fury.remoteinfo.txt             # Export Device Remote Info
  install-remote.ps1              # codec + map → Reason Remote dirs
  build-remote-profile.ps1        # Reason - Remote demo profile
  build-fury-remote-profile.ps1   # Reason - Fury Remote Maximize profile
  install-streamdeck-profile.ps1  # install into ProfilesV3
  Codecs/Lua Codecs/Community/    # .luacodec .lua .png
  Maps/Community/                 # .remotemap
  StreamDeck/Reason-Remote.sdProfile/
  StreamDeck/Reason-Fury-Remote.sdProfile/
```

## Coexistence

| | Reason-Fury | Reason-Remote (demo) | Reason-Fury Remote |
| --- | --- | --- | --- |
| Path | External Control Bus + Fury CC chart | Remote codec + Combinator maps | Remote codec + Fury scope |
| Ports | `loopMIDI Port` | Port 1 + Port 2 | Port 1 + Port 2 |
| Sync | One-way Deck → Reason | Bidirectional | Bidirectional |
| Profile | Reason - Fury | Reason - Remote | Reason - Fury Remote |
| CCs | Fury `midi_cc_chart` (7, 5, …) | Codec 20–23 | Codec 40–68 (+ Mod/PB) |

All three can be installed at once. Switch Stream Deck profiles depending on which path you want; keep the port assignments above so they never share a cable.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| *"Control surface inactivated"* on Recon start | Codec Lua error — reinstall `install-remote.ps1` and fully restart. Common causes: bad Pitch Bend formulas (`bit.band`/`bit.rshift`, not `bitand`), or nil from `get_item_value` during feedback dump. Check Preferences → red error icon. |
| No Fury mapping when Fury selected | Scope must be `Local Developer` / `com.local.Fury`; reinstall map + restart |
| Deck dials stay at 0 after creating Fury | Codec should dump on scope enable — reinstall codec + full Recon restart. Confirm Remote Out = Port 2 and Deck In = Port 2. Select Fury again to re-trigger dump. |
| First Deck turn used to yank Fury to 0 | Soft takeover should block until pickup; if not, codec is stale — reinstall + restart |

## Limitations

- No Reason “dump all on demand” button — Fury sync is dump-on-scope-enable + change-driven auto_outputs
- Background Stream Deck pages may not update until shown
- Remotable names ≠ Fury External Bus CC numbers
- Fury Scope/Spectrum/patch remotables not mapped in v1
- Soft takeover applies to Fury CCs; Pitch Bend stays on auto-input (press encoder to center)

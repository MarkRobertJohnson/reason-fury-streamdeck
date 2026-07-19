# Reason Stream Deck Remote Surface

Standalone **Reason Remote** control surface for Stream Deck+, with MIDI feedback. Independent of the [Reason-Fury External Bus profile](../README.md) — do not mix their virtual MIDI ports.

This is **not** an official Elgato or Reason Studios product. It registers in Preferences as:

- **Manufacturer:** Community  
- **Model:** Stream Deck+ Remote  

## What you get

| Piece | Role |
| --- | --- |
| Lua codec + `.luacodec` | Defines 4 knobs + 4 buttons with CC in **and** CC out (feedback) |
| `.remotemap` | Must be named `Community Stream Deck+ Remote.remotemap` (Manufacturer + Model). Scopes: Combinator, SubTractor, NN-XT, Master Section, Mixer 14:2 |
| Companion Stream Deck profile | Trevliga Spel dials using **separate** In/Out ports |

Feedback is **change / remap driven** (Reason pushes values when parameters change or the surface remaps). There is no on-demand “dump all values” button in Reason.

## Port conventions (do not collide with Fury)

| Port | Direction | Used by |
| --- | --- | --- |
| `loopMIDI Port` | Deck → External Control Bus A | **Reason-Fury profile only** |
| `loopMIDI Port 1` | Stream Deck MIDI **Out** → Reason Remote **Input** | This project |
| `loopMIDI Port 2` | Reason Remote **Output** → Stream Deck MIDI **In** | This project |

Never use one port for both In and Out (MIDI feedback loop).

## MIDI map (channel 1)

| Control | CC | Codec item |
| --- | --- | --- |
| Encoder 1–4 | 20–23 | Knob 1–4 |
| Keypad Btn 1–4 | 30–33 | Button 1–4 |

## Install

### Prerequisites

- Reason (Remote support)
- Stream Deck+ and [Trevliga Spel MIDI](https://trevligaspel.se/streamdeck/midi/index.php)
- `loopMIDI Port 1` and `loopMIDI Port 2` created in loopMIDI

There are **two** installs (do not skip the Reason one):

| Step | Script | Where it shows up |
| --- | --- | --- |
| A. Reason Remote codec + map | `install-remote.ps1` | Preferences → MIDI → Add manually → Manufacturer **Community** |
| B. Stream Deck companion profile | `build-remote-profile.ps1` + `install-streamdeck-profile.ps1` | Stream Deck app profile dropdown → **Reason - Remote** |

`build-remote-profile.ps1` / `install-streamdeck-profile.ps1` alone will **not** add anything to Reason’s manufacturer list.

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

### 3. Install companion Stream Deck profile

Guards: Device.UUID, no UTF-8 BOM, UPPERCASE on-disk page folder GUIDs. See [`.agents/skills/streamdeck-profiles`](../.agents/skills/streamdeck-profiles).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build-remote-profile.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-streamdeck-profile.ps1 -Restart
```

Or both sides at once:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-remote.ps1 -AlsoInstallProfile -RestartStreamDeck
```

In the **Stream Deck** app (not Reason), select profile **Reason - Remote**.

### 4. Prove feedback

1. Create/select a **Combinator** (or SubTractor / NN-XT).
2. Turn a mapped knob in Reason’s UI — the matching Stream Deck dial should move.
3. Turn the Stream Deck dial — the Reason parameter should follow.

If the Deck does not update until you touch it, select/lock the device again (Reason often pushes feedback on remap).

## Extending maps

1. In Reason, select a device → **File → Export Device Remote Info**
2. Copy remotable item names into [`Maps/Community/Stream Deck+ Remote.remotemap`](Maps/Community/Stream%20Deck+%20Remote.remotemap) under a new `Scope …` block
3. Re-run `install-remote.ps1` and restart Reason

Map lines are **tab-delimited**:

```text
Map<TAB>Knob 1<TAB><TAB>Remotable Item Name
```

With a variation/mode column (empty Scale):

```text
Map<TAB>Knob 1<TAB><TAB>Filter Freq<TAB><TAB>Filters
```

## Agents / maintainers

- Reason codec/map: [`.agents/skills/reason-remote`](../.agents/skills/reason-remote) (map filename, tabs, ProgramData+AppData, Easy MIDI, Recon restart).
- Stream Deck companion profile: [`.agents/skills/streamdeck-profiles`](../.agents/skills/streamdeck-profiles) (page GUID UPPERCASE folders, Device.UUID, no UTF-8 BOM).

After Deck profile install:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ..\verify-profile-load.ps1 -Name 'Reason - Remote'
```

## Layout in this folder

```text
reason-streamdeck-remote/
  README.md
  install-remote.ps1              # codec + map → Reason Remote dirs
  build-remote-profile.ps1        # build companion .sdProfile
  install-streamdeck-profile.ps1  # install into ProfilesV3
  Codecs/Lua Codecs/Community/    # .luacodec .lua .png
  Maps/Community/                 # .remotemap
  StreamDeck/Reason-Remote.sdProfile/
```

## Coexistence with Reason-Fury

| | Reason-Fury | Reason-Remote (this) |
| --- | --- | --- |
| Path | External Control Bus + Fury CC chart | Remote codec + remotemap |
| Ports | `loopMIDI Port` | `loopMIDI Port 1` + `Port 2` |
| Sync | One-way Deck → Reason | Bidirectional (change-driven) |
| Profile name | Reason - Fury | Reason - Remote |

Both can be installed at once. Switch Stream Deck profiles depending on which path you want; keep the port assignments above so they never share a cable.

## Limitations

- Not a full dump of patch state on demand
- Background Stream Deck pages may not update until shown
- Remotable names ≠ Fury External Bus CC numbers
- Starter map covers a few devices; expand via Export Device Remote Info

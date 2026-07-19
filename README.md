# Reason - Fury Stream Deck profile

Public Stream Deck+ profile for the **Fury** Rack Extension (Reason / Recon), using the [Trevliga Spel MIDI plugin](https://trevligaspel.se/streamdeck/midi/index.php).

Fury's built-in MIDI CC chart is the source of truth. Install this profile, route MIDI via Reason's External Control Bus, and control Fury without MIDI Learn.

## Download

1. Get **Reason-Fury-StreamDeck.zip** from [Releases](https://github.com/MarkRobertJohnson/reason-fury-streamdeck/releases).
2. Unzip.
3. Install the [Trevliga Spel MIDI plugin](https://trevligaspel.se/streamdeck/midi/index.php) if needed.
4. Create a virtual MIDI port named `loopMIDI Port`.
5. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-profile.ps1 -Restart
```

`-Restart` stops and relaunches Stream Deck so the new profile is picked up. Omit it if you prefer to restart manually.

6. In Stream Deck, select the **Reason - Fury** profile.
7. In Reason / Recon:
   - Preferences → Sync: **External Control Bus A** = `loopMIDI Port`
   - Hardware Interface → **ADVANCED MIDI** → Bus A, **Channel 1** → your Fury device

## Prerequisites

- Stream Deck+ (model `20GBD9901`)
- Trevliga Spel MIDI plugin
- `loopMIDI Port` (loopMIDI)
- Fury Rack Extension

## Repo contents

| Path | Purpose |
| --- | --- |
| `Reason-Fury.sdProfile/` | Portable profile (plugin paths use `__TREVLIGA_PLUGIN__`; expanded on install) |
| `install-profile.ps1` | Install into `%APPDATA%\Elgato\StreamDeck\ProfilesV3`; optional `-Restart` |
| `midi-cc-map.md` | CC ↔ parameter table |
| `verify-profile.ps1` | Check page labels/CCs |
| `verify-profile-load.ps1` | Assert installed profile is loadable (BOM, UUID, UPPERCASE page folders) |
| [`.agents/skills/streamdeck-profiles/`](.agents/skills/streamdeck-profiles/) | Agent skill for Stream Deck profile build/install invariants |
| [`.agents/skills/reason-remote/`](.agents/skills/reason-remote/) | Agent skill for Reason/Recon Remote codec + remotemap install |
| `package-streamdeck.ps1` | Build release zip |
| `build-profile.ps1` | Rebuild from local Stream Deck templates (maintainers); `-KnobLayout Maximize` or `Compact` |
| [`reason-streamdeck-remote/`](reason-streamdeck-remote/) | **Separate** Reason Remote surface (dual-port MIDI feedback). Profiles: **Reason - Remote** (demo) and **Reason - Fury Remote** (two-way Fury). Uses `loopMIDI Port 1`/`2` — not `loopMIDI Port`. See that folder’s README. |

## Pages

| Page | Encoders (Maximize layout, default) |
| --- | --- |
| Core | Volume 7, Glide 5, Bend 15, Mode 24 |
| Oscillator | Sub/Detune (Multi), Reese 28, FM 29, Shape 25 (Fixed 0–3) |
| Growl | Growl/Vowel (Multi), Bite 18, Cutoff 74, Res 71 |
| Motion | Free Rate 13, BPM Rate 14 (Fixed 0–10), Depth/SyncMode (Multi; SyncMode Fixed 0–1), Shape 30 (Fixed 0–3) |
| Output | ShapePre/Drive (Multi), Fold 20, Crush 21, Width/Limiter (Multi) |
| Articulation | Punch 37, Decay 33, Attack 35, Release 34 |
| Performance | Pitch bend (press resets to center 8192) + Mod wheel (CC1) |

Shape knobs send step indices `0–3` (Osc: Saw/Square/Hybrid/Growl; Motion: Sine/Triangle/Square/Ramp). BPM Rate sends `0–10` for BAR through 1/128. SyncMode sends `0–1` (Free / Tempo). Pages with more than four parameters use dual Multi knobs so all four encoders stay assigned. Rebuild with `-KnobLayout Compact` for the older packed maps (4-way Multi + singleton).

Keypad on every control page:

```text
[Core] [Osc]  [Growl] [Motion]
[Out]  [Art]  [Perf]  [Notes]
```

Nav keys use a dark icon with the page number upper-left and the section title centered. **Notes** opens bass note pads (C1–G1).

## Why External Control Bus?

Easy MIDI and a generic Remote "MIDI Control Keyboard" will play notes but will **not** auto-apply Fury's CC chart. External Bus A → Advanced MIDI channel 1 delivers CCs to the device chart.

For **two-way** Fury control (Deck dials follow Reason), use the Community Remote surface and Stream Deck profile **Reason - Fury Remote** under [`reason-streamdeck-remote/`](reason-streamdeck-remote/) — that path does **not** use External Bus or the chart CCs above.

## Maintainer: package a release

Agents: use [`.agents/skills/streamdeck-profiles`](.agents/skills/streamdeck-profiles) before building or installing any `.sdProfile` (GUID casing, Device.UUID, no UTF-8 BOM). For Reason Remote codec/map work under `reason-streamdeck-remote/`, use [`.agents/skills/reason-remote`](.agents/skills/reason-remote).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-profile.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-profile-load.ps1 -Name 'Reason - Fury'
powershell -NoProfile -ExecutionPolicy Bypass -File .\package-streamdeck.ps1
gh release create streamdeck-fury-v1.0.0 `
  -t "Stream Deck: Reason - Fury v1.0.0" `
  -n "Portable Stream Deck+ profile for Fury. See README." `
  .\dist\Reason-Fury-StreamDeck.zip
```

## License

MIT — see [LICENSE](LICENSE).

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
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-profile.ps1
```

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
| `install-profile.ps1` | Install into `%APPDATA%\Elgato\StreamDeck\ProfilesV3` |
| `midi-cc-map.md` | CC ↔ parameter table |
| `verify-profile.ps1` | Check page labels/CCs |
| `package-streamdeck.ps1` | Build release zip |
| `build-profile.ps1` | Rebuild from local Stream Deck templates (maintainers) |

## Pages

| Page | Encoders |
| --- | --- |
| Core | Volume 7, Glide 5, Bend 15, Mode 24 |
| Oscillator | Sub/Detune/Reese/FM (Multi) + fixed Shape CC25 |
| Growl | Growl/Vowel/Bite/Cutoff (Multi) + Res 71 |
| Motion | Rate/SyncRate/Depth/SyncMode (Multi) + fixed Shape CC30 |
| Output | ShapePre/Drive/Fold/Crush (Multi) + Width/Limiter (Multi) |
| Articulation | Punch 37, Decay 33, Attack 35, Release 34 |
| Performance | Pitch bend + Mod wheel (CC1) |

Keypad on every control page:

```text
[Core] [Osc]  [Growl] [Motion]
[Out]  [Art]  [Perf]  [Notes]
```

Nav keys use a dark icon with the page number upper-left and the section title centered. **Notes** opens bass note pads (C1–G1).

## Why External Control Bus?

Easy MIDI and a generic Remote "MIDI Control Keyboard" will play notes but will **not** auto-apply Fury's CC chart. External Bus A → Advanced MIDI channel 1 delivers CCs to the device chart.

## Maintainer: package a release

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-profile.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\package-streamdeck.ps1
gh release create streamdeck-fury-v1.0.0 `
  -t "Stream Deck: Reason - Fury v1.0.0" `
  -n "Portable Stream Deck+ profile for Fury. See README." `
  .\dist\Reason-Fury-StreamDeck.zip
```

## License

MIT — see [LICENSE](LICENSE).

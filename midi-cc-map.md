# Fury MIDI CC Map

Source of truth: `extensions/Fury/motherboard_def.lua` → `midi_implementation_chart.midi_cc_chart`.

Every Fury instance responds to these CCs when they arrive on the **device** via Reason’s External Control Bus → Advanced MIDI (see [README.md](README.md)). Easy MIDI / generic Remote keyboard alone will not apply this chart. No Reason MIDI Learn is required on the Advanced MIDI path.

| CC | Property | Label |
| --- | --- | --- |
| 5 | `/custom_properties/glide` | Glide |
| 7 | `/custom_properties/volume` | Volume |
| 12 | `/custom_properties/growl` | Growl |
| 13 | `/custom_properties/wobble_rate` | Wobble Rate |
| 14 | `/custom_properties/wobble_sync_rate` | Synced Rate |
| 15 | `/custom_properties/bend_range` | Bend Range |
| 16 | `/custom_properties/wobble_depth` | Wobble Depth |
| 17 | `/custom_properties/vowel` | Vowel |
| 18 | `/custom_properties/bite` | Bite |
| 19 | `/custom_properties/drive` | Drive |
| 20 | `/custom_properties/fold` | Fold |
| 21 | `/custom_properties/crush` | Crush |
| 22 | `/custom_properties/width` | Width |
| 23 | `/custom_properties/limiter` | Limiter |
| 24 | `/custom_properties/mono_mode` | Mono Mode |
| 25 | `/custom_properties/osc_shape` | Osc Shape |
| 26 | `/custom_properties/sub_level` | Sub Level |
| 27 | `/custom_properties/detune` | Detune |
| 28 | `/custom_properties/reese` | Reese |
| 29 | `/custom_properties/fm_amount` | FM Amount |
| 30 | `/custom_properties/wobble_shape` | Wobble Shape |
| 31 | `/custom_properties/sync_mode` | Sync Mode |
| 33 | `/custom_properties/punch_decay` | Punch Decay |
| 34 | `/custom_properties/amp_release` | Amp Release |
| 35 | `/custom_properties/amp_attack` | Amp Attack |
| 36 | `/custom_properties/shape_pre` | Shape Pre |
| 37 | `/custom_properties/punch_amount` | Punch Amount |
| 71 | `/custom_properties/resonance` | Resonance |
| 74 | `/custom_properties/cutoff` | Cutoff |

## Performance (not in CC chart)

| Control | MIDI |
| --- | --- |
| Mod Wheel | CC 1 (standard) |
| Pitch Bend | Pitch bend |

## Stream Deck profile pages

The `Reason - Fury` Stream Deck+ profile maps these CCs by UI group:

| Page | Controls |
| --- | --- |
| Core | Volume 7, Glide 5, Bend 15, Mode 24 |
| Oscillator | Sub 26, Detune 27, Reese 28, FM 29; fixed Shape 25 |
| Growl | Growl 12, Vowel 17, Bite 18, Cutoff 74, Res 71 |
| Motion | Rate 13, SyncRate 14, Depth 16, SyncMode 31; fixed Shape 30 |
| Output | ShapePre 36, Drive 19, Fold 20, Crush 21, Width 22, Limiter 23 |
| Articulation | Punch 37, Decay 33, Attack 35, Release 34 |
| Performance | Pitch bend (PB); Mod wheel CC1 |

Keypad on every control page: section jump buttons (Core/Osc/Growl/Motion/Out/Art/Perf) and a **Notes** folder (bass note pads; not a top-level swipe page).

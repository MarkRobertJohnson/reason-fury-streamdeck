# Fury Remote CC Map (Community / Stream Deck+ Remote)

Source remotables: [`Fury.remoteinfo.txt`](Fury.remoteinfo.txt)  
Scope: `Local Developer` / `com.local.Fury`

These CCs are for the **Lua codec** (Reason Remote path), not Fury’s External Bus `midi_cc_chart`. Deck profile **Reason - Fury Remote** uses Port 1 (Out) / Port 2 (In).

| CC | Hex | Codec / remotable item | Page | Notes |
| --- | --- | --- | --- | --- |
| 40 | 28 | Volume | Core | Continuous |
| 41 | 29 | Glide | Core | Continuous |
| 42 | 2a | Bend Range | Core | Continuous |
| 43 | 2b | Mono Mode | Core | Codec max 1; Fixed 0–1 |
| 44 | 2c | Sub Level | Oscillator | Multi w/ Detune |
| 45 | 2d | Detune | Oscillator | Multi w/ Sub |
| 46 | 2e | Reese | Oscillator | Continuous |
| 47 | 2f | FM Amount | Oscillator | Continuous |
| 48 | 30 | Osc Shape | Oscillator | Codec max 3; Fixed 0–3 |
| 49 | 31 | Growl | Growl | Multi w/ Vowel |
| 50 | 32 | Vowel | Growl | Multi w/ Growl |
| 51 | 33 | Bite | Growl | Continuous |
| 52 | 34 | Cutoff | Growl | Continuous |
| 53 | 35 | Resonance | Growl | Continuous |
| 54 | 36 | Wobble Rate | Motion | Continuous |
| 55 | 37 | Synced Rate | Motion | Codec max 10; Fixed 0–10 |
| 56 | 38 | Wobble Depth | Motion | Multi w/ Sync Mode |
| 57 | 39 | Sync Mode | Motion | Codec max 1; Fixed 0–1 |
| 58 | 3a | Wobble Shape | Motion | Codec max 3; Fixed 0–3 |
| 59 | 3b | Shape Pre | Output | Multi w/ Drive |
| 60 | 3c | Drive | Output | Multi w/ Shape Pre |
| 61 | 3d | Fold | Output | Continuous |
| 62 | 3e | Crush | Output | Continuous |
| 63 | 3f | Width | Output | Multi w/ Limiter |
| 64 | 40 | Limiter | Output | Multi w/ Width |
| 65 | 41 | Punch Amount | Articulation | Continuous |
| 66 | 42 | Punch Decay | Articulation | Continuous |
| 67 | 43 | Amp Attack | Articulation | Continuous |
| 68 | 44 | Amp Release | Articulation | Continuous |
| 1 | 01 | Mod Wheel | Performance | Continuous |
| PB | e0 | Pitch Bend | Performance | 0–16383; press resets to 8192 |

Demo Combinator knobs (CC 20–23) and buttons (CC 30–33) remain on the codec for non-Fury scopes.

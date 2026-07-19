# Stream Deck Profiles — Reference

## ProfilesV3 layout

```text
%APPDATA%\Elgato\StreamDeck\ProfilesV3\
  <UPPERCASE-GUID>.sdProfile\
    manifest.json                 # umbrella (Name, Device, Pages)
    Profiles\
      <UPPERCASE-PAGE-GUID>\
        manifest.json             # Controllers (Keypad + Encoder)
        Images\                   # optional per-action images
```

### Umbrella `manifest.json`

| Field | Notes |
| --- | --- |
| `Name` | Shown in profile dropdown |
| `Device.Model` | Stream Deck+ = `20GBD9901` |
| `Device.UUID` | Required; from a working local profile |
| `Pages.Pages` | Array of **lowercase** page GUIDs |
| `Pages.Current` | Lowercase |
| `Pages.Default` | Lowercase empty/default page (folder still UPPERCASE on disk) |
| `AppIdentifier` | Optional auto-switch exe path |
| `Version` | `"3.0"` |

### Page `manifest.json`

```json
{
  "Controllers": [
    { "Type": "Keypad", "Actions": { "0,0": { /* action */ } } },
    { "Type": "Encoder", "Actions": { "0,0": { /* dial */ } } }
  ],
  "Icon": "",
  "Name": "Page name"
}
```

- `Actions` must be an **object**, never an array.
- Encoder positions: `"0,0"` … `"3,0"` for four dials.
- Empty controller: `"Actions": null` (common for unused Keypad/Encoder).

## Trevliga Spel MIDI (common settings)

Plugin UUID: `se.trevligaspel.midi` · Dial action: `se.trevligaspel.midi.dial` · Multi: `se.trevligaspel.midi.mixer`

| Key | Meaning |
| --- | --- |
| `smo` | MIDI Out port name |
| `smi` | MIDI In port name |
| `rsa` | Message type (`CC`, `PB`, `None`) |
| `rcn` | CC number (string) |
| `rch` / `rch1` / `rcch` | Channel (usually `"1"`) |
| `a20` | Response: `Ultra` (continuous) or `Fixed` (steps) |
| `rcm` / `rcs` / `rcx` | Fixed min / step / max |
| `of_t` / `on_t` | Value range (e.g. `0`–`127`) |
| `rccv` | Current/display value |
| `rn1` | Dial title text |
| `rcsd` / `rcsf` | VPot / fader XML paths (use `__TREVLIGA_PLUGIN__` when portable) |

Portable placeholder: `__TREVLIGA_PLUGIN__` →  
`%APPDATA%\Elgato\StreamDeck\Plugins\se.trevligaspel.midi.sdPlugin`

## Log message → fix

Log file: `%APPDATA%\Elgato\StreamDeck\logs\StreamDeck.json` (and rotated `StreamDeck.N.json`).

| Log / symptom | Likely cause | Fix |
| --- | --- | --- |
| `no pages in umbrella` | Page folders lowercase while Stream Deck expects UPPERCASE dirs | Recreate `Profiles\<UPPERCASE-GUID>\` |
| `failed to read profile from disk` | Often follows “no pages”; or corrupt/BOM root | Fix casing; rewrite root without BOM |
| Profile absent; UUID empty | `Device.UUID` is `""` | Stamp UUID from a visible profile |
| Root starts with `EF BB BF` | `Set-Content -Encoding UTF8` | Rewrite with `UTF8Encoding($false)` |
| Dials show wrong plugin paths | Absolute path from another machine | Run install script path repair |

## Repo scripts

| Script | Role |
| --- | --- |
| [`build-profile.ps1`](../../../build-profile.ps1) | Rebuild Reason-Fury.sdProfile from local templates |
| [`install-profile.ps1`](../../../install-profile.ps1) | Install Fury into ProfilesV3; expand plugin paths; optional `-Restart` |
| [`verify-profile.ps1`](../../../verify-profile.ps1) | Assert Fury CC/layout/nav content |
| [`verify-profile-load.ps1`](../../../verify-profile-load.ps1) | Assert loadability: BOM, UUID, UPPERCASE page folders |
| [`package-streamdeck.ps1`](../../../package-streamdeck.ps1) | Release zip |
| [`reason-streamdeck-remote/build-remote-profile.ps1`](../../../reason-streamdeck-remote/build-remote-profile.ps1) | Companion Remote profile |
| [`reason-streamdeck-remote/install-streamdeck-profile.ps1`](../../../reason-streamdeck-remote/install-streamdeck-profile.ps1) | Install Remote profile |
| [`reason-streamdeck-remote/install-remote.ps1`](../../../reason-streamdeck-remote/install-remote.ps1) | Install Reason Remote codec + map |

## Post-install check

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-profile-load.ps1 -Name 'Reason - Fury'
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-profile-load.ps1 -Name 'Reason - Remote'
```

Exit code `0` = structurally loadable. Still restart Stream Deck if the dropdown was already open.

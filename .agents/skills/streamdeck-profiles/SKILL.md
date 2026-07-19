---
name: streamdeck-profiles
description: >-
  Build, install, and debug Elgato Stream Deck+ .sdProfile trees (ProfilesV3,
  Trevliga Spel MIDI, Device.UUID, page GUID casing, UTF-8 BOM). Use when
  creating or installing Stream Deck profiles, editing Reason-Fury.sdProfile or
  reason-streamdeck-remote, running build-profile.ps1 / install-profile.ps1,
  or when a profile is missing from the Stream Deck UI dropdown.
---

# Stream Deck Profiles

## Mandatory first step

Before creating, editing, or installing any `.sdProfile`:

1. Re-read this skill.
2. Prefer existing repo scripts over inventing new JSON writers.
3. After install, run `verify-profile-load.ps1` and check Stream Deck logs if the profile is missing from the UI.

## Prefer existing scripts

| Profile | Build | Install |
| --- | --- | --- |
| Reason - Fury | `build-profile.ps1` | `install-profile.ps1` |
| Reason - Remote | `reason-streamdeck-remote/build-remote-profile.ps1` | `reason-streamdeck-remote/install-streamdeck-profile.ps1` |

Do not hand-roll a profile tree unless you apply every invariant below.

## Hard invariants

| Rule | Correct | Failure |
| --- | --- | --- |
| Page GUID casing | JSON `Pages` / `Current` / `Default` = **lowercase**; on-disk `Profiles\<GUID>\` = **UPPERCASE** | Log: `no pages in umbrella` / `failed to read profile from disk`; missing from UI |
| Device binding | Root `Device.Model` + non-empty `Device.UUID` from a working local profile | Never appears in dropdown |
| Root encoding | UTF-8 **without BOM** (`New-Object System.Text.UTF8Encoding $false` + `WriteAllText`) | Fails to load |
| Actions shape | `Controllers[].Actions` is a **JSON object** with keys `"0,0"`, not an array | Invalid page |
| Install path | `%APPDATA%\Elgato\StreamDeck\ProfilesV3\<UPPERCASE-GUID>.sdProfile\` | Not found |
| Plugin paths | Portable `__TREVLIGA_PLUGIN__`; expand on install | Broken dials |

### GUID casing (critical)

```powershell
$id = [guid]::NewGuid().ToString().ToLowerInvariant()   # JSON refs
$dir = Join-Path $profilesDir $id.ToUpperInvariant()    # on-disk folder only
```

Match [`build-profile.ps1`](../../../build-profile.ps1): lowercase in manifest, UPPERCASE directories.

### Never BOM on root manifest

Windows PowerShell 5.1 `Set-Content -Encoding UTF8` writes `EF BB BF`. Stream Deck rejects that on the umbrella `manifest.json`. Working profiles start with `{` (byte `0x7B`).

```powershell
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($path, $json, $utf8)
```

### Device.UUID

Copy from any visible local profile (e.g. Default Profile or Reason - Fury):

```json
"Device": { "Model": "20GBD9901", "UUID": "@(1)[4057/132/...]" }
```

Empty string = hidden.

## Workflows

### Build

1. Clone dial/multi/note action templates from local ProfilesV3 (or deep-clone a known-good page).
2. Rewrite CC/name/port settings; keep full Settings schema from the template.
3. Write each page under `Profiles\<UPPERCASE-GUID>\manifest.json`.
4. Write root manifest: `Name`, `Device` (with UUID), `Pages` (lowercase ids), `Version` `"3.0"`.
5. Use `__TREVLIGA_PLUGIN__` for Trevliga asset paths in portable trees.

### Install

1. Remove prior installs matching the same `Name`.
2. Copy to `ProfilesV3\<NEW-UPPERCASE-GUID>.sdProfile\`.
3. Expand `__TREVLIGA_PLUGIN__` to this machine’s plugin folder.
4. Ensure Device.UUID is stamped (install script may copy from a sibling profile).
5. Restart Stream Deck (`-Restart`) so the list refreshes.
6. Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-profile-load.ps1 -Name 'Reason - Remote'`

### Profile missing from UI

Check **in order**:

1. `%APPDATA%\Elgato\StreamDeck\logs\StreamDeck.json` — search `no pages in umbrella`, `failed to read profile from disk`
2. Root `manifest.json` first bytes — must not be `EF BB BF`
3. `Device.UUID` non-empty
4. Every lowercase JSON page id has a matching **UPPERCASE** folder under `Profiles\`
5. Restart Stream Deck

## MIDI ports (this repo)

| Profile | Out (`smo`) | In (`smi`) |
| --- | --- | --- |
| Reason - Fury | `loopMIDI Port` | `loopMIDI Port` (send-only; same cable) |
| Reason - Remote | `loopMIDI Port 1` | `loopMIDI Port 2` |

Do not share Fury’s `loopMIDI Port` with Remote’s dual-port pair. For bidirectional MIDI, In and Out must be **separate** ports.

## More detail

See [reference.md](reference.md) for ProfilesV3 layout, Trevliga settings keys, and log→fix map.

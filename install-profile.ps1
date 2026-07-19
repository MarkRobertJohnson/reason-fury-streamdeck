#Requires -Version 5.1
<#
.SYNOPSIS
  Install Reason-Fury.sdProfile into Stream Deck ProfilesV3.
  Expands portable __TREVLIGA_PLUGIN__ tokens and rewrites absolute
  Trevliga Spel plugin paths to this machine's AppData plugin folder.
#>
$ErrorActionPreference = 'Stop'

$Source = Join-Path $PSScriptRoot 'Reason-Fury.sdProfile'
$ProfilesV3 = Join-Path $env:APPDATA 'Elgato\StreamDeck\ProfilesV3'
$PluginRoot = Join-Path $env:APPDATA 'Elgato\StreamDeck\Plugins\se.trevligaspel.midi.sdPlugin'
$PluginMarker = 'se.trevligaspel.midi.sdPlugin'
$Placeholder = '__TREVLIGA_PLUGIN__'

if (-not (Test-Path $Source)) {
  throw "Missing profile source: $Source - run build-profile.ps1 or unzip the release package here."
}
if (-not (Test-Path $ProfilesV3)) {
  throw "Stream Deck ProfilesV3 not found: $ProfilesV3"
}
if (-not (Test-Path $PluginRoot)) {
  throw @"
Trevliga Spel MIDI plugin not found at:
  $PluginRoot
Install it from https://trevligaspel.se/streamdeck/midi/index.php then re-run this script.
"@
}

function Repair-ProfileMidiPaths([string]$profileDir) {
  # JSON text uses escaped backslashes (\\) in path strings.
  $escapedPlugin = $PluginRoot.Replace('\', '\\')
  $absPluginPattern = '(?i)[A-Za-z]:(?:\\\\[^"\\]+)*\\\\' + [regex]::Escape($PluginMarker)

  Get-ChildItem $profileDir -Recurse -Filter 'manifest.json' | ForEach-Object {
    $text = [System.IO.File]::ReadAllText($_.FullName)
    $orig = $text
    $text = $text.Replace($Placeholder, $escapedPlugin)
    $text = [regex]::Replace($text, $absPluginPattern, $escapedPlugin)
    if ($text -ne $orig) {
      [System.IO.File]::WriteAllText($_.FullName, $text)
    }
  }
}

# Remove any previous Reason - Fury installs
Get-ChildItem $ProfilesV3 -Directory -Filter '*.sdProfile' | ForEach-Object {
  $m = Join-Path $_.FullName 'manifest.json'
  if (-not (Test-Path $m)) { return }
  try {
    $name = (Get-Content $m -Raw | ConvertFrom-Json).Name
  } catch { return }
  if ($name -eq 'Reason - Fury') {
    Write-Host "Removing previous install: $($_.Name)"
    Remove-Item -Recurse -Force $_.FullName
  }
}

$newId = [guid]::NewGuid().ToString().ToUpperInvariant()
$dest = Join-Path $ProfilesV3 ($newId + '.sdProfile')
Copy-Item -Recurse -Force $Source $dest
Repair-ProfileMidiPaths $dest

Write-Host "Installed: $dest"
Write-Host "Profile name: Reason - Fury"
Write-Host "Restart Stream Deck (or switch profiles) if it does not appear immediately."

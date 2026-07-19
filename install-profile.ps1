#Requires -Version 5.1
<#
.SYNOPSIS
  Install Reason-Fury.sdProfile into Stream Deck ProfilesV3.
  Expands portable __TREVLIGA_PLUGIN__ tokens and rewrites absolute
  Trevliga Spel plugin paths to this machine's AppData plugin folder.

.PARAMETER Restart
  Stop Stream Deck after install, then start it again so the new profile is picked up.
#>
param(
  [switch]$Restart
)

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

function Get-StreamDeckExe {
  $running = Get-Process -Name 'StreamDeck' -ErrorAction SilentlyContinue |
    Where-Object { $_.Path } |
    Select-Object -First 1
  if ($running -and (Test-Path $running.Path)) {
    return $running.Path
  }
  foreach ($candidate in @(
    (Join-Path ${env:ProgramFiles} 'Elgato\StreamDeck\StreamDeck.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Elgato\StreamDeck\StreamDeck.exe')
  )) {
    if ($candidate -and (Test-Path $candidate)) { return $candidate }
  }
  return $null
}

function Restart-StreamDeck {
  $exe = Get-StreamDeckExe
  if (-not $exe) {
    Write-Warning 'Stream Deck.exe not found; installed profile but could not restart the app.'
    return
  }

  $procs = @(Get-Process -Name 'StreamDeck' -ErrorAction SilentlyContinue)
  if ($procs.Count -gt 0) {
    Write-Host "Stopping Stream Deck ($($procs.Count) process(es))..."
    $procs | Stop-Process -Force
    $deadline = (Get-Date).AddSeconds(15)
    while ((Get-Date) -lt $deadline) {
      $left = @(Get-Process -Name 'StreamDeck' -ErrorAction SilentlyContinue)
      if ($left.Count -eq 0) { break }
      Start-Sleep -Milliseconds 200
    }
  } else {
    Write-Host 'Stream Deck was not running.'
  }

  Write-Host "Starting Stream Deck: $exe"
  Start-Process -FilePath $exe
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

if ($Restart) {
  Restart-StreamDeck
} else {
  Write-Host "Restart Stream Deck (or run with -Restart) if it does not appear immediately."
}

#Requires -Version 5.1
<#
.SYNOPSIS
  Install Reason-Remote.sdProfile into Stream Deck ProfilesV3.
#>
param(
  [switch]$Restart
)

$ErrorActionPreference = 'Stop'

$Source = Join-Path $PSScriptRoot 'StreamDeck\Reason-Remote.sdProfile'
$ProfilesV3 = Join-Path $env:APPDATA 'Elgato\StreamDeck\ProfilesV3'
$PluginRoot = Join-Path $env:APPDATA 'Elgato\StreamDeck\Plugins\se.trevligaspel.midi.sdPlugin'
$PluginMarker = 'se.trevligaspel.midi.sdPlugin'
$Placeholder = '__TREVLIGA_PLUGIN__'

if (-not (Test-Path $Source)) {
  throw "Missing profile: $Source - run .\build-remote-profile.ps1 first."
}
if (-not (Test-Path $ProfilesV3)) {
  throw "Stream Deck ProfilesV3 not found: $ProfilesV3"
}
if (-not (Test-Path $PluginRoot)) {
  throw @"
Trevliga Spel MIDI plugin not found at:
  $PluginRoot
Install it from https://trevligaspel.se/streamdeck/midi/index.php
"@
}

function Repair-ProfileMidiPaths([string]$profileDir) {
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

function Get-LocalDeviceBinding {
  foreach ($dir in @(Get-ChildItem $ProfilesV3 -Directory -Filter '*.sdProfile' -ErrorAction SilentlyContinue)) {
    $m = Join-Path $dir.FullName 'manifest.json'
    if (-not (Test-Path $m)) { continue }
    try {
      $j = Get-Content -Raw $m | ConvertFrom-Json
      if ($j.Name -eq 'Reason - Remote') { continue }
      if ($j.Device.Model -and $j.Device.UUID) {
        return [pscustomobject]@{ Model = [string]$j.Device.Model; UUID = [string]$j.Device.UUID }
      }
    } catch {}
  }
  return $null
}

function Write-Utf8NoBom([string]$path, [string]$text) {
  # Windows PowerShell Set-Content -Encoding UTF8 writes a BOM; Stream Deck
  # ignores profiles whose root manifest.json starts with EF BB BF.
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, $text, $utf8)
}

function Set-ProfileDeviceBinding([string]$profileDir, $binding) {
  $rootManifest = Join-Path $profileDir 'manifest.json'
  $j = Get-Content -Raw $rootManifest | ConvertFrom-Json
  if (-not $j.Device) { $j | Add-Member -NotePropertyName Device -NotePropertyValue ([pscustomobject]@{}) }
  $j.Device.Model = $binding.Model
  $j.Device.UUID = $binding.UUID
  Write-Utf8NoBom $rootManifest ($j | ConvertTo-Json -Depth 20)
}

function Get-StreamDeckExe {
  $running = Get-Process -Name 'StreamDeck' -ErrorAction SilentlyContinue |
    Where-Object { $_.Path } |
    Select-Object -First 1
  if ($running -and (Test-Path $running.Path)) { return $running.Path }
  foreach ($candidate in @(
    (Join-Path ${env:ProgramFiles} 'Elgato\StreamDeck\StreamDeck.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Elgato\StreamDeck\StreamDeck.exe')
  )) {
    if ($candidate -and (Test-Path $candidate)) { return $candidate }
  }
  return $null
}

# Remove prior installs of this profile name
Get-ChildItem $ProfilesV3 -Directory -ErrorAction SilentlyContinue | ForEach-Object {
  $m = Join-Path $_.FullName 'manifest.json'
  if (Test-Path $m) {
    try {
      $j = Get-Content -Raw $m | ConvertFrom-Json
      if ($j.Name -eq 'Reason - Remote') {
        Remove-Item -Recurse -Force $_.FullName
      }
    } catch {}
  }
}

$binding = Get-LocalDeviceBinding
if (-not $binding) {
  throw @"
No existing Stream Deck profile with a Device.UUID was found in:
  $ProfilesV3
Connect your Stream Deck+, open the app once so a Default Profile exists, then re-run.
"@
}

$destId = [guid]::NewGuid().ToString().ToUpperInvariant()
$dest = Join-Path $ProfilesV3 "$destId.sdProfile"
Copy-Item -Recurse -Force $Source $dest
Repair-ProfileMidiPaths $dest
Set-ProfileDeviceBinding $dest $binding

Write-Host "Installed Stream Deck profile:"
Write-Host "  $dest"
Write-Host "Select profile: Reason - Remote"
Write-Host "Device: Model=$($binding.Model) UUID=$($binding.UUID)"
Write-Host "Ports: Out=loopMIDI Port 1, In=loopMIDI Port 2"

if ($Restart) {
  $exe = Get-StreamDeckExe
  if (-not $exe) {
    Write-Warning 'Stream Deck.exe not found; installed profile but could not restart.'
    return
  }
  $procs = @(Get-Process -Name 'StreamDeck' -ErrorAction SilentlyContinue)
  if ($procs.Count -gt 0) {
    Write-Host "Stopping Stream Deck..."
    $procs | Stop-Process -Force
    Start-Sleep -Seconds 2
  }
  Write-Host "Starting Stream Deck..."
  Start-Process $exe
}

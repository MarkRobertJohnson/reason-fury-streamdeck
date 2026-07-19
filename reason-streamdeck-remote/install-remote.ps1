#Requires -Version 5.1
<#
.SYNOPSIS
  Install Community / Stream Deck+ Remote codec + map into Reason's Remote folders.

.PARAMETER RemoteRoot
  Override install root (default: %PROGRAMDATA%\Propellerhead Software\Remote)

.PARAMETER AlsoInstallProfile
  Also build (if needed) and install the companion Stream Deck profile.
#>
param(
  [string]$RemoteRoot = (Join-Path $env:PROGRAMDATA 'Propellerhead Software\Remote'),
  [switch]$AlsoInstallProfile,
  [switch]$RestartStreamDeck
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

$srcCodec = Join-Path $Root 'Codecs\Lua Codecs\Community'
$srcMap = Join-Path $Root 'Maps\Community'
$dstCodec = Join-Path $RemoteRoot 'Codecs\Lua Codecs\Community'
$dstMap = Join-Path $RemoteRoot 'Maps\Community'

if (-not (Test-Path $srcCodec)) { throw "Missing codec folder: $srcCodec" }
if (-not (Test-Path $srcMap)) { throw "Missing map folder: $srcMap" }

New-Item -ItemType Directory -Force -Path $dstCodec | Out-Null
New-Item -ItemType Directory -Force -Path $dstMap | Out-Null

Copy-Item -Force (Join-Path $srcCodec '*') $dstCodec
Copy-Item -Force (Join-Path $srcMap '*') $dstMap

Write-Host "Installed Reason Remote files to:"
Write-Host "  $dstCodec"
Write-Host "  $dstMap"
Write-Host ""
Write-Host "Next in Reason:"
Write-Host "  1. Restart Reason (required to reload codecs)."
Write-Host "  2. Preferences → MIDI → Add manually"
Write-Host "  3. Manufacturer: Community  |  Model: Stream Deck+ Remote"
Write-Host "  4. Input Port:  loopMIDI Port 1"
Write-Host "  5. Output Port: loopMIDI Port 2"
Write-Host "  6. Disable Easy MIDI on Port 1 / Port 2 (avoid double-handling)."

if ($AlsoInstallProfile) {
  $build = Join-Path $Root 'build-remote-profile.ps1'
  $installSd = Join-Path $Root 'install-streamdeck-profile.ps1'
  & $build
  $sdArgs = @()
  if ($RestartStreamDeck) { $sdArgs += '-Restart' }
  & $installSd @sdArgs
}

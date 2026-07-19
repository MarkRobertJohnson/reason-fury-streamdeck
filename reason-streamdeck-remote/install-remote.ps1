#Requires -Version 5.1
<#
.SYNOPSIS
  Install Community / Stream Deck+ Remote codec + map into Reason/Recon Remote folders.

.DESCRIPTION
  Copies Lua codec + remotemap into:
    - %PROGRAMDATA%\Propellerhead Software\Remote
    - %APPDATA%\Propellerhead Software\Remote
  The map file must be named "Community Stream Deck+ Remote.remotemap"
  (Manufacturer + Model). A wrong filename yields:
  "Remote Mapping file cannot be found" and disables port selectors / OK.

.PARAMETER AlsoInstallProfile
  Also build and install companion Stream Deck profile(s).

.PARAMETER Profile
  Which Deck profile(s) when -AlsoInstallProfile: Demo (Reason - Remote),
  Fury (Reason - Fury Remote), or Both. Default: Demo.

.PARAMETER RestartStreamDeck
  When used with -AlsoInstallProfile, restart the Stream Deck app after install.
#>
param(
  [switch]$AlsoInstallProfile,
  [ValidateSet('Demo', 'Fury', 'Both')]
  [string]$Profile = 'Demo',
  [switch]$RestartStreamDeck
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

$srcCodec = Join-Path $Root 'Codecs\Lua Codecs\Community'
$srcMap = Join-Path $Root 'Maps\Community'
$expectedMap = 'Community Stream Deck+ Remote.remotemap'

if (-not (Test-Path $srcCodec)) { throw "Missing codec folder: $srcCodec" }
if (-not (Test-Path $srcMap)) { throw "Missing map folder: $srcMap" }
if (-not (Test-Path (Join-Path $srcMap $expectedMap))) {
  throw "Missing map file: $srcMap\$expectedMap (name must be Manufacturer + Model)"
}

$roots = @(
  (Join-Path $env:PROGRAMDATA 'Propellerhead Software\Remote'),
  (Join-Path $env:APPDATA 'Propellerhead Software\Remote')
)

foreach ($remoteRoot in $roots) {
  $dstCodec = Join-Path $remoteRoot 'Codecs\Lua Codecs\Community'
  $dstMap = Join-Path $remoteRoot 'Maps\Community'
  New-Item -ItemType Directory -Force -Path $dstCodec | Out-Null
  New-Item -ItemType Directory -Force -Path $dstMap | Out-Null

  # Remove legacy wrong filename from earlier installs
  Remove-Item -Force (Join-Path $dstMap 'Stream Deck+ Remote.remotemap') -ErrorAction SilentlyContinue

  Copy-Item -Force (Join-Path $srcCodec '*') $dstCodec
  Copy-Item -Force (Join-Path $srcMap '*') $dstMap

  Write-Host "Installed Remote files to:"
  Write-Host "  $dstCodec"
  Write-Host "  $dstMap\$expectedMap"
}

Write-Host ""
Write-Host "Next in Reason / Reason Recon:"
Write-Host "  1. Fully quit and restart the app (required to reload maps)."
Write-Host "  2. Preferences -> MIDI -> Add manually"
Write-Host "  3. Manufacturer: Community  |  Model: Stream Deck+ Remote"
Write-Host "  4. Input Port:  loopMIDI Port 1"
Write-Host "  5. Output Port: loopMIDI Port 2"
Write-Host "  6. Disable Easy MIDI on Port 1 / Port 2 (avoid double-handling)."

if ($AlsoInstallProfile) {
  $installSd = Join-Path $Root 'install-streamdeck-profile.ps1'
  $jobs = @()
  if ($Profile -eq 'Demo' -or $Profile -eq 'Both') {
    $jobs += @{
      Build  = (Join-Path $Root 'build-remote-profile.ps1')
      Name   = 'Reason - Remote'
      Source = 'StreamDeck\Reason-Remote.sdProfile'
    }
  }
  if ($Profile -eq 'Fury' -or $Profile -eq 'Both') {
    $jobs += @{
      Build  = (Join-Path $Root 'build-fury-remote-profile.ps1')
      Name   = 'Reason - Fury Remote'
      Source = 'StreamDeck\Reason-Fury-Remote.sdProfile'
    }
  }
  for ($i = 0; $i -lt $jobs.Count; $i++) {
    $job = $jobs[$i]
    & $job.Build
    $sdArgs = @{
      ProfileName    = $job.Name
      SourceRelative = $job.Source
    }
    if ($RestartStreamDeck -and $i -eq ($jobs.Count - 1)) {
      $sdArgs.Restart = $true
    }
    & $installSd @sdArgs
  }
}

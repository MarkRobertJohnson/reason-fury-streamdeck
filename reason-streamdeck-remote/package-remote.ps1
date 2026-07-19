#Requires -Version 5.1
<#
.SYNOPSIS
  Package a portable Reason-StreamDeck-Remote.zip for GitHub Releases.
#>
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$RepoRoot = Split-Path $ScriptDir -Parent
$DistRoot = Join-Path $RepoRoot 'dist'
$StageName = 'Reason-StreamDeck-Remote'
$StageDir = Join-Path $DistRoot $StageName
$ZipPath = Join-Path $DistRoot 'Reason-StreamDeck-Remote.zip'
$PluginMarker = 'se.trevligaspel.midi.sdPlugin'
$Placeholder = '__TREVLIGA_PLUGIN__'

$DemoProfile = Join-Path $ScriptDir 'StreamDeck\Reason-Remote.sdProfile'
$FuryProfile = Join-Path $ScriptDir 'StreamDeck\Reason-Fury-Remote.sdProfile'

function Ensure-Profile([string]$Path, [string]$BuildScript) {
  if (-not (Test-Path (Join-Path $Path 'manifest.json'))) {
    Write-Host "Building profile via $BuildScript..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir $BuildScript)
    if ($LASTEXITCODE -ne 0) { throw "$BuildScript failed" }
  }
  if (-not (Test-Path (Join-Path $Path 'manifest.json'))) {
    throw "Missing profile after build: $Path"
  }
}

function Sanitize-SdProfile([string]$ProfileDir) {
  $rootManifestPath = Join-Path $ProfileDir 'manifest.json'
  $manifestRoot = Get-Content $rootManifestPath -Raw | ConvertFrom-Json
  $manifestRoot.AppIdentifier = ''
  if ($manifestRoot.Device) {
    $manifestRoot.Device | Add-Member -NotePropertyName UUID -NotePropertyValue '' -Force
  }
  ($manifestRoot | ConvertTo-Json -Depth 20) | Set-Content -Path $rootManifestPath -Encoding UTF8

  # In JSON text, path separators are escaped as \\ (two chars).
  $absPluginPattern = '(?i)[A-Za-z]:(?:\\\\[^"\\]+)*\\\\' + [regex]::Escape($PluginMarker)
  $rewrote = 0
  Get-ChildItem $ProfileDir -Recurse -Filter 'manifest.json' | ForEach-Object {
    $raw = [System.IO.File]::ReadAllText($_.FullName)
    if ($raw -notlike "*$PluginMarker*") { return }
    $portable = [regex]::Replace($raw, $absPluginPattern, $Placeholder)
    if ($portable -ne $raw) {
      [System.IO.File]::WriteAllText($_.FullName, $portable)
      $rewrote++
    }
  }
  Write-Host "  Rewrote plugin paths in $rewrote manifest file(s) under $(Split-Path $ProfileDir -Leaf)"
}

Ensure-Profile $DemoProfile 'build-remote-profile.ps1'
Ensure-Profile $FuryProfile 'build-fury-remote-profile.ps1'

$codecDir = Join-Path $ScriptDir 'Codecs\Lua Codecs\Community'
$mapDir = Join-Path $ScriptDir 'Maps\Community'
$mapFile = Join-Path $mapDir 'Community Stream Deck+ Remote.remotemap'
if (-not (Test-Path $codecDir)) { throw "Missing codec folder: $codecDir" }
if (-not (Test-Path $mapFile)) { throw "Missing map file: $mapFile" }

if (Test-Path $StageDir) { Remove-Item -Recurse -Force $StageDir }
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null

Write-Host "Staging Remote release..."
Copy-Item -Recurse -Force (Join-Path $ScriptDir 'Codecs') (Join-Path $StageDir 'Codecs')
Copy-Item -Recurse -Force (Join-Path $ScriptDir 'Maps') (Join-Path $StageDir 'Maps')

$stagedStreamDeck = Join-Path $StageDir 'StreamDeck'
New-Item -ItemType Directory -Force -Path $stagedStreamDeck | Out-Null
Copy-Item -Recurse -Force $DemoProfile (Join-Path $stagedStreamDeck 'Reason-Remote.sdProfile')
Copy-Item -Recurse -Force $FuryProfile (Join-Path $stagedStreamDeck 'Reason-Fury-Remote.sdProfile')

Write-Host "Sanitizing Stream Deck profiles..."
Sanitize-SdProfile (Join-Path $stagedStreamDeck 'Reason-Remote.sdProfile')
Sanitize-SdProfile (Join-Path $stagedStreamDeck 'Reason-Fury-Remote.sdProfile')

$copyFiles = @(
  'install-remote.ps1',
  'install-streamdeck-profile.ps1',
  'build-remote-profile.ps1',
  'build-fury-remote-profile.ps1',
  'README.md',
  'fury-remote-cc-map.md',
  'Fury.remoteinfo.txt'
)
foreach ($name in $copyFiles) {
  $src = Join-Path $ScriptDir $name
  if (Test-Path $src) {
    Copy-Item -Force $src (Join-Path $StageDir $name)
  }
}

if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
New-Item -ItemType Directory -Force -Path $DistRoot | Out-Null
Compress-Archive -Path $StageDir -DestinationPath $ZipPath -Force

Write-Host ""
Write-Host "Packaged: $ZipPath"
Write-Host "Stage:    $StageDir"
Write-Host "Upload with: gh release create <tag> -a `"$ZipPath`""

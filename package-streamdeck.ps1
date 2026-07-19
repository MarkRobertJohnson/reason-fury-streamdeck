#Requires -Version 5.1
<#
.SYNOPSIS
  Package a portable Reason-Fury-StreamDeck.zip for GitHub Releases.
#>
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$SourceProfile = Join-Path $ScriptDir 'Reason-Fury.sdProfile'
$DistRoot = Join-Path $ScriptDir 'dist'
$StageName = 'Reason-Fury-StreamDeck'
$StageDir = Join-Path $DistRoot $StageName
$ZipPath = Join-Path $DistRoot 'Reason-Fury-StreamDeck.zip'
$PluginMarker = 'se.trevligaspel.midi.sdPlugin'
$Placeholder = '__TREVLIGA_PLUGIN__'

if (-not (Test-Path $SourceProfile)) {
  throw "Missing $SourceProfile - run build-profile.ps1 first."
}

Write-Host "Verifying profile..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir 'verify-profile.ps1')
if ($LASTEXITCODE -ne 0) { throw "verify-profile.ps1 failed" }

# Only clear this package's stage/zip so sibling release zips in dist/ survive.
if (Test-Path $StageDir) { Remove-Item -Recurse -Force $StageDir }
if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null

$stagedProfile = Join-Path $StageDir 'Reason-Fury.sdProfile'
Copy-Item -Recurse -Force $SourceProfile $stagedProfile

# Sanitize root manifest for other machines
$rootManifestPath = Join-Path $stagedProfile 'manifest.json'
$manifestRoot = Get-Content $rootManifestPath -Raw | ConvertFrom-Json
$manifestRoot.AppIdentifier = ''
if ($manifestRoot.Device) {
  $manifestRoot.Device | Add-Member -NotePropertyName UUID -NotePropertyValue '' -Force
}
($manifestRoot | ConvertTo-Json -Depth 20) | Set-Content -Path $rootManifestPath -Encoding UTF8

# In JSON text, path separators are escaped as \\ (two chars). Match any absolute
# prefix ending at the Trevliga plugin folder and replace with the placeholder.
$absPluginPattern = '(?i)[A-Za-z]:(?:\\\\[^"\\]+)*\\\\' + [regex]::Escape($PluginMarker)

$rewrote = 0
Get-ChildItem $stagedProfile -Recurse -Filter 'manifest.json' | ForEach-Object {
  $raw = [System.IO.File]::ReadAllText($_.FullName)
  if ($raw -notlike "*$PluginMarker*") { return }
  $portable = [regex]::Replace($raw, $absPluginPattern, $Placeholder)
  if ($portable -ne $raw) {
    [System.IO.File]::WriteAllText($_.FullName, $portable)
    $rewrote++
  }
}
Write-Host "Rewrote plugin paths in $rewrote manifest file(s)"

Copy-Item -Force (Join-Path $ScriptDir 'install-profile.ps1') (Join-Path $StageDir 'install-profile.ps1')
Copy-Item -Force (Join-Path $ScriptDir 'midi-cc-map.md') (Join-Path $StageDir 'midi-cc-map.md')
Copy-Item -Force (Join-Path $ScriptDir 'README.md') (Join-Path $StageDir 'README.md')

if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
Compress-Archive -Path $StageDir -DestinationPath $ZipPath -Force

Write-Host ""
Write-Host "Packaged: $ZipPath"
Write-Host "Stage:    $StageDir"
Write-Host "Upload with: gh release create <tag> -a `"$ZipPath`""

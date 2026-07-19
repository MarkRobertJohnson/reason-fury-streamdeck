#Requires -Version 5.1
<#
.SYNOPSIS
  Build StreamDeck/Reason-Remote.sdProfile — 4 encoder companion for the
  Community / Stream Deck+ Remote codec (dual loopMIDI ports).
#>
$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
$RepoRoot = Split-Path $Root -Parent
$FuryPage = Join-Path $RepoRoot 'Reason-Fury.sdProfile\Profiles\98DE7BAB-B822-404A-99D5-EA94C4A5788C\manifest.json'
$OutRoot = Join-Path $Root 'StreamDeck\Reason-Remote.sdProfile'
$Placeholder = '__TREVLIGA_PLUGIN__'

if (-not (Test-Path $FuryPage)) {
  throw "Dial template source missing: $FuryPage"
}

function ConvertTo-PlainObject($obj) {
  ($obj | ConvertTo-Json -Depth 100 | ConvertFrom-Json)
}

function New-GuidString {
  [guid]::NewGuid().ToString().ToLowerInvariant()
}

function Set-RemoteDial($action, [string]$name, [int]$cc) {
  $s = $action.Settings
  $s.rn1 = $name
  $s.rcn = [string]$cc
  $s.rsa = 'CC'
  $s.rch = '1'
  $s.rch1 = '1'
  $s.rcch = '1'
  # Dual ports: Out → Reason Remote In; In ← Reason Remote Out
  $s.smi = 'loopMIDI Port 2'
  $s.smo = 'loopMIDI Port 1'
  $s.of_t = '0'
  $s.on_t = '127'
  $s.ch_t = '1'
  $s.a20 = 'Ultra'
  $s.rccv = '0'
  $s.rcm = '0'
  $s.rcx = '127'
}

$fury = Get-Content -Raw $FuryPage | ConvertFrom-Json
$encCtrl = @($fury.Controllers | Where-Object { $_.Type -eq 'Encoder' })[0]
$dialTemplate = ConvertTo-PlainObject $encCtrl.Actions.'0,0'

$knobs = @(
  @{ Name = 'Knob 1'; Cc = 20 },
  @{ Name = 'Knob 2'; Cc = 21 },
  @{ Name = 'Knob 3'; Cc = 22 },
  @{ Name = 'Knob 4'; Cc = 23 }
)

$encoderActions = [ordered]@{}
for ($i = 0; $i -lt $knobs.Count; $i++) {
  $k = $knobs[$i]
  $action = ConvertTo-PlainObject $dialTemplate
  $action.ActionID = New-GuidString
  Set-RemoteDial $action $k.Name $k.Cc
  if ($action.States -and $action.States.Count -gt 0) {
    $action.States[0].Title = $k.Name
    $action.States[0].ShowTitle = $true
  }
  $encoderActions["$i,0"] = $action
}

# Optional keypad: 4 CC buttons (30-33) cloned from first dial for feedback toggles
$keypadActions = [ordered]@{}
$buttons = @(
  @{ Name = 'Btn 1'; Cc = 30 },
  @{ Name = 'Btn 2'; Cc = 31 },
  @{ Name = 'Btn 3'; Cc = 32 },
  @{ Name = 'Btn 4'; Cc = 33 }
)
for ($i = 0; $i -lt $buttons.Count; $i++) {
  $b = $buttons[$i]
  $action = ConvertTo-PlainObject $dialTemplate
  $action.ActionID = New-GuidString
  $action.Name = 'Generic Midi'
  Set-RemoteDial $action $b.Name $b.Cc
  # Fixed 0/127 for button-like CC
  $action.Settings.a20 = 'Fixed'
  $action.Settings.rcs = '127'
  $action.Settings.rcm = '0'
  $action.Settings.rcx = '127'
  $action.Settings.rccv = '0'
  if ($action.States -and $action.States.Count -gt 0) {
    $action.States[0].Title = $b.Name
  }
  $row = [int][math]::Floor($i / 4)
  $col = $i % 4
  $keypadActions["$col,$row"] = $action
}

$pageId = New-GuidString
$defaultId = New-GuidString
# Stream Deck resolves page folders case-sensitively: JSON refs are lowercase,
# on-disk Profiles\<GUID> folders must be UPPERCASE (same as build-profile.ps1).
$pageDirName = $pageId.ToUpperInvariant()
$defaultDirName = $defaultId.ToUpperInvariant()

if (Test-Path $OutRoot) {
  Remove-Item -Recurse -Force $OutRoot
}
New-Item -ItemType Directory -Force -Path (Join-Path $OutRoot "Profiles\$pageDirName") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutRoot "Profiles\$defaultDirName") | Out-Null

$pageManifest = [ordered]@{
  Controllers = @(
    [ordered]@{
      Actions = $keypadActions
      Type    = 'Keypad'
    },
    [ordered]@{
      Actions = $encoderActions
      Type    = 'Encoder'
    }
  )
  Icon = ''
  Name = 'Remote'
}

$defaultManifest = [ordered]@{
  Controllers = @(
    [ordered]@{ Actions = $null; Type = 'Keypad' },
    [ordered]@{ Actions = $null; Type = 'Encoder' }
  )
  Icon = ''
  Name = ''
}

function Get-LocalStreamDeckDevice {
  # Profiles are bound to a physical Deck. Empty Device.UUID = profile never appears in the UI.
  $profilesV3 = Join-Path $env:APPDATA 'Elgato\StreamDeck\ProfilesV3'
  $candidates = [System.Collections.Generic.List[string]]::new()
  Get-ChildItem $profilesV3 -Directory -Filter '*.sdProfile' -ErrorAction SilentlyContinue | ForEach-Object {
    $candidates.Add((Join-Path $_.FullName 'manifest.json')) | Out-Null
  }
  $candidates.Add((Join-Path $RepoRoot 'Reason-Fury.sdProfile\manifest.json')) | Out-Null

  $fallback = $null
  foreach ($candidate in $candidates) {
    if (-not (Test-Path $candidate)) { continue }
    try {
      $j = Get-Content -Raw $candidate | ConvertFrom-Json
      if ($j.Name -eq 'Reason - Remote') { continue }
      if (-not ($j.Device.Model -and $j.Device.UUID)) { continue }
      $hit = [pscustomobject]@{
        Model         = [string]$j.Device.Model
        UUID          = [string]$j.Device.UUID
        AppIdentifier = $(if ($j.AppIdentifier) { [string]$j.AppIdentifier } else { $null })
        Name          = [string]$j.Name
      }
      # Prefer Reason-bound profiles for AppIdentifier auto-switch.
      if ($hit.Name -like 'Reason*') { return $hit }
      if (-not $fallback) { $fallback = $hit }
    } catch {}
  }
  return $fallback
}

$device = Get-LocalStreamDeckDevice
if (-not $device) {
  throw @"
Could not find a Stream Deck Device.UUID to bind this profile to.
Open Stream Deck once with your Deck connected, or ensure Reason-Fury.sdProfile/manifest.json has Device.UUID set.
"@
}

$defaultReasonExe = 'D:\Program Files\Propellerhead\Reason 13\Reason.exe'
$appId = $defaultReasonExe
if ($device.AppIdentifier -and ($device.AppIdentifier -match '(?i)Reason')) {
  $appId = $device.AppIdentifier
} elseif (Test-Path $defaultReasonExe) {
  $appId = $defaultReasonExe
} elseif ($device.AppIdentifier) {
  # Keep device UUID from any profile, but do not inherit unrelated app auto-switch (e.g. OBS).
  $appId = $defaultReasonExe
}

$rootManifest = [ordered]@{
  AppIdentifier = $appId
  Device        = [ordered]@{
    Model = $device.Model
    UUID  = $device.UUID
  }
  Name  = 'Reason - Remote'
  Pages = [ordered]@{
    Current = $pageId
    Default = $defaultId
    Pages   = @($pageId)
  }
  Version = '3.0'
}

function Write-JsonFile([string]$path, $obj) {
  $json = $obj | ConvertTo-Json -Depth 100
  # Portable plugin paths
  $pluginMarker = 'se.trevligaspel.midi.sdPlugin'
  $absPattern = '(?i)[A-Za-z]:(?:\\\\[^"\\]+)*\\\\' + [regex]::Escape($pluginMarker)
  $json = [regex]::Replace($json, $absPattern, $Placeholder.Replace('\', '\\'))
  # Also replace single-backslash style if ConvertTo-Json emitted them unescaped oddly
  $json = $json.Replace(
    ($env:APPDATA + '\Elgato\StreamDeck\Plugins\' + $pluginMarker).Replace('\', '\\'),
    $Placeholder
  )
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, $json, $utf8)
}

Write-JsonFile (Join-Path $OutRoot 'manifest.json') $rootManifest
Write-JsonFile (Join-Path $OutRoot "Profiles\$pageDirName\manifest.json") $pageManifest
Write-JsonFile (Join-Path $OutRoot "Profiles\$defaultDirName\manifest.json") $defaultManifest

Write-Host "Built: $OutRoot"
Write-Host "Page:  $pageId (folder $pageDirName)"
Write-Host "Device: Model=$($device.Model) UUID=$($device.UUID)"
Write-Host "Ports: smo=loopMIDI Port 1 (Deck->Reason), smi=loopMIDI Port 2 (Reason->Deck)"
Write-Host "CCs:   Knobs 20-23, Buttons 30-33, channel 1"

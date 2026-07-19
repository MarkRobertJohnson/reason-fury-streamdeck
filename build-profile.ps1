#Requires -Version 5.1
<#
.SYNOPSIS
  Build Reason-Fury.sdProfile from local Stream Deck Multi Midi / dial / note templates.
  Seven control pages with keypad nav (Go to Page) + Notes folder (openchild).

.PARAMETER KnobLayout
  Maximize (default): spread params across all four encoders; dual Multi when needed.
  Compact: pack related params into fewer knobs (4-way Multi + singleton).
#>
param(
  [ValidateSet('Maximize', 'Compact')]
  [string]$KnobLayout = 'Maximize'
)

$ErrorActionPreference = 'Stop'

$OutRoot = Join-Path $PSScriptRoot 'Reason-Fury.sdProfile'
$ProfilesV3 = Join-Path $env:APPDATA 'Elgato\StreamDeck\ProfilesV3'

$MultiTemplatePage = Join-Path $ProfilesV3 '613B3FF6-417A-4397-8104-64E8E133C081.sdProfile\Profiles\87DEAD06-E720-436F-99D2-E4D06DD3F97F\manifest.json'
$DialTemplatePage  = Join-Path $ProfilesV3 '4504C016-1BB5-4C37-80A2-83A8E1E29B8D.sdProfile\Profiles\86D75B55-046A-48B1-B353-FEBF9A2BF528\manifest.json'
$NoteTemplatePage  = Join-Path $ProfilesV3 '613B3FF6-417A-4397-8104-64E8E133C081.sdProfile\Profiles\F97B7DFB-D503-4640-AD5E-05977DDE2B34\manifest.json'
$DeviceRootSrc     = Join-Path $ProfilesV3 '613B3FF6-417A-4397-8104-64E8E133C081.sdProfile\manifest.json'

foreach ($p in @($MultiTemplatePage, $DialTemplatePage, $NoteTemplatePage, $DeviceRootSrc)) {
  if (-not (Test-Path $p)) { throw "Missing Stream Deck template: $p" }
}

function New-GuidLower {
  [guid]::NewGuid().ToString().ToLowerInvariant()
}

function Get-DeepClone($obj) {
  $obj | ConvertTo-Json -Depth 100 -Compress | ConvertFrom-Json
}

function Get-EncoderAction($pageJson, $pos) {
  $enc = @($pageJson.Controllers | Where-Object { $_.Type -eq 'Encoder' })[0]
  return $enc.Actions.$pos
}

function Set-MultiSlots($action, [object[]]$slots, [int]$sfa) {
  $s = $action.Settings
  $s.sfa = $sfa
  $s.smi = 'loopMIDI Port'
  $s.smo = 'loopMIDI Port'
  $s.dos = $true
  $s.doj = $false
  $s.sps = $true
  $s.swps = $true
  $s.srs = $true
  $s.sss = $true
  $s.si20 = 'Rotate'
  for ($i = 1; $i -le 4; $i++) {
    if ($i -le $slots.Count) {
      $slot = $slots[$i - 1]
      $s."rn$i" = [string]$slot.Name
      $s."rcn$i" = [string]$slot.CC
      $s."rsa$i" = 'CC'
      $s."rch$i" = '1'
      $s."rcch$i" = '1'
      $s."rcsm$i" = $true
      $s."rpsk$i" = $true
      $s."rpsp$i" = $true
      $s."rsd$i" = 'knob'
      $s."rsm$i" = 'Move'
      $s."of_t$i" = '0'
      $s."on_t$i" = '127'
      $s."ch_t$i" = '1'
      # Optional FixedMax: discrete step selector (CC used as step index 0..FixedMax)
      if ($null -ne $slot.FixedMax) {
        $s."a20_$i" = 'Fixed'
        $s."rcs$i" = '1'
        $s."rcm$i" = '0'
        $s."rcx$i" = [string]$slot.FixedMax
      }
    } else {
      $s."rn$i" = ''
      $s."rcn$i" = '0'
      $s."rsa$i" = 'None'
      $s."rcsm$i" = $false
    }
  }
}

function Set-Dial($action, [string]$name, [int]$cc) {
  $s = $action.Settings
  $s.rn1 = $name
  $s.rcn = [string]$cc
  $s.rsa = 'CC'
  $s.rch = '1'
  $s.rch1 = '1'
  $s.rcch = '1'
  $s.smi = 'loopMIDI Port'
  $s.smo = 'loopMIDI Port'
  $s.of_t = '0'
  $s.on_t = '127'
  $s.ch_t = '1'
  $s.a20 = 'Ultra'
}

function Set-PitchBendDial($action, [string]$name) {
  $s = $action.Settings
  $s.rn1 = $name
  $s.rsa = 'PB'
  $s.rcn = '0'
  $s.rch = '1'
  $s.rch1 = '1'
  $s.rcch = '1'
  $s.smi = 'loopMIDI Port'
  $s.smo = 'loopMIDI Port'
  $s.of_t = '0'
  $s.on_t = '16383'
  $s.ch_t = '1'
  $s.a20 = 'Ultra'
  if ($null -ne $s.PSObject.Properties['rcx']) { $s.rcx = '16383' }
}

function Set-FixedStepDial($action, [string]$name, [int]$cc, [int]$maxStep) {
  Set-Dial $action $name $cc
  $s = $action.Settings
  # Discrete selectors: Advanced MIDI uses CC as step index 0..maxStep.
  $s.a20 = 'Fixed'
  $s.rcs = '1'
  $s.rcm = '0'
  $s.rcx = [string]$maxStep
  if ($null -ne $s.PSObject.Properties['rckf']) { $s.rckf = $true }
}

function Set-FixedShapeDial($action, [string]$name, [int]$cc) {
  Set-FixedStepDial $action $name $cc 3
}

function New-EmptyControllers {
  return @(
    [pscustomobject]@{ Actions = $null; Type = 'Keypad' },
    [pscustomobject]@{ Actions = [pscustomobject]@{}; Type = 'Encoder' }
  )
}

function Write-PageManifest([string]$dir, [string]$name, $controllers) {
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $page = [pscustomobject]@{
    Controllers = @($controllers)
    Icon = ''
    Name = $name
  }
  $json = $page | ConvertTo-Json -Depth 100
  Set-Content -Path (Join-Path $dir 'manifest.json') -Value $json -Encoding UTF8
}

function New-NavPageIcon([int]$pageIndex, [string]$outPath) {
  Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
  $size = 144
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
  $g.Clear([System.Drawing.Color]::FromArgb(255, 28, 28, 30))
  $font = New-Object System.Drawing.Font 'Segoe UI', 22, ([System.Drawing.FontStyle]::Bold)
  $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 200, 200, 205))
  $g.DrawString([string]$pageIndex, $font, $brush, 8.0, 4.0)
  $dir = Split-Path -Parent $outPath
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose()
  $bmp.Dispose()
  $font.Dispose()
  $brush.Dispose()
}

function New-NavIconAssets([int]$pageCount) {
  $dir = Join-Path $PSScriptRoot 'assets\nav'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  for ($i = 1; $i -le $pageCount; $i++) {
    New-NavPageIcon $i (Join-Path $dir "page-$i.png")
  }
  return $dir
}

function Install-NavImagesOnPage($controllers, [string]$pageDir, [string]$navIconDir) {
  $imagesDir = Join-Path $pageDir 'Images'
  New-Item -ItemType Directory -Force -Path $imagesDir | Out-Null
  $pad = @($controllers | Where-Object { $_.Type -eq 'Keypad' })[0]
  if (-not $pad -or -not $pad.Actions) { return }
  $posToIndex = [ordered]@{
    '0,0' = 1; '1,0' = 2; '2,0' = 3; '3,0' = 4
    '0,1' = 5; '1,1' = 6; '2,1' = 7
  }
  foreach ($pos in $posToIndex.Keys) {
    $act = $pad.Actions.$pos
    if (-not $act -or $act.UUID -ne 'com.elgato.streamdeck.page.goto') { continue }
    $idx = [int]$posToIndex[$pos]
    $fileName = ([guid]::NewGuid().ToString('N').ToUpperInvariant()) + '.png'
    Copy-Item -Force (Join-Path $navIconDir "page-$idx.png") (Join-Path $imagesDir $fileName)
    $act.States[0] | Add-Member -NotePropertyName Image -NotePropertyValue ("Images/" + $fileName) -Force
  }
}

function New-GoToPageAction([string]$title, [int]$pageIndex) {
  return [pscustomobject]@{
    ActionID    = (New-GuidLower)
    LinkedTitle = $true
    Name        = 'Go to Page'
    Plugin      = [pscustomobject]@{ Name = 'Pages'; UUID = 'com.elgato.streamdeck.page'; Version = '1.0' }
    Resources   = $null
    Settings    = [pscustomobject]@{ PageIndex = $pageIndex }
    State       = 0
    States      = @(
      [pscustomobject]@{
        FontFamily        = ''
        FontSize          = 11
        FontStyle         = ''
        FontUnderline     = $false
        OutlineThickness  = 2
        ShowTitle         = $true
        Title             = $title
        TitleAlignment    = 'middle'
        TitleColor        = '#ffffff'
      }
    )
    UUID = 'com.elgato.streamdeck.page.goto'
  }
}

function New-OpenChildAction([string]$title, [string]$childUuid) {
  return [pscustomobject]@{
    ActionID    = (New-GuidLower)
    LinkedTitle = $true
    Name        = 'Create Folder'
    Plugin      = [pscustomobject]@{ Name = 'Create Folder'; UUID = 'com.elgato.streamdeck.profile.openchild'; Version = '1.0' }
    Resources   = $null
    Settings    = [pscustomobject]@{ ProfileUUID = $childUuid }
    State       = 0
    States      = @(
      [pscustomobject]@{
        FontFamily        = ''
        FontSize          = 11
        FontStyle         = ''
        FontUnderline     = $false
        OutlineThickness  = 2
        ShowTitle         = $true
        Title             = $title
        TitleAlignment    = 'middle'
        TitleColor        = '#ffffff'
      }
    )
    UUID = 'com.elgato.streamdeck.profile.openchild'
  }
}

function New-BackToParentAction {
  return [pscustomobject]@{
    ActionID    = (New-GuidLower)
    LinkedTitle = $true
    Name        = 'Parent Folder'
    Plugin      = [pscustomobject]@{ Name = 'Open Parent Folder'; UUID = 'com.elgato.streamdeck.profile.backtoparent'; Version = '1.0' }
    Resources   = $null
    Settings    = [pscustomobject]@{}
    State       = 0
    States      = @([pscustomobject]@{})
    UUID        = 'com.elgato.streamdeck.profile.backtoparent'
  }
}

function New-NavKeypadActions([string]$notesChildUuid) {
  # Fixed layout on every control page:
  # [Core] [Osc] [Growl] [Motion]
  # [Out]  [Art] [Perf]  [Notes]
  $map = [ordered]@{
    '0,0' = New-GoToPageAction 'Core' 1
    '1,0' = New-GoToPageAction 'Osc' 2
    '2,0' = New-GoToPageAction 'Growl' 3
    '3,0' = New-GoToPageAction 'Motion' 4
    '0,1' = New-GoToPageAction 'Out' 5
    '1,1' = New-GoToPageAction 'Art' 6
    '2,1' = New-GoToPageAction 'Perf' 7
    '3,1' = New-OpenChildAction 'Notes' $notesChildUuid
  }
  return [pscustomobject]$map
}

# Load templates
$multiPage = Get-Content $MultiTemplatePage -Raw | ConvertFrom-Json
$dialPage  = Get-Content $DialTemplatePage -Raw | ConvertFrom-Json
$notePage  = Get-Content $NoteTemplatePage -Raw | ConvertFrom-Json
$deviceSrc = Get-Content $DeviceRootSrc -Raw | ConvertFrom-Json

$multiProto = Get-DeepClone (Get-EncoderAction $multiPage '1,0')
$dialProto  = Get-DeepClone (Get-EncoderAction $dialPage '0,0')

function New-MultiAction([object[]]$slots, [int]$sfa) {
  $a = Get-DeepClone $multiProto
  $a.ActionID = (New-GuidLower)
  Set-MultiSlots $a $slots $sfa
  return $a
}

function New-DialAction([string]$name, [int]$cc) {
  $a = Get-DeepClone $dialProto
  $a.ActionID = (New-GuidLower)
  Set-Dial $a $name $cc
  if ($a.States -and @($a.States).Count -gt 0) {
    $a.States[0] | Add-Member -NotePropertyName Title -NotePropertyValue $name -Force
  }
  return $a
}

function New-FixedStepDial([string]$name, [int]$cc, [int]$maxStep) {
  $a = Get-DeepClone $dialProto
  $a.ActionID = (New-GuidLower)
  Set-FixedStepDial $a $name $cc $maxStep
  if ($a.States -and @($a.States).Count -gt 0) {
    $a.States[0] | Add-Member -NotePropertyName Title -NotePropertyValue $name -Force
  }
  return $a
}

function New-FixedShapeDial([string]$name, [int]$cc) {
  New-FixedStepDial $name $cc 3
}

function New-PitchBendDial([string]$name) {
  $a = Get-DeepClone $dialProto
  $a.ActionID = (New-GuidLower)
  Set-PitchBendDial $a $name
  if ($a.States -and @($a.States).Count -gt 0) {
    $a.States[0] | Add-Member -NotePropertyName Title -NotePropertyValue $name -Force
  }
  return $a
}

function New-EncoderPage([string]$pageName, $encoderMap) {
  $controllers = New-EmptyControllers
  $actions = [ordered]@{}
  foreach ($key in ($encoderMap.Keys | Sort-Object)) {
    $actions[$key] = $encoderMap[$key]
  }
  $controllers[1].Actions = [pscustomobject]$actions
  return [pscustomobject]@{ Name = $pageName; Controllers = $controllers }
}

# Stable IDs — each control page gets its own Notes folder child.
# Stream Deck only binds a shared openchild UUID to one parent; per-page
# children make Notes work on every page.
$sectionNames = @('Core', 'Oscillator', 'Growl', 'Motion', 'Output', 'Articulation', 'Performance')
$sectionIds = @{}
$notesChildIds = @{}
foreach ($n in $sectionNames) {
  $sectionIds[$n] = New-GuidLower
  $notesChildIds[$n] = New-GuidLower
}
$defaultId = New-GuidLower

function New-NotesFolderControllers {
  $srcPad = @($notePage.Controllers | Where-Object { $_.Type -eq 'Keypad' })[0]
  $noteActions = [ordered]@{}
  $noteActions['0,0'] = New-BackToParentAction
  if ($srcPad -and $srcPad.Actions) {
    foreach ($prop in $srcPad.Actions.PSObject.Properties) {
      if (-not ($prop.Value -is [pscustomobject]) -or -not $prop.Value.UUID) { continue }
      if ($prop.Name -eq '0,0') { continue }
      if ($prop.Value.UUID -notmatch 'noteon') { continue }
      $clone = Get-DeepClone $prop.Value
      $clone.ActionID = (New-GuidLower)
      $noteActions[$prop.Name] = $clone
    }
  }
  return @(
    [pscustomobject]@{ Actions = [pscustomobject]$noteActions; Type = 'Keypad' },
    [pscustomobject]@{ Actions = $null; Type = 'Encoder' }
  )
}

# --- Define control pages (encoders only first) ---
Write-Host "KnobLayout: $KnobLayout"
$pageDefs = @()

$pageDefs += New-EncoderPage 'Core' @{
  '0,0' = New-DialAction 'Volume' 7
  '1,0' = New-DialAction 'Glide' 5
  '2,0' = New-DialAction 'Bend' 15
  '3,0' = New-DialAction 'Mode' 24
}

if ($KnobLayout -eq 'Maximize') {
  $pageDefs += New-EncoderPage 'Oscillator' @{
    '0,0' = New-MultiAction @(
      @{ Name = 'Sub'; CC = 26 }
      @{ Name = 'Detune'; CC = 27 }
    ) 2
    '1,0' = New-DialAction 'Reese' 28
    '2,0' = New-DialAction 'FM' 29
    '3,0' = New-FixedShapeDial 'Shape' 25
  }

  $pageDefs += New-EncoderPage 'Growl' @{
    '0,0' = New-MultiAction @(
      @{ Name = 'Growl'; CC = 12 }
      @{ Name = 'Vowel'; CC = 17 }
    ) 2
    '1,0' = New-DialAction 'Bite' 18
    '2,0' = New-DialAction 'Cutoff' 74
    '3,0' = New-DialAction 'Res' 71
  }

  $pageDefs += New-EncoderPage 'Motion' @{
    '0,0' = New-DialAction 'Free Rate' 13
    '1,0' = New-FixedStepDial 'BPM Rate' 14 10
    '2,0' = New-MultiAction @(
      @{ Name = 'Depth'; CC = 16 }
      @{ Name = 'SyncMode'; CC = 31; FixedMax = 1 }
    ) 2
    '3,0' = New-FixedShapeDial 'Shape' 30
  }

  $pageDefs += New-EncoderPage 'Output' @{
    '0,0' = New-MultiAction @(
      @{ Name = 'ShapePre'; CC = 36 }
      @{ Name = 'Drive'; CC = 19 }
    ) 2
    '1,0' = New-DialAction 'Fold' 20
    '2,0' = New-DialAction 'Crush' 21
    '3,0' = New-MultiAction @(
      @{ Name = 'Width'; CC = 22 }
      @{ Name = 'Limiter'; CC = 23 }
    ) 2
  }
} else {
  $pageDefs += New-EncoderPage 'Oscillator' @{
    '0,0' = New-MultiAction @(
      @{ Name = 'Sub'; CC = 26 }
      @{ Name = 'Detune'; CC = 27 }
      @{ Name = 'Reese'; CC = 28 }
      @{ Name = 'FM'; CC = 29 }
    ) 4
    '1,0' = New-FixedShapeDial 'Shape' 25
  }

  $pageDefs += New-EncoderPage 'Growl' @{
    '0,0' = New-MultiAction @(
      @{ Name = 'Growl'; CC = 12 }
      @{ Name = 'Vowel'; CC = 17 }
      @{ Name = 'Bite'; CC = 18 }
      @{ Name = 'Cutoff'; CC = 74 }
    ) 4
    '1,0' = New-DialAction 'Res' 71
  }

  $pageDefs += New-EncoderPage 'Motion' @{
    '0,0' = New-MultiAction @(
      @{ Name = 'Free Rate'; CC = 13 }
      @{ Name = 'BPM Rate'; CC = 14; FixedMax = 10 }
      @{ Name = 'Depth'; CC = 16 }
      @{ Name = 'SyncMode'; CC = 31; FixedMax = 1 }
    ) 4
    '1,0' = New-FixedShapeDial 'Shape' 30
  }

  $pageDefs += New-EncoderPage 'Output' @{
    '0,0' = New-MultiAction @(
      @{ Name = 'ShapePre'; CC = 36 }
      @{ Name = 'Drive'; CC = 19 }
      @{ Name = 'Fold'; CC = 20 }
      @{ Name = 'Crush'; CC = 21 }
    ) 4
    '1,0' = New-MultiAction @(
      @{ Name = 'Width'; CC = 22 }
      @{ Name = 'Limiter'; CC = 23 }
    ) 2
  }
}

$pageDefs += New-EncoderPage 'Articulation' @{
  '0,0' = New-DialAction 'Punch' 37
  '1,0' = New-DialAction 'Decay' 33
  '2,0' = New-DialAction 'Attack' 35
  '3,0' = New-DialAction 'Release' 34
}

$pageDefs += New-EncoderPage 'Performance' @{
  '0,0' = New-PitchBendDial 'Pitch'
  '1,0' = New-DialAction 'Mod' 1
}

# Attach keypad nav — each page opens its own Notes folder child
foreach ($pd in $pageDefs) {
  $pd.Controllers[0].Actions = New-NavKeypadActions $notesChildIds[$pd.Name]
}

# Dark nav icons: page number upper-left; section title stays centered on the key
$navIconDir = New-NavIconAssets $sectionNames.Count
Write-Host "Generated nav icons in $navIconDir"

# Rebuild output tree
if (Test-Path $OutRoot) { Remove-Item -Recurse -Force $OutRoot }
$profilesDir = Join-Path $OutRoot 'Profiles'
New-Item -ItemType Directory -Force -Path $profilesDir | Out-Null

$topLevelIds = @()
foreach ($pd in $pageDefs) {
  $id = $sectionIds[$pd.Name]
  $topLevelIds += $id
  $dir = Join-Path $profilesDir $id.ToUpperInvariant()
  Install-NavImagesOnPage $pd.Controllers $dir $navIconDir
  Write-PageManifest $dir $pd.Name $pd.Controllers
  Write-Host "Wrote page $($pd.Name) -> $id"

  $notesId = $notesChildIds[$pd.Name]
  $notesDir = Join-Path $profilesDir $notesId.ToUpperInvariant()
  Write-PageManifest $notesDir 'Notes' (New-NotesFolderControllers)
  Write-Host "  Notes folder child -> $notesId"
}

# Default empty page
$defaultDir = Join-Path $profilesDir $defaultId.ToUpperInvariant()
Write-PageManifest $defaultDir '' (New-EmptyControllers)

$root = [pscustomobject]@{
  AppIdentifier = 'D:\Program Files\Propellerhead\Reason 13\Reason.exe'
  Device = $deviceSrc.Device
  Name = 'Reason - Fury'
  Pages = [pscustomobject]@{
    Current = $topLevelIds[0]
    Default = $defaultId
    Pages   = @($topLevelIds)
  }
  Version = '3.0'
}

$rootJson = $root | ConvertTo-Json -Depth 20
Set-Content -Path (Join-Path $OutRoot 'manifest.json') -Value $rootJson -Encoding UTF8

Write-Host ""
Write-Host "Built profile: $OutRoot"
Write-Host "Top-level pages: $($topLevelIds.Count) (Notes folders: $($notesChildIds.Count))"

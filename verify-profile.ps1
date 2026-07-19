#Requires -Version 5.1
<#
.SYNOPSIS
  Verify Reason-Fury.sdProfile CC/label mappings and keypad navigation.

.PARAMETER KnobLayout
  Maximize (default) or Compact — must match how the profile was built.
#>
param(
  [ValidateSet('Maximize', 'Compact')]
  [string]$KnobLayout = 'Maximize'
)

$ErrorActionPreference = 'Stop'

$ProfileRoot = Join-Path $PSScriptRoot 'Reason-Fury.sdProfile'
if (-not (Test-Path $ProfileRoot)) { throw "Missing $ProfileRoot" }

$ExpectedShared = @{
  'Core' = @(
    @{ Pos = '0,0'; Kind = 'dial'; Name = 'Volume'; CC = 7 }
    @{ Pos = '1,0'; Kind = 'dial'; Name = 'Glide'; CC = 5 }
    @{ Pos = '2,0'; Kind = 'dial'; Name = 'Bend'; CC = 15 }
    @{ Pos = '3,0'; Kind = 'dial'; Name = 'Mode'; CC = 24 }
  )
  'Articulation' = @(
    @{ Pos = '0,0'; Kind = 'dial'; Name = 'Punch'; CC = 37 }
    @{ Pos = '1,0'; Kind = 'dial'; Name = 'Decay'; CC = 33 }
    @{ Pos = '2,0'; Kind = 'dial'; Name = 'Attack'; CC = 35 }
    @{ Pos = '3,0'; Kind = 'dial'; Name = 'Release'; CC = 34 }
  )
  'Performance' = @(
    @{ Pos = '0,0'; Kind = 'pitch'; Name = 'Pitch' }
    @{ Pos = '1,0'; Kind = 'dial'; Name = 'Mod'; CC = 1 }
  )
}

if ($KnobLayout -eq 'Maximize') {
  $ExpectedLayout = @{
    'Oscillator' = @(
      @{ Pos = '0,0'; Kind = 'multi'; Slots = @(
        @{ Name = 'Sub'; CC = 26 }, @{ Name = 'Detune'; CC = 27 }
      )}
      @{ Pos = '1,0'; Kind = 'dial'; Name = 'Reese'; CC = 28 }
      @{ Pos = '2,0'; Kind = 'dial'; Name = 'FM'; CC = 29 }
      @{ Pos = '3,0'; Kind = 'fixed'; Name = 'Shape'; CC = 25; MaxStep = 3 }
    )
    'Growl' = @(
      @{ Pos = '0,0'; Kind = 'multi'; Slots = @(
        @{ Name = 'Growl'; CC = 12 }, @{ Name = 'Vowel'; CC = 17 }
      )}
      @{ Pos = '1,0'; Kind = 'dial'; Name = 'Bite'; CC = 18 }
      @{ Pos = '2,0'; Kind = 'dial'; Name = 'Cutoff'; CC = 74 }
      @{ Pos = '3,0'; Kind = 'dial'; Name = 'Res'; CC = 71 }
    )
    'Motion' = @(
      @{ Pos = '0,0'; Kind = 'dial'; Name = 'Free Rate'; CC = 13 }
      @{ Pos = '1,0'; Kind = 'fixed'; Name = 'BPM Rate'; CC = 14; MaxStep = 10 }
      @{ Pos = '2,0'; Kind = 'multi'; Slots = @(
        @{ Name = 'Depth'; CC = 16 }, @{ Name = 'SyncMode'; CC = 31; FixedMax = 1 }
      )}
      @{ Pos = '3,0'; Kind = 'fixed'; Name = 'Shape'; CC = 30; MaxStep = 3 }
    )
    'Output' = @(
      @{ Pos = '0,0'; Kind = 'multi'; Slots = @(
        @{ Name = 'ShapePre'; CC = 36 }, @{ Name = 'Drive'; CC = 19 }
      )}
      @{ Pos = '1,0'; Kind = 'dial'; Name = 'Fold'; CC = 20 }
      @{ Pos = '2,0'; Kind = 'dial'; Name = 'Crush'; CC = 21 }
      @{ Pos = '3,0'; Kind = 'multi'; Slots = @(
        @{ Name = 'Width'; CC = 22 }, @{ Name = 'Limiter'; CC = 23 }
      )}
    )
  }
} else {
  $ExpectedLayout = @{
    'Oscillator' = @(
      @{ Pos = '0,0'; Kind = 'multi'; Slots = @(
        @{ Name = 'Sub'; CC = 26 }, @{ Name = 'Detune'; CC = 27 },
        @{ Name = 'Reese'; CC = 28 }, @{ Name = 'FM'; CC = 29 }
      )}
      @{ Pos = '1,0'; Kind = 'fixed'; Name = 'Shape'; CC = 25; MaxStep = 3 }
    )
    'Growl' = @(
      @{ Pos = '0,0'; Kind = 'multi'; Slots = @(
        @{ Name = 'Growl'; CC = 12 }, @{ Name = 'Vowel'; CC = 17 },
        @{ Name = 'Bite'; CC = 18 }, @{ Name = 'Cutoff'; CC = 74 }
      )}
      @{ Pos = '1,0'; Kind = 'dial'; Name = 'Res'; CC = 71 }
    )
    'Motion' = @(
      @{ Pos = '0,0'; Kind = 'multi'; Slots = @(
        @{ Name = 'Free Rate'; CC = 13 },
        @{ Name = 'BPM Rate'; CC = 14; FixedMax = 10 },
        @{ Name = 'Depth'; CC = 16 }, @{ Name = 'SyncMode'; CC = 31; FixedMax = 1 }
      )}
      @{ Pos = '1,0'; Kind = 'fixed'; Name = 'Shape'; CC = 30; MaxStep = 3 }
    )
    'Output' = @(
      @{ Pos = '0,0'; Kind = 'multi'; Slots = @(
        @{ Name = 'ShapePre'; CC = 36 }, @{ Name = 'Drive'; CC = 19 },
        @{ Name = 'Fold'; CC = 20 }, @{ Name = 'Crush'; CC = 21 }
      )}
      @{ Pos = '1,0'; Kind = 'multi'; Slots = @(
        @{ Name = 'Width'; CC = 22 }, @{ Name = 'Limiter'; CC = 23 }
      )}
    )
  }
}

$Expected = @{}
foreach ($k in $ExpectedShared.Keys) { $Expected[$k] = $ExpectedShared[$k] }
foreach ($k in $ExpectedLayout.Keys) { $Expected[$k] = $ExpectedLayout[$k] }

$NavExpected = @(
  @{ Pos = '0,0'; Title = 'Core'; PageIndex = 1 }
  @{ Pos = '1,0'; Title = 'Osc'; PageIndex = 2 }
  @{ Pos = '2,0'; Title = 'Growl'; PageIndex = 3 }
  @{ Pos = '3,0'; Title = 'Motion'; PageIndex = 4 }
  @{ Pos = '0,1'; Title = 'Out'; PageIndex = 5 }
  @{ Pos = '1,1'; Title = 'Art'; PageIndex = 6 }
  @{ Pos = '2,1'; Title = 'Perf'; PageIndex = 7 }
)

$errors = @()
$root = Get-Content (Join-Path $ProfileRoot 'manifest.json') -Raw | ConvertFrom-Json
if ($root.Name -ne 'Reason - Fury') { $errors += "Root name is '$($root.Name)'" }
if ($root.Device.Model -ne '20GBD9901') { $errors += "Device model is '$($root.Device.Model)'" }
if (@($root.Pages.Pages).Count -ne 7) {
  $errors += "Expected 7 top-level pages, got $(@($root.Pages.Pages).Count)"
}

$pagesByName = @{}
Get-ChildItem (Join-Path $ProfileRoot 'Profiles') -Directory | ForEach-Object {
  $j = Get-Content (Join-Path $_.FullName 'manifest.json') -Raw | ConvertFrom-Json
  $id = $_.Name.ToLowerInvariant()
  if ($j.Name) { $pagesByName[$j.Name] = @{ Json = $j; Id = $id } }
}

$topIds = @($root.Pages.Pages | ForEach-Object { $_.ToLowerInvariant() })
foreach ($name in $Expected.Keys) {
  if (-not $pagesByName.ContainsKey($name)) {
    $errors += "Missing page: $name"
    continue
  }
  if ($topIds -notcontains $pagesByName[$name].Id) {
    $errors += "Page $name is not in Pages.Pages"
  }
}

$notesChildren = @()
Get-ChildItem (Join-Path $ProfileRoot 'Profiles') -Directory | ForEach-Object {
  $j = Get-Content (Join-Path $_.FullName 'manifest.json') -Raw | ConvertFrom-Json
  if ($j.Name -ne 'Notes') { return }
  $id = $_.Name.ToLowerInvariant()
  if ($topIds -contains $id) {
    $errors += "Notes page $id must not be a top-level swipe page"
    return
  }
  $pad = @($j.Controllers | Where-Object { $_.Type -eq 'Keypad' })[0]
  $back = if ($pad -and $pad.Actions) { $pad.Actions.'0,0' } else { $null }
  if (-not $back -or $back.UUID -ne 'com.elgato.streamdeck.profile.backtoparent') {
    $errors += "Notes child $id missing backtoparent at 0,0"
  }
  $noteCount = @($pad.Actions.PSObject.Properties | Where-Object {
    $_.Value -is [pscustomobject] -and $_.Value.UUID -match 'noteon'
  }).Count
  if ($noteCount -lt 7) { $errors += "Notes child $id has $noteCount note pads (expected 7+)" }
  $notesChildren += $id
}
if ($notesChildren.Count -ne 7) {
  $errors += "Expected 7 per-page Notes folder children, got $($notesChildren.Count)"
}

foreach ($pageName in $Expected.Keys) {
  if (-not $pagesByName.ContainsKey($pageName)) { continue }
  $page = $pagesByName[$pageName].Json
  $enc = @($page.Controllers | Where-Object { $_.Type -eq 'Encoder' })[0]
  $pad = @($page.Controllers | Where-Object { $_.Type -eq 'Keypad' })[0]

  foreach ($exp in $Expected[$pageName]) {
    $act = $enc.Actions.($exp.Pos)
    if (-not $act) {
      $errors += "$pageName missing encoder at $($exp.Pos)"
      continue
    }
    $s = $act.Settings
    if ($exp.Kind -eq 'dial') {
      if ($s.rn1 -ne $exp.Name -or [int]$s.rcn -ne $exp.CC -or $s.rsa -ne 'CC') {
        $errors += "$pageName $($exp.Pos): expected dial $($exp.Name)/CC$($exp.CC), got $($s.rn1)/CC$($s.rcn) rsa=$($s.rsa)"
      }
    } elseif ($exp.Kind -eq 'fixed') {
      $maxStep = if ($null -ne $exp.MaxStep) { [string]$exp.MaxStep } else { '3' }
      if ($s.rn1 -ne $exp.Name -or [int]$s.rcn -ne $exp.CC -or $s.rsa -ne 'CC') {
        $errors += "$pageName $($exp.Pos): expected fixed $($exp.Name)/CC$($exp.CC), got $($s.rn1)/CC$($s.rcn)"
      }
      if ($s.a20 -ne 'Fixed' -or [string]$s.rcs -ne '1' -or [string]$s.rcm -ne '0' -or [string]$s.rcx -ne $maxStep) {
        $errors += "$pageName $($exp.Pos): expected Fixed rcs=1 rcm=0 rcx=$maxStep, got a20=$($s.a20) rcs=$($s.rcs) rcm=$($s.rcm) rcx=$($s.rcx)"
      }
    } elseif ($exp.Kind -eq 'pitch') {
      if ($s.rn1 -ne $exp.Name -or $s.rsa -ne 'PB') {
        $errors += "$pageName $($exp.Pos): expected pitch bend $($exp.Name)/PB, got $($s.rn1)/$($s.rsa)"
      }
    } elseif ($exp.Kind -eq 'multi') {
      $i = 1
      foreach ($slot in $exp.Slots) {
        if ($s."rn$i" -ne $slot.Name -or [int]$s."rcn$i" -ne $slot.CC -or $s."rsa$i" -ne 'CC') {
          $errors += ("{0} {1} slot {2}: expected {3}/CC{4}, got {5}/CC{6}" -f $pageName, $exp.Pos, $i, $slot.Name, $slot.CC, $s."rn$i", $s."rcn$i")
        }
        if ($null -ne $slot.FixedMax) {
          $fm = [string]$slot.FixedMax
          if ($s."a20_$i" -ne 'Fixed' -or [string]$s."rcs$i" -ne '1' -or [string]$s."rcm$i" -ne '0' -or [string]$s."rcx$i" -ne $fm) {
            $errors += ("{0} {1} slot {2}: expected Fixed rcs=1 rcm=0 rcx={3}, got a20={4} rcs={5} rcm={6} rcx={7}" -f `
              $pageName, $exp.Pos, $i, $fm, $s."a20_$i", $s."rcs$i", $s."rcm$i", $s."rcx$i")
          }
        }
        $i++
      }
    }
  }

  if (-not $pad -or -not $pad.Actions) {
    $errors += "$pageName missing keypad nav"
    continue
  }
  $pageDir = Join-Path $ProfileRoot "Profiles\$($pagesByName[$pageName].Id.ToUpperInvariant())"
  foreach ($nav in $NavExpected) {
    $act = $pad.Actions.($nav.Pos)
    if (-not $act -or $act.UUID -ne 'com.elgato.streamdeck.page.goto') {
      $errors += "$pageName missing page.goto at $($nav.Pos)"
      continue
    }
    $title = $act.States[0].Title
    $idx = [int]$act.Settings.PageIndex
    if ($title -ne $nav.Title -or $idx -ne $nav.PageIndex) {
      $errors += ("{0} {1}: expected {2}/PageIndex {3}, got {4}/{5}" -f $pageName, $nav.Pos, $nav.Title, $nav.PageIndex, $title, $idx)
    }
    $img = $act.States[0].Image
    if (-not $img) {
      $errors += "$pageName $($nav.Pos): missing States[0].Image for nav contrast icon"
    } elseif (-not (Test-Path (Join-Path $pageDir $img))) {
      $errors += "$pageName $($nav.Pos): Image file missing: $img"
    }
  }
  $folder = $pad.Actions.'3,1'
  if (-not $folder -or $folder.UUID -ne 'com.elgato.streamdeck.profile.openchild') {
    $errors += "$pageName missing Notes openchild at 3,1"
  } elseif ($folder.States[0].Title -ne 'Notes') {
    $errors += "$pageName Notes folder title is '$($folder.States[0].Title)'"
  } else {
    $childId = $folder.Settings.ProfileUUID.ToLowerInvariant()
    if ($notesChildren -notcontains $childId) {
      $errors += "$pageName Notes folder points to unknown child $childId"
    }
  }
}

$folderTargets = @()
foreach ($pageName in $Expected.Keys) {
  if (-not $pagesByName.ContainsKey($pageName)) { continue }
  $pad = @($pagesByName[$pageName].Json.Controllers | Where-Object { $_.Type -eq 'Keypad' })[0]
  $folder = $pad.Actions.'3,1'
  if ($folder -and $folder.Settings.ProfileUUID) {
    $folderTargets += $folder.Settings.ProfileUUID.ToLowerInvariant()
  }
}
$uniqueTargets = @($folderTargets | Select-Object -Unique)
if ($uniqueTargets.Count -ne 7) {
  $errors += "Expected 7 unique Notes folder targets, got $($uniqueTargets.Count)"
}

if ($errors.Count) {
  Write-Host "VERIFY FAILED ($($errors.Count) issues):"
  $errors | ForEach-Object { Write-Host " - $_" }
  exit 1
}

Write-Host "VERIFY OK - KnobLayout=$KnobLayout; CC mappings and keypad navigation match plan"
exit 0

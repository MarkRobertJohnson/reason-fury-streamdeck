#Requires -Version 5.1
<#
.SYNOPSIS
  Assert a ProfilesV3 profile is structurally loadable by Stream Deck.

.DESCRIPTION
  Checks root manifest has no UTF-8 BOM, Device.UUID is non-empty, and every
  lowercase page GUID in the umbrella has a matching UPPERCASE folder under Profiles\.

.PARAMETER Name
  Profile Name from umbrella manifest.json (e.g. 'Reason - Fury', 'Reason - Remote').

.PARAMETER ProfileDir
  Optional path to a .sdProfile folder (repo source or ProfilesV3). When set, -Name is ignored.
#>
param(
  [string]$Name,
  [string]$ProfileDir
)

$ErrorActionPreference = 'Stop'
$failed = $false

function Write-Fail([string]$msg) {
  Write-Host "FAIL: $msg" -ForegroundColor Red
  $script:failed = $true
}

function Write-Ok([string]$msg) {
  Write-Host "OK:   $msg" -ForegroundColor Green
}

function Test-ProfileLoadable([string]$dir) {
  $root = Join-Path $dir 'manifest.json'
  if (-not (Test-Path $root)) {
    Write-Fail "Missing umbrella manifest: $root"
    return
  }

  $bytes = [System.IO.File]::ReadAllBytes($root)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Fail "Root manifest has UTF-8 BOM (EF BB BF). Stream Deck rejects this. Rewrite without BOM."
  } else {
    Write-Ok "Root manifest has no UTF-8 BOM"
  }

  try {
    $j = Get-Content -Raw $root | ConvertFrom-Json
  } catch {
    Write-Fail "Root manifest JSON parse error: $_"
    return
  }

  if (-not $j.Device -or -not $j.Device.Model) {
    Write-Fail "Device.Model missing"
  } else {
    Write-Ok "Device.Model = $($j.Device.Model)"
  }

  if (-not $j.Device -or [string]::IsNullOrWhiteSpace([string]$j.Device.UUID)) {
    Write-Fail "Device.UUID empty - profile will not appear in the dropdown"
  } else {
    Write-Ok "Device.UUID = $($j.Device.UUID)"
  }

  $profilesRoot = Join-Path $dir 'Profiles'
  if (-not (Test-Path $profilesRoot)) {
    Write-Fail "Missing Profiles\ directory"
    return
  }

  $diskFolders = @(Get-ChildItem $profilesRoot -Directory | ForEach-Object { $_.Name })
  $ids = [System.Collections.Generic.List[string]]::new()
  foreach ($id in @($j.Pages.Pages)) {
    if ($id) { $ids.Add([string]$id) | Out-Null }
  }
  if ($j.Pages.Default) { $ids.Add([string]$j.Pages.Default) | Out-Null }
  if ($j.Pages.Current -and -not $ids.Contains([string]$j.Pages.Current)) {
    $ids.Add([string]$j.Pages.Current) | Out-Null
  }

  $uniqueIds = $ids | Select-Object -Unique
  foreach ($id in $uniqueIds) {
    $lower = $id.ToLowerInvariant()
    $upper = $id.ToUpperInvariant()
    if ($id -cne $lower) {
      Write-Fail "JSON page id is not lowercase: $id (expected $lower)"
    }
    $match = $diskFolders | Where-Object { $_ -ceq $upper }
    if (-not $match) {
      $caseInsensitive = $diskFolders | Where-Object { $_.ToUpperInvariant() -eq $upper }
      if ($caseInsensitive) {
        Write-Fail "Page folder exists but not UPPERCASE: disk='$caseInsensitive' expected='$upper' (log: no pages in umbrella)"
      } else {
        Write-Fail "Missing Profiles\$upper for JSON id $lower"
      }
    } else {
      Write-Ok "Page folder $upper matches JSON $lower"
    }
  }

  Write-Host "Profile: $($j.Name)"
  Write-Host "Path:    $dir"
}

if ($ProfileDir) {
  if (-not (Test-Path $ProfileDir)) { throw "ProfileDir not found: $ProfileDir" }
  Test-ProfileLoadable (Resolve-Path $ProfileDir).Path
} else {
  if (-not $Name) {
    throw "Specify -Name 'Reason - Fury' (or similar) or -ProfileDir path"
  }
  $profilesV3 = Join-Path $env:APPDATA 'Elgato\StreamDeck\ProfilesV3'
  if (-not (Test-Path $profilesV3)) { throw "ProfilesV3 not found: $profilesV3" }

  $hits = @()
  foreach ($dir in Get-ChildItem $profilesV3 -Directory -Filter '*.sdProfile') {
    $m = Join-Path $dir.FullName 'manifest.json'
    if (-not (Test-Path $m)) { continue }
    try {
      $n = (Get-Content -Raw $m | ConvertFrom-Json).Name
      if ($n -eq $Name) { $hits += $dir.FullName }
    } catch {}
  }

  if ($hits.Count -eq 0) { throw "No installed profile named '$Name' under $profilesV3" }
  if ($hits.Count -gt 1) {
    Write-Host "WARN: $($hits.Count) installs named '$Name'; verifying all." -ForegroundColor Yellow
  }
  foreach ($h in $hits) { Test-ProfileLoadable $h }
}

if ($failed) {
  Write-Host "`nverify-profile-load: FAILED" -ForegroundColor Red
  exit 1
}
Write-Host "`nverify-profile-load: OK" -ForegroundColor Green
exit 0

#Requires -Version 5.1
<#
.SYNOPSIS
  Shared Fury section palette + nav/strip asset helpers for Stream Deck+ profile builds.

.DESCRIPTION
  Dot-source from build-profile.ps1 / build-fury-remote-profile.ps1.
  Call New-SectionThemeAssets -AssetsRoot <dir> then Install-* helpers per page.
#>

# Section index is 1-based page order: Core … Performance
$script:SectionThemePalette = @(
  @{ Name = 'Core';          R = 214; G = 152; B = 48  }  # amber
  @{ Name = 'Oscillator';    R = 56;  G = 186; B = 196 }  # cyan
  @{ Name = 'Growl';         R = 232; G = 98;  B = 52  }  # orange-red
  @{ Name = 'Motion';        R = 156; G = 92;  B = 214 }  # violet
  @{ Name = 'Output';        R = 72;  G = 176; B = 96  }  # green
  @{ Name = 'Articulation';  R = 72;  G = 128; B = 220 }  # blue
  @{ Name = 'Performance';   R = 214; G = 72;  B = 140 }  # magenta
)

function Get-SectionThemeColor([int]$pageIndex) {
  if ($pageIndex -lt 1 -or $pageIndex -gt $script:SectionThemePalette.Count) {
    throw "Section index out of range: $pageIndex"
  }
  return $script:SectionThemePalette[$pageIndex - 1]
}

function Get-MutedSectionColor([int]$r, [int]$g, [int]$b, [double]$mix = 0.38) {
  # Blend toward dark charcoal for inactive key backgrounds
  $dr = 28; $dg = 28; $db = 30
  return @{
    R = [int][Math]::Round($dr + ($r - $dr) * $mix)
    G = [int][Math]::Round($dg + ($g - $dg) * $mix)
    B = [int][Math]::Round($db + ($b - $db) * $mix)
  }
}

function Get-ScaledColor([int]$r, [int]$g, [int]$b, [double]$scale) {
  return @{
    R = [int][Math]::Min(255, [Math]::Round($r * $scale))
    G = [int][Math]::Min(255, [Math]::Round($g * $scale))
    B = [int][Math]::Min(255, [Math]::Round($b * $scale))
  }
}

function New-NavKeyBitmap([int]$pageIndex, [int]$bgR, [int]$bgG, [int]$bgB, [int]$borderWidth = 0, [int]$borderR = 0, [int]$borderG = 0, [int]$borderB = 0) {
  Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
  $size = 144
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
  $g.Clear([System.Drawing.Color]::FromArgb(255, $bgR, $bgG, $bgB))
  if ($borderWidth -gt 0) {
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, $borderR, $borderG, $borderB)), $borderWidth
    $inset = [Math]::Ceiling($borderWidth / 2.0)
    $g.DrawRectangle($pen, $inset, $inset, $size - $borderWidth, $size - $borderWidth)
    $pen.Dispose()
  }
  $font = New-Object System.Drawing.Font 'Segoe UI', 22, ([System.Drawing.FontStyle]::Bold)
  $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 235, 235, 240))
  $g.DrawString([string]$pageIndex, $font, $brush, 8.0, 4.0)
  $font.Dispose()
  $brush.Dispose()
  $g.Dispose()
  return $bmp
}

function Save-BitmapPng($bmp, [string]$outPath) {
  $dir = Split-Path -Parent $outPath
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
}

function New-AnimatedNavGif([int]$pageIndex, [int]$baseR, [int]$baseG, [int]$baseB, [string]$outPath) {
  Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
  $frameDir = Join-Path ([System.IO.Path]::GetTempPath()) ("sd-nav-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $frameDir | Out-Null
  try {
    $frameCount = 10
    for ($i = 0; $i -lt $frameCount; $i++) {
      $t = $i / [double]$frameCount
      $wave = 0.5 + 0.5 * [Math]::Sin(2.0 * [Math]::PI * $t)
      $scale = 0.55 + 0.45 * $wave
      $c = Get-ScaledColor $baseR $baseG $baseB $scale
      $borderW = [int][Math]::Round(3 + 5 * $wave)
      $bright = Get-ScaledColor $baseR $baseG $baseB (0.85 + 0.35 * $wave)
      $bmp = New-NavKeyBitmap $pageIndex $c.R $c.G $c.B $borderW $bright.R $bright.G $bright.B
      $framePath = Join-Path $frameDir ("frame-{0:D2}.png" -f $i)
      Save-BitmapPng $bmp $framePath
      $bmp.Dispose()
    }

    $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if (-not $ffmpeg) {
      # Fallback: bright static PNG renamed as .gif is invalid — write brightest PNG instead as .png active
      throw "ffmpeg not found"
    }

    $outDir = Split-Path -Parent $outPath
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
    if (Test-Path $outPath) { Remove-Item -Force $outPath }

    $pattern = Join-Path $frameDir 'frame-%02d.png'
    $args = @(
      '-y', '-hide_banner', '-loglevel', 'error',
      '-framerate', '8',
      '-i', $pattern,
      '-loop', '0',
      '-gifflags', '+transdiff',
      $outPath
    )
    & ffmpeg @args
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outPath)) {
      throw "ffmpeg failed to create $outPath (exit $LASTEXITCODE)"
    }
  }
  finally {
    if (Test-Path $frameDir) { Remove-Item -Recurse -Force $frameDir }
  }
}

function New-StripBackgroundPng([int]$r, [int]$g, [int]$b, [string]$outPath) {
  Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
  $w = 800; $h = 100
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $gfx = [System.Drawing.Graphics]::FromImage($bmp)
  # Soft horizontal gradient: darker edges, section color center
  for ($x = 0; $x -lt $w; $x++) {
    $t = $x / [double]($w - 1)
    $edge = 1.0 - 2.0 * [Math]::Abs($t - 0.5)
    $scale = 0.35 + 0.65 * $edge
    $c = Get-ScaledColor $r $g $b $scale
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, $c.R, $c.G, $c.B))
    $gfx.DrawLine($pen, $x, 0, $x, $h)
    $pen.Dispose()
  }
  $gfx.Dispose()
  Save-BitmapPng $bmp $outPath
  $bmp.Dispose()
}

function New-SectionThemeAssets([string]$AssetsRoot) {
  $navDir = Join-Path $AssetsRoot 'nav'
  $stripDir = Join-Path $AssetsRoot 'strip'
  New-Item -ItemType Directory -Force -Path $navDir | Out-Null
  New-Item -ItemType Directory -Force -Path $stripDir | Out-Null

  $pageCount = $script:SectionThemePalette.Count
  for ($i = 1; $i -le $pageCount; $i++) {
    $col = Get-SectionThemeColor $i
    $muted = Get-MutedSectionColor $col.R $col.G $col.B 0.42
    $bmp = New-NavKeyBitmap $i $muted.R $muted.G $muted.B 0 0 0 0
    Save-BitmapPng $bmp (Join-Path $navDir "page-$i.png")
    $bmp.Dispose()

    $activeGif = Join-Path $navDir "page-$i-active.gif"
    $activePngFallback = Join-Path $navDir "page-$i-active.png"
    try {
      New-AnimatedNavGif $i $col.R $col.G $col.B $activeGif
      if (Test-Path $activePngFallback) { Remove-Item -Force $activePngFallback }
    }
    catch {
      Write-Warning "GIF generation failed for page $i ($($_.Exception.Message)); using bright static PNG"
      $bright = Get-ScaledColor $col.R $col.G $col.B 0.95
      $border = Get-ScaledColor $col.R $col.G $col.B 1.15
      $ab = New-NavKeyBitmap $i $bright.R $bright.G $bright.B 8 $border.R $border.G $border.B
      Save-BitmapPng $ab $activePngFallback
      $ab.Dispose()
      if (Test-Path $activeGif) { Remove-Item -Force $activeGif }
    }

    New-StripBackgroundPng $col.R $col.G $col.B (Join-Path $stripDir "section-$i.png")
  }

  return [pscustomobject]@{
    NavDir   = $navDir
    StripDir = $stripDir
  }
}

function Install-NavImagesOnPage($controllers, [string]$pageDir, [string]$navIconDir, [int]$currentPageIndex) {
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
    if ($idx -eq $currentPageIndex) {
      $gif = Join-Path $navIconDir "page-$idx-active.gif"
      $png = Join-Path $navIconDir "page-$idx-active.png"
      if (Test-Path $gif) {
        $src = $gif
        $ext = '.gif'
      }
      elseif (Test-Path $png) {
        $src = $png
        $ext = '.png'
      }
      else {
        $src = Join-Path $navIconDir "page-$idx.png"
        $ext = '.png'
      }
    }
    else {
      $src = Join-Path $navIconDir "page-$idx.png"
      $ext = '.png'
    }
    $fileName = ([guid]::NewGuid().ToString('N').ToUpperInvariant()) + $ext
    Copy-Item -Force $src (Join-Path $imagesDir $fileName)
    $act.States[0] | Add-Member -NotePropertyName Image -NotePropertyValue ("Images/" + $fileName) -Force
  }
}

function Install-EncoderBackground($controllers, [string]$pageDir, [string]$stripDir, [int]$pageIndex) {
  $enc = @($controllers | Where-Object { $_.Type -eq 'Encoder' })[0]
  if (-not $enc) { return }
  $imagesDir = Join-Path $pageDir 'Images'
  New-Item -ItemType Directory -Force -Path $imagesDir | Out-Null
  $src = Join-Path $stripDir "section-$pageIndex.png"
  if (-not (Test-Path $src)) { throw "Missing strip background: $src" }
  $fileName = ([guid]::NewGuid().ToString('N').ToUpperInvariant()) + '.png'
  Copy-Item -Force $src (Join-Path $imagesDir $fileName)
  $enc | Add-Member -NotePropertyName Background -NotePropertyValue ("Images/" + $fileName) -Force
}

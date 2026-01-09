$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$wxsPath = Join-Path $scriptDir "WWPTools.wxs"

# Extract version from WXS file
[xml]$wxsContent = Get-Content $wxsPath
$version = $wxsContent.Wix.Package.Version
if ($version -match '^(\d+\.\d+\.\d+)') {
    $versionTag = "v$($matches[1])"
    $msiPath = Join-Path $scriptDir "WWPTools-$versionTag.msi"
} else {
    $msiPath = Join-Path $scriptDir "WWPTools.msi"
}

$wixExe = "C:\Program Files\WiX Toolset v6.0\bin\wix.exe"
$bindPath = $scriptDir

if (-not (Test-Path $wixExe)) {
  throw "WiX not found at $wixExe"
}

# Replace banner logo with `WWPTools.ico` and right-align it (10px padding).
# Creates a backup of the original banner at WWPTools-banner.bmp.bak
$bannerPath = Join-Path $scriptDir "WWPTools-banner.bmp"
$icoPath = Join-Path $scriptDir "WWPTools.ico"
if (Test-Path $bannerPath -and Test-Path $icoPath) {
  try {
    Add-Type -AssemblyName System.Drawing
    $banner = [System.Drawing.Bitmap]::FromFile($bannerPath)
    $icon = New-Object System.Drawing.Icon $icoPath
    $iconBmp = $icon.ToBitmap()

    $W = $banner.Width; $H = $banner.Height
    # background color assumed at (0,0)
    $bgCol = $banner.GetPixel(0,0)

    # find existing content bbox (if any)
    $left = $W; $top = $H; $right = 0; $bottom = 0
    for ($x = 0; $x -lt $W; $x++) {
      for ($y = 0; $y -lt $H; $y++) {
        if (-not ($banner.GetPixel($x,$y).ToArgb() -eq $bgCol.ToArgb())) {
          if ($x -lt $left) { $left = $x }
          if ($y -lt $top) { $top = $y }
          if ($x -gt $right) { $right = $x }
          if ($y -gt $bottom) { $bottom = $y }
        }
      }
    }

    if ($right -ge $left) {
      $areaW = $right - $left + 1; $areaH = $bottom - $top + 1
    } else {
      # fallback area if banner has no content
      $areaW = [math]::Floor($W * 0.25)
      $areaH = [math]::Floor($H * 0.6)
    }

    # Determine target size for icon (fit into area, preserve aspect, limit to banner height)
    $maxW = [math]::Min($areaW, [math]::Floor($W * 0.6))
    $maxH = [math]::Min($areaH, [math]::Floor($H * 0.9))
    $scale = [math]::Min(1.0, [math]::Min($maxW / $iconBmp.Width, $maxH / $iconBmp.Height))
    if ($scale -le 0) { $scale = 1 }
    $tW = [math]::Max(1, [math]::Floor($iconBmp.Width * $scale))
    $tH = [math]::Max(1, [math]::Floor($iconBmp.Height * $scale))

    $destX = [math]::Max(0, $W - $tW - 10)  # 10px right padding
    $destY = [math]::Max(0, [math]::Floor((($H - $tH) / 2)))

    $out = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.Clear($bgCol)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    # Optionally copy any banner left-of-area content (e.g., text) - here we copy entire banner background
    # but we deliberately replace the old logo area with the icon.
    $g.DrawImage($banner, 0, 0)

    $destRect = New-Object System.Drawing.Rectangle $destX, $destY, $tW, $tH
    $g.DrawImage($iconBmp, $destRect)

    $g.Dispose()
    $banner.Dispose()
    $icon.Dispose()
    $iconBmp.Dispose()

    $bak = "${bannerPath}.bak"
    Copy-Item -Path $bannerPath -Destination $bak -Force
    $out.Save($bannerPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $out.Dispose()
    Write-Host "Banner replaced with WW+P icon and right-aligned (backup saved at $bak)"
  } catch {
    Write-Warning "Failed to replace banner image with icon: $_"
  }
} elseif (-not (Test-Path $bannerPath)) {
  Write-Host "Banner bitmap not found at $bannerPath; skipping logo replacement."
} elseif (-not (Test-Path $icoPath)) {
  Write-Host "Icon file not found at $icoPath; skipping logo replacement."
}

& $wixExe build -arch x64 -o $msiPath $wxsPath -bindpath $bindPath -ext WixToolset.Util.wixext -ext WixToolset.UI.wixext

$installer = New-Object -ComObject WindowsInstaller.Installer
$db = $installer.OpenDatabase($msiPath, 1)
$view = $db.OpenView("UPDATE `Control` SET `Width`=370 WHERE `Control`='BannerLine' OR `Control`='BottomLine'")
$view.Execute()
$db.Commit()
$view.Close()

Write-Host "MSI built and UI controls patched: $msiPath"

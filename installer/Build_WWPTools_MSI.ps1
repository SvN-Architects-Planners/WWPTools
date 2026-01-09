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

# Shift logo to the right inside the banner bitmap so the logo appears right-aligned in the installer UI.
# Creates a backup of the original banner at WWPTools-banner.bmp.bak
$bannerPath = Join-Path $scriptDir "WWPTools-banner.bmp"
if (Test-Path $bannerPath) {
  try {
    Add-Type -AssemblyName System.Drawing
    $banner = [System.Drawing.Bitmap]::FromFile($bannerPath)
    $W = $banner.Width; $H = $banner.Height
    $bgCol = $banner.GetPixel(0,0)
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
      $lw = $right - $left + 1; $lh = $bottom - $top + 1
      $out = New-Object System.Drawing.Bitmap $W, $H
      $g = [System.Drawing.Graphics]::FromImage($out)
      $bgBrush = New-Object System.Drawing.SolidBrush $bgCol
      $g.FillRectangle($bgBrush, 0, 0, $W, $H)
      $srcRect = New-Object System.Drawing.Rectangle $left, $top, $lw, $lh
      $destX = [math]::Max(0, $W - $lw - 10)  # 10px right padding
      $destY = [math]::Max(0, [math]::Floor((($H - $lh) / 2)))
      $destRect = New-Object System.Drawing.Rectangle $destX, $destY, $lw, $lh
      $g.DrawImage($banner, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
      $g.Dispose()
      $banner.Dispose()

      $bak = "${bannerPath}.bak"
      Copy-Item -Path $bannerPath -Destination $bak -Force
      $out.Save($bannerPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
      $out.Dispose()
      Write-Host "Banner processed and logo moved to right (backup saved at $bak)"
    } else {
      Write-Host "Banner appears to be blank or single-color; skipping logo alignment."
      $banner.Dispose()
    }
  } catch {
    Write-Warning "Failed to process banner image: $_"
  }
} else {
  Write-Host "Banner bitmap not found at $bannerPath; skipping logo alignment step."
}

& $wixExe build -arch x64 -o $msiPath $wxsPath -bindpath $bindPath -ext WixToolset.Util.wixext -ext WixToolset.UI.wixext

$installer = New-Object -ComObject WindowsInstaller.Installer
$db = $installer.OpenDatabase($msiPath, 1)
$view = $db.OpenView("UPDATE `Control` SET `Width`=370 WHERE `Control`='BannerLine' OR `Control`='BottomLine'")
$view.Execute()
$db.Commit()
$view.Close()

Write-Host "MSI built and UI controls patched: $msiPath"

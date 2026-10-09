# Renders report page metafiles to PNG so they can be looked at.
#   wmf2png.ps1 page.wmf out.png              whole page at 150 dpi (letter)
#   wmf2png.ps1 page.wmf out.png x y w h      a crop of that render
#   wmf2png.ps1 -Sheet out.png -Pages a.wmf,b.wmf   pages side by side
param([string]$In, [string]$Out, [int]$X = -1, [int]$Y = 0, [int]$W = 0, [int]$H = 0,
      [string]$Sheet = '', [string[]]$Pages)
Add-Type -AssemblyName System.Drawing
function Load([string]$p) { [System.Drawing.Image]::FromFile((Resolve-Path $p).Path) }
if ($Sheet) {
    $files = ($Pages -join ',') -split ','
    $imgs = $files | ForEach-Object { Load $_ }
    $pw = 560; $ph = [int](560 * $imgs[0].Height / $imgs[0].Width)
    $bmp = New-Object System.Drawing.Bitmap ($pw * $imgs.Count + 10 * ($imgs.Count + 1)), ($ph + 20)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(200, 205, 212))
    for ($i = 0; $i -lt $imgs.Count; $i++) {
        $x0 = 10 + $i * ($pw + 10)
        $g.FillRectangle([System.Drawing.Brushes]::White, $x0, 10, $pw, $ph)
        $g.DrawImage($imgs[$i], $x0, 10, $pw, $ph)
    }
    $g.Dispose(); $bmp.Save([IO.Path]::GetFullPath((Join-Path (Get-Location) $Sheet)), [System.Drawing.Imaging.ImageFormat]::Png)
    $imgs | ForEach-Object { $_.Dispose() }
    return
}
$img = Load $In
$bw = 1275; $bh = [int](1275 * $img.Height / $img.Width)
$big = New-Object System.Drawing.Bitmap $bw, $bh
$g = [System.Drawing.Graphics]::FromImage($big)
$g.Clear([System.Drawing.Color]::White); $g.DrawImage($img, 0, 0, $bw, $bh); $g.Dispose()
if ($X -ge 0) { $big = $big.Clone((New-Object System.Drawing.Rectangle $X, $Y, $W, $H), $big.PixelFormat) }
$big.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$img.Dispose()

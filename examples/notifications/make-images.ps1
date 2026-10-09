<#
    Draws the sample pictures used by the Notification Designer presets and the
    demo: images\logo.png, avatar.png, calendar.png, warning.png, hero.png,
    and the designer's app.ico. Re-run any time:  pwsh .\make-images.ps1
#>
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$out = Join-Path $here 'images'
New-Item -ItemType Directory -Force $out | Out-Null

function New-Canvas([int]$w, [int]$h) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.InterpolationMode = 'HighQualityBicubic'
    $g.Clear([System.Drawing.Color]::Transparent)
    return $bmp, $g
}
function C([string]$hex) { return [System.Drawing.ColorTranslator]::FromHtml($hex) }
function RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc($x, $y, 2*$r, 2*$r, 180, 90); $p.AddArc($x+$w-2*$r, $y, 2*$r, 2*$r, 270, 90)
    $p.AddArc($x+$w-2*$r, $y+$h-2*$r, 2*$r, 2*$r, 0, 90); $p.AddArc($x, $y+$h-2*$r, 2*$r, 2*$r, 90, 90)
    $p.CloseFigure(); return $p
}
function Center-Text($g, [string]$s, $font, $brush, [float]$x, [float]$y, [float]$w, [float]$h) {
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $g.DrawString($s, $font, $brush, (New-Object System.Drawing.RectangleF $x, $y, $w, $h), $sf)
}
function Grad($x, $y, $w, $h, $a, $b, $angle) {
    New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.RectangleF $x, $y, $w, $h), (C $a), (C $b), $angle
}

# ---- logo: a ledger mark on a slate-to-blue tile -------------------------------
$bmp, $g = New-Canvas 256 256
$g.FillPath((Grad 0 0 256 256 '#1F6FB2' '#33424F' 135), (RoundRect 8 8 240 240 48))
$white = [System.Drawing.Brushes]::White
$g.FillPath($white, (RoundRect 70 58 116 140 14))
$pen = New-Object System.Drawing.Pen (C '#1F6FB2'), 10
$pen.StartCap = 'Round'; $pen.EndCap = 'Round'
foreach ($yy in 92, 120, 148) { $g.DrawLine($pen, 92, $yy, 164, $yy) }
$g.FillEllipse((New-Object System.Drawing.SolidBrush (C '#2E7D4F')), 150, 150, 62, 62)
$tick = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 9
$tick.StartCap = 'Round'; $tick.EndCap = 'Round'; $tick.LineJoin = 'Round'
$g.DrawLines($tick, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF 165,181), (New-Object System.Drawing.PointF 177,193), (New-Object System.Drawing.PointF 198,168)))
$bmp.Save((Join-Path $out 'logo.png'), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# ---- avatar: initials on a warm gradient ---------------------------------------
$bmp, $g = New-Canvas 256 256
$g.FillEllipse((Grad 0 0 256 256 '#E0915F' '#B9573B' 120), 0, 0, 256, 256)
Center-Text $g 'AT' (New-Object System.Drawing.Font 'Segoe UI Semibold', 84, ([System.Drawing.GraphicsUnit]::Pixel)) $white 0 4 256 256
$bmp.Save((Join-Path $out 'avatar.png'), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# ---- calendar ------------------------------------------------------------------
$bmp, $g = New-Canvas 256 256
$g.FillPath((New-Object System.Drawing.SolidBrush (C '#FFFFFF')), (RoundRect 20 28 216 208 30))
$g.SetClip((RoundRect 20 28 216 208 30))
$g.FillRectangle((New-Object System.Drawing.SolidBrush (C '#B23A2E')), 20, 28, 216, 62)
$g.ResetClip()
$g.DrawPath((New-Object System.Drawing.Pen (C '#D7DCE3'), 3), (RoundRect 20 28 216 208 30))
Center-Text $g 'MAR' (New-Object System.Drawing.Font 'Segoe UI Semibold', 34, ([System.Drawing.GraphicsUnit]::Pixel)) $white 20 30 216 60
Center-Text $g '15' (New-Object System.Drawing.Font 'Segoe UI Semibold', 104, ([System.Drawing.GraphicsUnit]::Pixel)) (New-Object System.Drawing.SolidBrush (C '#1F2933')) 20 92 216 140
$bmp.Save((Join-Path $out 'calendar.png'), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# ---- warning -------------------------------------------------------------------
$bmp, $g = New-Canvas 256 256
$tri = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF 128,22), (New-Object System.Drawing.PointF 240,222), (New-Object System.Drawing.PointF 16,222))
$tp = New-Object System.Drawing.Drawing2D.GraphicsPath; $tp.AddPolygon($tri)
$g.FillPath((Grad 0 0 256 256 '#F2B33D' '#D9822B' 90), $tp)
$rp = New-Object System.Drawing.Pen (C '#D9822B'), 22; $rp.LineJoin = 'Round'; $g.DrawPath($rp, $tp)
$g.FillPath($white, (RoundRect 116 80 24 84 12))
$g.FillEllipse($white, 115, 178, 26, 26)
$bmp.Save((Join-Path $out 'warning.png'), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# ---- hero banner ---------------------------------------------------------------
$bmp, $g = New-Canvas 728 364
$g.FillRectangle((Grad 0 0 728 364 '#1F2A37' '#1F6FB2' 25), 0, 0, 728, 364)
$soft = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(28, 255, 255, 255))
$g.FillEllipse($soft, 470, -120, 420, 420); $g.FillEllipse($soft, 560, 170, 260, 260); $g.FillEllipse($soft, -90, 220, 300, 300)
# a tiny bar chart
$bars = 0.35, 0.55, 0.45, 0.72, 0.9
for ($i = 0; $i -lt $bars.Count; $i++) {
    $h = 170 * $bars[$i]
    $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(230, 255, 255, 255))), (RoundRect (470 + $i * 40) (290 - $h) 26 $h 6))
}
$g.DrawString('Version 4.2', (New-Object System.Drawing.Font 'Segoe UI Semibold', 54, ([System.Drawing.GraphicsUnit]::Pixel)), $white, 48, 120)
$g.DrawString('Faster reports  |  Dark mode  |  Dashboard', (New-Object System.Drawing.Font 'Segoe UI', 22, ([System.Drawing.GraphicsUnit]::Pixel)), (New-Object System.Drawing.SolidBrush (C '#CFD8E3')), 52, 196)
$bmp.Save((Join-Path $out 'hero.png'), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# ---- designer icon: a bell on the accent tile, as a multi-size .ico -------------
function Icon-Frame([int]$s) {
    $bmp, $g = New-Canvas $s $s
    $r = [Math]::Max(3, $s * 0.22)
    $g.FillPath((Grad 0 0 $s $s '#2A7FC6' '#1F5F9A' 90), (RoundRect 0 0 $s $s $r))
    $f = New-Object System.Drawing.Font 'Segoe Fluent Icons', ([float]($s * 0.56)), ([System.Drawing.GraphicsUnit]::Pixel)
    Center-Text $g ([string][char]0xEA8F) $f $white 0 ($s * 0.04) $s $s
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
    return ,$ms.ToArray()
}
$sizes = 16, 24, 32, 48, 64, 256
$frames = $sizes | ForEach-Object { ,(Icon-Frame $_) }
$ico = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter $ico
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]; $len = $frames[$i].Length
    $bw.Write([byte]($(if ($s -ge 256) { 0 } else { $s }))); $bw.Write([byte]($(if ($s -ge 256) { 0 } else { $s })))
    $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([UInt16]1); $bw.Write([UInt16]32)
    $bw.Write([UInt32]$len); $bw.Write([UInt32]$offset); $offset += $len
}
foreach ($f in $frames) { $bw.Write([byte[]]$f) }
$bw.Flush()
$icoPath = Join-Path $here '..\..\designer\NotificationDesigner\app.ico'
[System.IO.File]::WriteAllBytes($icoPath, $ico.ToArray())
Write-Host "images written to $out; icon to $icoPath"

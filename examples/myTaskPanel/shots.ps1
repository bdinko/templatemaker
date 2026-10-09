# shots.ps1 - every screenshot in docs/myTaskPanel-template.html, English and
# Spanish, regenerated from the demo. Run from anywhere:
#   powershell -ExecutionPolicy Bypass -File examples\myTaskPanel\shots.ps1
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$docs = Resolve-Path (Join-Path $here "..\..\docs")
Add-Type -AssemblyName System.Drawing
$park = "760,560"                       # the mouse waits in the MDI area: no stray hover

function Shot($name, $exe, $argv, $click = $park, $delay = 1800, $hover = 600) {
  foreach ($lang in @("en", "es")) {
    $a = "$argv badge=off"; $suffix = ""
    if ($lang -eq "es") { $a = "$argv badge=off lang=es"; $suffix = "-es" }
    $out = Join-Path $docs "myTaskPanel-$name$suffix.png"
    & (Join-Path $here "shoot.ps1") -Exe $exe -Argv $a -Out $out -Click $click -Delay $delay -HoverWait $hover | Out-Null
    "  $out"
  }
}

# panels cropped out of several shots, side by side, with a caption under each
function Strip($name, $items) {
  foreach ($lang in @("en", "es")) {
    $suffix = ""; if ($lang -eq "es") { $suffix = "-es" }
    $crops = @()
    foreach ($it in $items) {
      $tmp = Join-Path $env:TEMP ("mtp_" + [guid]::NewGuid().ToString("N") + ".png")
      $a = "$($it.Args) badge=off"; if ($lang -eq "es") { $a = "$a lang=es" }
      $c = $park; if ($it.Click) { $c = $it.Click }      # an item can hold the mouse on a row
      & (Join-Path $here "shoot.ps1") -Exe $it.Exe -Argv $a -Out $tmp -Click $c | Out-Null
      $src = [System.Drawing.Bitmap]::FromFile($tmp)
      $rect = New-Object System.Drawing.Rectangle 1, 86, 231, 470
      $crops += @{ Bmp = $src.Clone($rect, $src.PixelFormat); Label = $(if ($lang -eq "es") { $it.Es } else { $it.En }) }
      $src.Dispose(); Remove-Item $tmp
    }
    $gap = 14; $w = $crops.Count * 231 + ($crops.Count + 1) * $gap; $h = 470 + 2 * $gap + 26
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(255, 248, 250, 252))
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $font = New-Object System.Drawing.Font "Segoe UI", 10, ([System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 31, 41, 55))
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 216, 222, 230))
    $x = $gap
    foreach ($c in $crops) {
      $g.DrawImage($c.Bmp, $x, $gap)
      $g.DrawRectangle($pen, $x - 1, $gap - 1, 232, 471)
      $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = [System.Drawing.StringAlignment]::Center
      $g.DrawString($c.Label, $font, $brush, (New-Object System.Drawing.RectangleF $x, (470 + $gap + 6), 231, 22), $sf)
      $c.Bmp.Dispose(); $x += 231 + $gap
    }
    $out = Join-Path $docs "myTaskPanel-$name$suffix.png"
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
    "  $out"
  }
}

"hero";    Shot "hero"    "TaskPanelDemoDX.exe" "engine=dx child"
"menu";    Shot "menu"    "TaskPanelDemoDX.exe" "engine=dx open=menu dock=right"
"float";   Shot "float"   "TaskPanelDemoDX.exe" "engine=dx dock=float child theme=2"
"flyout";  Shot "flyout"  "TaskPanelDemoDX.exe" "engine=dx sub=flyout flyout" "" 2600
"window";  Shot "window"  "TaskPanelDemoDX.exe" "engine=dx win theme=4"
"engines"; Strip "engines" @(
  @{ Exe = "TaskPanelDemo.exe";   Args = "";          Click = "90,170"; En = "Clarion engine (GDI)"; Es = "Motor Clarion (GDI)" },
  @{ Exe = "TaskPanelDemoDX.exe"; Args = "engine=dx"; Click = "90,170"; En = "DirectX engine";       Es = "Motor DirectX" })
"search";  Strip "search" @(
  @{ Exe = "TaskPanelDemoDX.exe"; Args = "engine=dx open=all"; En = "Badges";           Es = "Insignias" },
  @{ Exe = "TaskPanelDemoDX.exe"; Args = "engine=dx search=co"; En = "Typing co";       Es = "Escribiendo co" },
  @{ Exe = "TaskPanelDemoDX.exe"; Args = "engine=dx keys";      En = "Keyboard (F6)";   Es = "Teclado (F6)" })
"rail";    Shot "rail"     "TaskPanelDemoDX.exe" "engine=dx rail child" "22,222"
"autohide"; Shot "autohide" "TaskPanelDemoDX.exe" "engine=dx autohide child" "3,300"
"cards";   Strip "cards" @(
  @{ Exe = "TaskPanelDemoDX.exe"; Args = "engine=dx open=today"; En = "Info cards";            Es = "Tarjetas de datos" },
  @{ Exe = "TaskPanelDemoDX.exe"; Args = "engine=dx";            En = "Favourites at the top"; Es = "Favoritos arriba" })
"hover";   Shot "hover"    "TaskPanelDemoDX.exe" "engine=dx open=first" "81,248" 1800 1400
"custom";  Strip "custom" @(
  @{ Exe = "TaskPanelDemoDX.exe"; Args = "engine=dx custom open=first"; En = "Customize: Suppliers hidden"; Es = "Personalizar: Proveedores oculto" },
  @{ Exe = "TaskPanelDemoDX.exe"; Args = "engine=dx hidden open=first"; En = "After Done";                  Es = "Después de Listo" })
"themes";  Strip "themes" @(
  @{ Exe = "TaskPanelDemoDX.exe"; Args = "engine=dx theme=1 open=first"; En = "Slate";    Es = "Pizarra" },
  @{ Exe = "TaskPanelDemoDX.exe"; Args = "engine=dx theme=2 open=first"; En = "Navy";     Es = "Marino" },
  @{ Exe = "TaskPanelDemoDX.exe"; Args = "engine=dx theme=3 open=first"; En = "Graphite"; Es = "Grafito" },
  @{ Exe = "TaskPanelDemoDX.exe"; Args = "engine=dx theme=4 open=first"; En = "Teal";     Es = "Verde azulado" },
  @{ Exe = "TaskPanelDemoDX.exe"; Args = "engine=dx theme=5 open=first"; En = "Light";    Es = "Claro" },
  @{ Exe = "TaskPanelDemoDX.exe"; Args = "engine=dx theme=6 open=first"; En = "Forest";   Es = "Bosque" })

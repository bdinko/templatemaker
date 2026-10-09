<#
    Screenshots of REAL Windows notifications for the documentation.

    For each design: photograph the bottom-right corner of the screen, run
    NotifyDemo.exe /shot=<name> [es], photograph it again, and keep only the
    pixels that changed - the notification itself, cropped, with transparent
    rounded corners and none of the desktop behind it. No window is clicked
    or typed into; the demo shows the notification by itself.

    Usage:  powershell -File .\shoot.ps1 [-Only invoice,chat] [-Langs en,es]
    Output: ..\..\docs\notifications-<name>.png and -<name>-es.png
    Tip: close other notifications first; Windows queues them one at a time.
#>
param(
    [string[]]$Only = @('invoice', 'chat', 'reminder', 'hero', 'urgent', 'progress', 'quick'),
    [string[]]$Langs = @('en', 'es')
)
$ErrorActionPreference = 'Stop'
$Only = $Only -split ','; $Langs = $Langs -split ','     # also accept "a,b" from powershell -File
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class ToastCrop {
    static byte[] Bytes(Bitmap b, out int stride) {
        var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        stride = d.Stride; var a = new byte[stride * b.Height]; Marshal.Copy(d.Scan0, a, 0, a.Length); b.UnlockBits(d); return a;
    }
    // A notification replaces most of a band at the right edge of the screen;
    // anything else that moves (a terminal, a clock) changes only scattered
    // pixels. Rows where more than half the band changed are the notification;
    // take the longest run of them, then trim the columns the same way.
    public static Bitmap Diff(Bitmap before, Bitmap after, int threshold) {
        int s; var x0 = Bytes(before, out s); var x1 = Bytes(after, out s);
        int w = after.Width, h = after.Height, band0 = Math.Max(0, w - 400);
        Func<int, int, bool> changed = (x, y) => { int i = y * s + x * 4;
            return Math.Abs(x0[i] - x1[i]) + Math.Abs(x0[i + 1] - x1[i + 1]) + Math.Abs(x0[i + 2] - x1[i + 2]) > threshold; };
        int bestTop = -1, bestLen = 0, runTop = -1;
        for (int y = 0; y <= h; y++) {
            bool row = false;
            if (y < h) { int n = 0; for (int x = band0; x < w; x++) if (changed(x, y)) n++; row = n > (w - band0) / 2; }
            if (row && runTop < 0) runTop = y;
            if (!row && runTop >= 0) { if (y - runTop > bestLen) { bestLen = y - runTop; bestTop = runTop; } runTop = -1; }
        }
        if (bestLen < 40) return null;
        int left = w, right = -1;
        for (int x = 0; x < w; x++) { int n = 0; for (int y = bestTop; y < bestTop + bestLen; y++) if (changed(x, y)) n++;
            if (n > bestLen / 2) { if (x < left) left = x; right = x; } }
        if (right < 0) return null;
        // the drop shadow below and beside the card changes the desktop only a
        // little: trim bottom rows and side columns while the change is weak
        Func<int, int, bool> strong = (x, y) => { int i = y * s + x * 4;
            return Math.Abs(x0[i] - x1[i]) + Math.Abs(x0[i + 1] - x1[i + 1]) + Math.Abs(x0[i + 2] - x1[i + 2]) > 60; };
        int bottom = bestTop + bestLen - 1;
        Func<int, bool> weakRow = y => { int n = 0; for (int x = left; x <= right; x++) if (strong(x, y)) n++; return n < (right - left + 1) * 4 / 10; };
        Func<int, bool> weakCol = x => { int n = 0; for (int y = bestTop; y <= bottom; y++) if (strong(x, y)) n++; return n < (bottom - bestTop + 1) * 4 / 10; };
        while (bottom > bestTop + 40 && weakRow(bottom)) bottom--;
        while (right > left + 40 && weakCol(right)) right--;
        while (left < right - 40 && weakCol(left)) left++;
        bottom -= 3; right -= 1;                      // the card's own 1px edge sits on the shadow: shave it
        var rect = new Rectangle(left, bestTop, right - left + 1, bottom - bestTop + 1);
        var outB = new Bitmap(rect.Width, rect.Height, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(outB)) {
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            var path = new System.Drawing.Drawing2D.GraphicsPath(); float r = 16;
            path.AddArc(0, 0, r, r, 180, 90); path.AddArc(rect.Width - r - 1, 0, r, r, 270, 90);
            path.AddArc(rect.Width - r - 1, rect.Height - r - 1, r, r, 0, 90); path.AddArc(0, rect.Height - r - 1, r, r, 90, 90); path.CloseFigure();
            using (var tb = new TextureBrush(after.Clone(rect, PixelFormat.Format32bppArgb))) g.FillPath(tb, path);
        }
        return outB;
    }
}
'@

$here = $PSScriptRoot
$docs = Join-Path $here '..\..\docs'
$env:PATH = "C:\clarion12\bin;$env:PATH"
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$area = $screen.WorkingArea                       # above the taskbar
$W = 560; $H = 820
function Grab {
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($area.Right - $W, $area.Bottom - $H, 0, 0, $bmp.Size)
    $g.Dispose(); return $bmp
}

foreach ($lang in $Langs) {
    foreach ($name in $Only) {
      $suffix = if ($lang -eq 'es') { '-es' } else { '' }
      $out = Join-Path $docs "notifications-$name$suffix.png"
      foreach ($attempt in 1, 2) {
        $before = Grab
        $args = @("/shot=$name"); if ($lang -eq 'es') { $args += 'es' }
        $p = Start-Process -FilePath (Join-Path $here 'NotifyDemo.exe') -ArgumentList $args -WorkingDirectory $here -PassThru
        Start-Sleep -Milliseconds $(if ($name -eq 'progress') { 4200 } else { 2400 })
        $after = Grab
        $crop = [ToastCrop]::Diff($before, $after, 30)
        if ($crop) { $crop.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); "{0,-28} {1}x{2}" -f (Split-Path $out -Leaf), $crop.Width, $crop.Height }
        else { "{0,-28} not found (attempt {1})" -f (Split-Path $out -Leaf), $attempt }
        $p.WaitForExit(15000) | Out-Null
        Start-Sleep -Milliseconds 1200               # let the pop-up slide away before the next "before"
        if ($crop) { break }
      }
    }
}

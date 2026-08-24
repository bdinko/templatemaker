# Grab a PNG of a running window.
#   powershell -NoProfile -File shot.ps1 -Proc Spike -Out spike.png
#
# -Frag picks a particular top-level window of the process by a fragment of its
# title (the drop-down calendar is a window of its own, so it needs naming);
# with no -Frag we take the process's main window.
param([string]$Proc, [string]$Out = "shot.png", [string]$Frag = "", [int]$Wait = 1500)

Add-Type -AssemblyName System.Drawing
$src = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class Snap {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int m);
  public delegate bool EP(IntPtr h, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public static uint target;
  public static List<IntPtr> hits = new List<IntPtr>();
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowTextW(h, sb, 512); return sb.ToString(); }
  public static void Scan() {
    hits.Clear();
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint pid = 0; GetWindowThreadProcessId(h, out pid);
      if (pid == target && IsWindowVisible(h)) hits.Add(h);
      return true;
    }, IntPtr.Zero);
  }
}
'@
Add-Type -TypeDefinition $src

Start-Sleep -Milliseconds $Wait

$p = Get-Process -Name $Proc -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { throw "process '$Proc' is not running" }
Write-Host ("pid={0} main=0x{1:X}" -f $p.Id, [int64]$p.MainWindowHandle)

[Snap]::target = [uint32]$p.Id
[Snap]::Scan()
Write-Host ("enumerated {0} visible window(s):" -f [Snap]::hits.Count)
foreach ($h in [Snap]::hits) { Write-Host ("   0x{0:X}  '{1}'" -f [int64]$h, [Snap]::Title($h)) }

$hwnd = [IntPtr]::Zero
if ($Frag -ne "") {
  foreach ($h in [Snap]::hits) { if ([Snap]::Title($h) -like "*$Frag*") { $hwnd = $h; break } }
} else {
  $hwnd = $p.MainWindowHandle
  if ($hwnd -eq [IntPtr]::Zero -and [Snap]::hits.Count -gt 0) { $hwnd = [Snap]::hits[0] }
}
if ($hwnd -eq [IntPtr]::Zero) { throw "no window found (Frag='$Frag')" }

$r = New-Object Snap+RECT
[void][Snap]::GetWindowRect($hwnd, [ref]$r)
$w = $r.R - $r.L; $h2 = $r.B - $r.T
if ($w -le 0 -or $h2 -le 0) { throw "window has no size ($w x $h2)" }

$bmp = New-Object System.Drawing.Bitmap $w, $h2
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
# flag 2 = PW_RENDERFULLCONTENT, which is what makes native child controls
# (our month calendar among them) actually appear in the capture
[void][Snap]::PrintWindow($hwnd, $hdc, 2)
$g.ReleaseHdc($hdc)
$bmp.Save((Join-Path (Get-Location) $Out), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host ("saved {0} ({1}x{2})" -f $Out, $w, $h2)

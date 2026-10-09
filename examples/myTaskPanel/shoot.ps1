# shoot.ps1 - start the demo with some arguments, photograph its window from the
# screen, close it.  Screen capture on purpose: PrintWindow renders child
# windows even when the parent is painting over them, which hides exactly the
# kind of bug a docked panel can have.
#   .\shoot.ps1 -Exe TaskPanelDemoDX.exe -Argv "engine=dx" -Out ..\..\docs\x.png
param(
  [string]$Exe = "TaskPanelDemo.exe",
  [string]$Argv = "",
  [Parameter(Mandatory=$true)][string]$Out,
  [int]$Delay = 1800,
  [string]$Click = "",         # optional "x,y" in window coords: hover there before the shot
  [int]$HoverWait = 600        # how long the mouse rests there first (a description card needs ~1200)
)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class W {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s);
}
"@
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:PATH = "C:\clarion12\bin;" + $env:PATH
if ($Argv) { $p = Start-Process -FilePath (Join-Path $here $Exe) -ArgumentList $Argv -WorkingDirectory $here -PassThru }
else { $p = Start-Process -FilePath (Join-Path $here $Exe) -WorkingDirectory $here -PassThru }
$h = [IntPtr]::Zero
for ($i = 0; $i -lt 50 -and $h -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh(); if ($p.MainWindowTitle) { $h = $p.MainWindowHandle } }   # a titled window: not a pop-out
Start-Sleep -Milliseconds $Delay
$r = New-Object W+RECT
[void][W]::DwmGetWindowAttribute($h, 9, [ref]$r, 16)      # DWMWA_EXTENDED_FRAME_BOUNDS: no shadow
if ($Click) {
  $xy = $Click.Split(',')
  [void][W]::SetCursorPos($r.L + [int]$xy[0], $r.T + [int]$xy[1])
  Start-Sleep -Milliseconds $HoverWait
}
$w = $r.R - $r.L; $hh = $r.B - $r.T
$bmp = New-Object System.Drawing.Bitmap $w, $hh
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, (New-Object System.Drawing.Size $w, $hh))
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
[void][W]::PostMessage($h, 0x10, [IntPtr]::Zero, [IntPtr]::Zero)   # WM_CLOSE
if (-not $p.WaitForExit(5000)) { "did not exit - killing"; $p.Kill() } else { "exit " + $p.ExitCode }
"saved $Out ($w x $hh)"

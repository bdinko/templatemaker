# Starts Spike.exe, waits, and photographs its window FROM THE SCREEN.
# (PrintWindow would hide a hosted control that is being painted over - see
#  the comlessCalendar notes - so this is a real screen capture.)
#   shot.ps1 -Out editor.png [-Arg PAGE] [-Wait 2500] [-Keep]
param([string]$Out = "editor.png", [string]$Arg = "", [int]$Wait = 2500, [switch]$Keep,
      [int]$Width = 0, [int]$Height = 0)
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public class W32 {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
'@
$env:PATH = "C:\clarion12\bin;" + $env:PATH
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Get-Process Spike -ErrorAction SilentlyContinue | Stop-Process -Force
if ($Arg) { $p = Start-Process -FilePath "$here\Spike.exe" -ArgumentList $Arg -WorkingDirectory $here -PassThru }
else       { $p = Start-Process -FilePath "$here\Spike.exe" -WorkingDirectory $here -PassThru }
$h = [IntPtr]::Zero
for ($i = 0; $i -lt 40 -and $h -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 250; $p.Refresh(); $h = $p.MainWindowHandle }
if ($h -eq [IntPtr]::Zero) { throw "no window" }
if ($Width -gt 0) { [void][W32]::MoveWindow($h, 60, 40, $Width, $Height, $true) }
[void][W32]::SetForegroundWindow($h)
Start-Sleep -Milliseconds $Wait
$r = New-Object W32+RECT
[void][W32]::GetWindowRect($h, [ref]$r)
$bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
$g.Dispose()
$bmp.Save((Join-Path $here $Out), [System.Drawing.Imaging.ImageFormat]::Png)
if (-not $Keep) { Stop-Process -Id $p.Id -Force }
"saved $Out ($($r.R - $r.L)x$($r.B - $r.T))"

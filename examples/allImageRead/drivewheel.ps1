Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class W {
  [DllImport("user32.dll", CharSet=CharSet.Auto)]
  public static extern IntPtr FindWindow(string cls, string title);
  [DllImport("user32.dll", CharSet=CharSet.Auto)]
  public static extern int GetWindowText(IntPtr h, StringBuilder s, int max);
  [DllImport("user32.dll", CharSet=CharSet.Auto)]
  public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
}
"@

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:PATH = "C:\clarion12\bin;$env:PATH"
$p = Start-Process -FilePath (Join-Path $dir 'wheeltest.exe') -PassThru
Start-Sleep -Milliseconds 1500

$p.Refresh()
$h = $p.MainWindowHandle
if ($h -eq [IntPtr]::Zero) { $h = [W]::FindWindow($null,'AirWheelTest') }
if ($h -eq [IntPtr]::Zero) { 'FAIL: window not found'; $p.Kill(); exit 1 }
"window handle: $h"

# WM_MOUSEWHEEL = 0x020A.  wParam = (delta << 16) | keyflags ; MK_CONTROL = 0x0008
$WM_MOUSEWHEEL = 0x020A
function Send-Wheel([int]$delta, [int]$keys) {
  $d = $delta; if ($d -lt 0) { $d = 65536 + $d }
  $wp = [IntPtr](([int64]$d -shl 16) -bor $keys)
  [void][W]::SendMessage($h, $WM_MOUSEWHEEL, $wp, [IntPtr]0)
}

Send-Wheel  120 0x0008      # one notch up, Ctrl held
Send-Wheel  120 0x0008
Send-Wheel -120 0x0008      # one notch down, Ctrl held
Send-Wheel  120 0x0000      # a notch with no Ctrl
Send-Wheel -120 0x0000      # and one down with no Ctrl
Start-Sleep -Milliseconds 900

$sb = New-Object Text.StringBuilder 256
[void][W]::GetWindowText($h, $sb, 256)
"title now: " + $sb.ToString()
$p.Kill()

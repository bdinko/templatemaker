param([string]$Exe, [string]$Prefix, [string]$Out, [int]$WaitSeconds = 3)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;using System.Runtime.InteropServices;using System.Text;
public class Shooter {
 public delegate bool EnumProc(IntPtr h, IntPtr l);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
 [DllImport("user32.dll",CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int m);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 public struct RECT { public int L,T,R,B; }
 public static IntPtr Win(uint want, string prefix){ IntPtr f=IntPtr.Zero;
   EnumWindows((h,l)=>{uint pid;GetWindowThreadProcessId(h,out pid);
     if(pid==want){var t=new StringBuilder(300);GetWindowText(h,t,300);
       if(t.ToString().StartsWith(prefix)){f=h;return false;}} return true;},IntPtr.Zero); return f;}
 public static string Title(IntPtr h){var t=new StringBuilder(300);GetWindowText(h,t,300);return t.ToString();}
}
"@ -ErrorAction SilentlyContinue

Set-Location $PSScriptRoot
$env:PATH = "C:\clarion12\bin;$env:PATH"
$p = Start-Process $Exe -PassThru
Start-Sleep -Seconds $WaitSeconds
$h = [Shooter]::Win([uint32]$p.Id, $Prefix)
if ($h -eq [IntPtr]::Zero) { "window not found"; if (-not $p.HasExited) { $p.Kill() }; exit 1 }
"title: " + [Shooter]::Title($h)
[void][Shooter]::SetForegroundWindow($h)
Start-Sleep -Milliseconds 900
$r = New-Object Shooter+RECT
[void][Shooter]::GetWindowRect($h, [ref]$r)
$bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
$bmp.Save((Join-Path $PSScriptRoot $Out), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"saved $Out"
if (-not $p.HasExited) { $p.Kill() }

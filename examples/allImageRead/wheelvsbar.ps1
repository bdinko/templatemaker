# Does a mouse wheel over a region carrying WS_VSCROLL turn into a scroll
# message? If it does, zooming with the wheel also moves the scrollbar, and the
# canvas jumps to somewhere nobody panned to.
Add-Type @"
using System;using System.Runtime.InteropServices;using System.Text;
public class WB {
 public delegate bool EnumProc(IntPtr h, IntPtr l);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
 [DllImport("user32.dll",CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int m);
 [DllImport("user32.dll")] public static extern IntPtr PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 public static IntPtr Win(uint want,string prefix){ IntPtr f=IntPtr.Zero;
   EnumWindows((h,l)=>{uint pid;GetWindowThreadProcessId(h,out pid);
     if(pid==want){var t=new StringBuilder(300);GetWindowText(h,t,300);
       if(t.ToString().StartsWith(prefix)){f=h;return false;}} return true;},IntPtr.Zero); return f;}
 public static string Title(IntPtr h){var t=new StringBuilder(300);GetWindowText(h,t,300);return t.ToString();}
}
"@ -ErrorAction SilentlyContinue

Set-Location $PSScriptRoot
$env:PATH = "C:\clarion12\bin;$env:PATH"
$p = Start-Process .\bartest.exe -PassThru
Start-Sleep -Seconds 3
$h = [WB]::Win([uint32]$p.Id, "BarTest")
$t = [WB]::Title($h)
"start          : $t"
$rgn = [int](($t -split 'hwnd=')[1] -split ' ')[0]

# WM_MOUSEWHEEL, plain: wParam high word = delta
$wp = [IntPtr]([int64]120 -shl 16)
for ($i = 0; $i -lt 3; $i++) { [void][WB]::SendMessage([IntPtr]$rgn, 0x020A, $wp, [IntPtr]0) }
Start-Sleep -Seconds 1
"after 3 wheels : " + [WB]::Title($h)

# and with Ctrl held (MK_CONTROL = 8), which is how the canvas zooms
$wp2 = [IntPtr](([int64]120 -shl 16) -bor 8)
for ($i = 0; $i -lt 3; $i++) { [void][WB]::SendMessage([IntPtr]$rgn, 0x020A, $wp2, [IntPtr]0) }
Start-Sleep -Seconds 1
"after 3 ctrl+w : " + [WB]::Title($h)

if (-not $p.HasExited) { $p.Kill() }

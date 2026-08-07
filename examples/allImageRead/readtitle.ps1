param([string]$Exe, [string]$Prefix, [int]$MaxSeconds = 180)
Add-Type @"
using System;using System.Runtime.InteropServices;using System.Text;
public class TitleReader {
 public delegate bool EnumProc(IntPtr h, IntPtr l);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
 [DllImport("user32.dll",CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int m);
 public static string Title(uint want, string prefix){ string r="";
   EnumWindows((h,l)=>{uint pid;GetWindowThreadProcessId(h,out pid);
     if(pid==want){var t=new StringBuilder(600);GetWindowText(h,t,600);
       if(t.ToString().StartsWith(prefix)){r=t.ToString();return false;}} return true;},IntPtr.Zero);
   return r;}
}
"@ -ErrorAction SilentlyContinue

$env:PATH = "C:\clarion12\bin;$env:PATH"
$p = Start-Process $Exe -PassThru
$seen = ""
for ($i = 0; $i -lt $MaxSeconds; $i += 3) {
  Start-Sleep -Seconds 3
  $t = [TitleReader]::Title([uint32]$p.Id, $Prefix)
  if ($t) { $seen = $t }
  if ($t -and $t -ne $Prefix) { break }
  if ($p.HasExited) { break }
}
"waited ${i}s"
$seen
if (-not $p.HasExited) { $p.Kill() }

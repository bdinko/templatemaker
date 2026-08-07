param([string[]]$Set = @())
# Patch airwin.txa prompts, regenerate, rebuild, run, and say whether the app
# came up clean or threw. Usage:  .\try.ps1 "%airCDisable LONG  (1)","..."
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$txa = Get-Content airwin.txa
foreach ($s in $Set) {
  $name = ($s -split ' ')[0]
  $txa = $txa | ForEach-Object { if ($_ -match "^\s*$([regex]::Escape($name))\s") { $s } else { $_ } }
}
$txa | Set-Content airwin.txa

Remove-Item airwin.app -EA SilentlyContinue
& "C:\clarion12\bin\ClarionCL.exe" -win -au -ai airwin.app airwin.txa 2>&1 | Select-String "error" | ForEach-Object { "IMPORT: $_" }
& "C:\clarion12\bin\ClarionCL.exe" -win -au -ag airwin.app 2>&1 | Select-String " error" | ForEach-Object { "GEN: $_" }
$b = & "C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe" airwin.cwproj /p:ClarionBinPath="C:\clarion12\bin" /p:Configuration=Debug /nologo /v:minimal 2>&1 | Select-String "error"
if ($b) { $b | Select-Object -First 3 | ForEach-Object { "BUILD: $_" }; exit 1 }

Add-Type @"
using System;using System.Runtime.InteropServices;using System.Text;
public class TW {
 public delegate bool EnumProc(IntPtr h, IntPtr l);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
 [DllImport("user32.dll",CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int m);
 public static string Titles(uint want){ var sb=new StringBuilder();
   EnumWindows((h,l)=>{uint pid;GetWindowThreadProcessId(h,out pid);
     if(pid==want){var t=new StringBuilder(256);GetWindowText(h,t,256);
       if(t.Length>0) sb.Append("["+t+"]");} return true;},IntPtr.Zero);
   return sb.ToString(); }
}
"@ -EA SilentlyContinue

$env:PATH = "C:\clarion12\bin;$env:PATH"
$p = Start-Process .\airwin.exe -PassThru
Start-Sleep -Seconds 3
$titles = [TW]::Titles([uint32]$p.Id)
if (-not $p.HasExited) { $p.Kill() }
if ($titles -match 'Exception') { "RESULT: THREW   $titles" } else { "RESULT: CLEAN   $titles" }

# Posts real key messages through Spike's message queue (so Clarion's ACCEPT
# loop sees them exactly as typing), then closes the window.
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public class K {
  [DllImport("user32.dll")] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string t);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
}
'@
$env:PATH = "C:\clarion12\bin;" + $env:PATH
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Remove-Item "$here\Docs.tps" -ErrorAction SilentlyContinue
$p = Start-Process -FilePath "$here\Spike.exe" -WorkingDirectory $here -PassThru
$h = [IntPtr]::Zero
for ($i = 0; $i -lt 40 -and $h -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 250; $p.Refresh(); $h = $p.MainWindowHandle }
Start-Sleep -Milliseconds 800
$host_ = [K]::FindWindowEx($h, [IntPtr]::Zero, "myWordDocHost", $null)
$edit = [K]::FindWindowEx($host_, [IntPtr]::Zero, "RICHEDIT50W", $null)
"host=$host_ edit=$edit"
foreach ($vk in 0x48, 0x49, 0x09, 0x58, 0x0D, 0x59) {     # H I Tab X Enter Y
  [void][K]::PostMessage($edit, 0x0100, [IntPtr]$vk, [IntPtr]1)
  [void][K]::PostMessage($edit, 0x0101, [IntPtr]$vk, [IntPtr]0xC0000001)
  Start-Sleep -Milliseconds 120
}
Start-Sleep -Milliseconds 500
[void][K]::PostMessage($h, 0x0010, [IntPtr]0, [IntPtr]0)   # WM_CLOSE
$p.WaitForExit(5000) | Out-Null

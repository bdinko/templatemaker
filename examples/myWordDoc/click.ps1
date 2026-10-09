# Starts Spike CLICK (document fully selected), clicks the toolbar's Italic
# button by posting mouse messages to the host, then photographs the screen.
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public class C {
  [DllImport("user32.dll")] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string t);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool r);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
'@
$env:PATH = "C:\clarion12\bin;" + $env:PATH
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Remove-Item "$here\Docs.tps" -ErrorAction SilentlyContinue
$p = Start-Process -FilePath "$here\Spike.exe" -ArgumentList CLICK -WorkingDirectory $here -PassThru
$h = [IntPtr]::Zero
for ($i = 0; $i -lt 40 -and $h -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 250; $p.Refresh(); $h = $p.MainWindowHandle }
[void][C]::MoveWindow($h, 60, 40, 1100, 760, $true)
Start-Sleep -Milliseconds 800
$hst = [C]::FindWindowEx($h, [IntPtr]::Zero, "myWordDocHost", $null)
$lp = [IntPtr](16 * 65536 + 263)          # Italic button centre (x=263, y=16)
[void][C]::PostMessage($hst, 0x0201, [IntPtr]1, $lp)
[void][C]::PostMessage($hst, 0x0202, [IntPtr]0, $lp)
Start-Sleep -Milliseconds 1200
$r = New-Object C+RECT; [void][C]::GetWindowRect($h, [ref]$r)
$bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size); $g.Dispose()
$bmp.Save("$here\click_italic.png")
[void][C]::PostMessage($h, 0x0010, [IntPtr]0, [IntPtr]0)
$p.WaitForExit(5000) | Out-Null

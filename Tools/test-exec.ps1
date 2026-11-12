# exec-channel test: writes System\panel-batch.txt (PathPing), opens the console
# (diagnostic build = VISIBLE), types "exec panel-batch", Enter, screenshots the
# terminal so the console's response text is visible. ASCII only.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Add-Type -Path (Join-Path $root "Panel\cache\GameCtl.dll") | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices;
public class TF2 {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowW(string c, IntPtr t);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}' | Out-Null
[TF2]::SetProcessDPIAware() | Out-Null

$proc = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
if ( $proc -eq $null ) { Write-Output "NO GAME"; exit 1 }
$h = [TF2]::FindWindowW("GameUnrealWWindowsViewportWindow", [IntPtr]::Zero)
if ( $h -eq [IntPtr]::Zero ) { Write-Output "NO VIEWPORT"; exit 1 }
[TF2]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 60
[TF2]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 60
[TF2]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 400
if ( [TF2]::GetForegroundWindow() -ne $h ) { Write-Output "FOCUS FAILED"; exit 1 }

[System.IO.File]::WriteAllText('F:\Harry Potter and the Chamber of Secrets\System\panel-batch.txt', "PathPing`r`n")

# ensure-open: Shift down -> 250ms -> grave -> 150ms -> shift up -> 120ms
[TF2]::keybd_event(0x10, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 250
[TF2]::keybd_event(0xC0, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 40
[TF2]::keybd_event(0xC0, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 150
[TF2]::keybd_event(0x10, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 120

foreach ( $ch in 'exec panel-batch'.ToCharArray() ) {
    [GameCtl]::TapChar($ch)
    Start-Sleep -Milliseconds 20
}
Start-Sleep -Milliseconds 230
[TF2]::keybd_event(0x0D, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 40
[TF2]::keybd_event(0x0D, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 350

$b = New-Object System.Drawing.Bitmap 3840,2160
$g = [System.Drawing.Graphics]::FromImage($b)
$g.CopyFromScreen(0,0,0,0,$b.Size)
$b2 = New-Object System.Drawing.Bitmap 1920,1080
$g2 = [System.Drawing.Graphics]::FromImage($b2)
$g2.InterpolationMode = 'NearestNeighbor'
$g2.DrawImage($b, 0, 0, 1920, 1080)
$b2.Save('C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\exec-state.png')
Write-Output "exec sent, shot saved"

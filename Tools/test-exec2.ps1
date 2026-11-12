# Clean exec test: console is ALREADY OPEN (left by the previous probe) - type only.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Add-Type -Path (Join-Path $root "Panel\cache\GameCtl.dll") | Out-Null
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices;
public class TF3 {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowW(string c, IntPtr t);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}' | Out-Null
[TF3]::SetProcessDPIAware() | Out-Null

$proc = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
if ( $proc -eq $null ) { Write-Output "NO GAME"; exit 1 }
$h = [TF3]::FindWindowW("GameUnrealWWindowsViewportWindow", [IntPtr]::Zero)
if ( $h -eq [IntPtr]::Zero ) { Write-Output "NO VIEWPORT"; exit 1 }
[TF3]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 60
[TF3]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 60
[TF3]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 400
if ( [TF3]::GetForegroundWindow() -ne $h ) { Write-Output "FOCUS FAILED"; exit 1 }

foreach ( $ch in 'exec panel-batch'.ToCharArray() ) {
    [GameCtl]::TapChar($ch)
    Start-Sleep -Milliseconds 20
}
Start-Sleep -Milliseconds 230
[TF3]::keybd_event(0x0D, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 40
[TF3]::keybd_event(0x0D, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 600
Write-Output "exec typed (console was already open)"

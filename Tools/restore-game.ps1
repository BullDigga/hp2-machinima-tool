# Restore (unminimize) the game window and bring it up. ASCII only.
param([int]$Mode = 9)  # 9 = SW_RESTORE
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class RGW {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowW(string c, IntPtr t);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
}
'@ | Out-Null
$h = [RGW]::FindWindowW("GameUnrealWWindowsViewportWindow", [IntPtr]::Zero)
if ( $h -eq [IntPtr]::Zero ) { Write-Output "NO VIEWPORT"; exit 1 }
[RGW]::ShowWindow($h, $Mode) | Out-Null
Start-Sleep -Milliseconds 300
[RGW]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 50
[RGW]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
[RGW]::SetForegroundWindow($h) | Out-Null
Write-Output ("restored " + $h)

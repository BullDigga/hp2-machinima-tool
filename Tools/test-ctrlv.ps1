# Channel probe v2: Ctrl+V delivers PathPing; screenshot taken right after Enter
# so the console state is visible. ASCII only.
param([string]$Shot = "")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Add-Type -Path (Join-Path $root "Panel\cache\GameCtl.dll") | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices;
public class TF {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowW(string c, IntPtr t);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}' | Out-Null
[TF]::SetProcessDPIAware() | Out-Null

$proc = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
if ( $proc -eq $null ) { Write-Output "NO GAME"; exit 1 }
$h = [TF]::FindWindowW("GameUnrealWWindowsViewportWindow", [IntPtr]::Zero)
if ( $h -eq [IntPtr]::Zero ) { Write-Output "NO VIEWPORT"; exit 1 }
[TF]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 60
[TF]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 60
[TF]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 400
if ( [TF]::GetForegroundWindow() -ne $h ) { Write-Output "FOCUS FAILED"; exit 1 }

function Open-Console {
    [TF]::keybd_event(0x10, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [TF]::keybd_event(0xC0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [TF]::keybd_event(0xC0, 0, 2, [UIntPtr]::Zero)
    [TF]::keybd_event(0x10, 0, 2, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 600
}
function Press-Key([byte]$vk) {
    [TF]::keybd_event($vk, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 30
    [TF]::keybd_event($vk, 0, 2, [UIntPtr]::Zero)
}

Write-Output "== Ctrl+V probe with screenshot =="
Open-Console
Set-Clipboard -Value 'PathPing'
Start-Sleep -Milliseconds 150
[TF]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 40
Press-Key 0x56
Start-Sleep -Milliseconds 40
[TF]::keybd_event(0x11, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 250
Press-Key 0x0D
Start-Sleep -Milliseconds 250

if ( $Shot -ne "" ) {
    $b = New-Object System.Drawing.Bitmap 3840,2160
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.CopyFromScreen(0,0,0,0,$b.Size)
    $b2 = New-Object System.Drawing.Bitmap 1920,1080
    $g2 = [System.Drawing.Graphics]::FromImage($b2)
    $g2.InterpolationMode = 'NearestNeighbor'
    $g2.DrawImage($b, 0, 0, 1920, 1080)
    $b2.Save($Shot)
    Write-Output ("shot -> " + $Shot)
}
Start-Sleep -Milliseconds 400
Write-Output "done"

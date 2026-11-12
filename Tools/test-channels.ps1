# Channel probe: test Ctrl+V paste and exec-file delivery into the game console.
# Both deliver a single PathPing; a new PING in the buffer proves the channel works.
# ASCII only.
param([ValidateSet('v','exec','both')] [string]$Channel = 'both')
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Add-Type -Path (Join-Path $root "Panel\cache\GameCtl.dll") | Out-Null
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
# Alt-tap releases the Windows foreground lock, then SetForegroundWindow works
[TF]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 60
[TF]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 60
[TF]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 400
$fg = [TF]::GetForegroundWindow()
if ( $fg -ne $h ) { Write-Output "FOCUS FAILED (game did not take foreground)"; exit 1 }
Write-Output "game focused"

function Open-Console {
    [TF]::keybd_event(0x10, 0, 0, [UIntPtr]::Zero)      # shift down
    Start-Sleep -Milliseconds 40
    [TF]::keybd_event(0xC0, 0, 0, [UIntPtr]::Zero)      # grave down
    Start-Sleep -Milliseconds 40
    [TF]::keybd_event(0xC0, 0, 2, [UIntPtr]::Zero)      # grave up
    [TF]::keybd_event(0x10, 0, 2, [UIntPtr]::Zero)      # shift up
    Start-Sleep -Milliseconds 600
}
function Press-Key([byte]$vk) {
    [TF]::keybd_event($vk, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 30
    [TF]::keybd_event($vk, 0, 2, [UIntPtr]::Zero)
}

if ( $Channel -eq 'v' -or $Channel -eq 'both' ) {
    Write-Output "== Ctrl+V probe =="
    Open-Console
    Set-Clipboard -Value 'PathPing'
    Start-Sleep -Milliseconds 150
    [TF]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero)      # ctrl down
    Start-Sleep -Milliseconds 40
    Press-Key 0x56                                       # V
    Start-Sleep -Milliseconds 40
    [TF]::keybd_event(0x11, 0, 2, [UIntPtr]::Zero)      # ctrl up
    Start-Sleep -Milliseconds 250
    Press-Key 0x0D                                       # enter
    Start-Sleep -Milliseconds 600
    Write-Output "sent"
}

if ( $Channel -eq 'exec' -or $Channel -eq 'both' ) {
    Write-Output "== exec-file probe =="
    $f = 'F:\Harry Potter and the Chamber of Secrets\System\panel-batch.txt'
    [System.IO.File]::WriteAllText($f, "PathPing`r`n")
    Open-Console
    # type chars via GameCtl.TapChar
    foreach ( $ch in 'exec panel-batch'.ToCharArray() ) {
        [GameCtl]::TapChar($ch)
        Start-Sleep -Milliseconds 20
    }
    Start-Sleep -Milliseconds 250
    Press-Key 0x0D
    Start-Sleep -Milliseconds 600
    Write-Output "sent"
}
Write-Output "PROBE DONE - run dump-buf-diag.ps1 and look for a fresh PING"

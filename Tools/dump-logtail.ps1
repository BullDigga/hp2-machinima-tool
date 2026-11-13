# Dump the raw game log-buffer text around 'Unrecognized' hits and the buffer tail.
# Uses MemScanPanel full scan. ASCII only.
param([int]$ctx = 120)
$ErrorActionPreference = "Stop"
Add-Type -Path 'C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Panel\cache\MemScanPanel.dll'
$gp = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
if ( $gp -eq $null ) { Write-Output "GAME NOT RUNNING"; exit 1 }
[MemScanPanel]::StartAsync($gp.Id, $null)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while ( [MemScanPanel]::AsyncState -ne 2 -and $sw.ElapsedMilliseconds -lt 60000 ) { Start-Sleep -Milliseconds 300 }
if ( [MemScanPanel]::AsyncState -ne 2 ) { Write-Output "SCAN TIMEOUT"; exit 1 }
$txt = [MemScanPanel]::AsyncResult
if ( $txt.StartsWith("|REGS:") ) { $nl = $txt.IndexOf("`n"); if ( $nl -gt 0 ) { $txt = $txt.Substring($nl + 1) } }
Write-Output ("buffer chars: " + $txt.Length)
$hits = [regex]::Matches($txt, 'Unrecognized')
Write-Output ("Unrecognized count: " + $hits.Count)
foreach ( $h in $hits ) {
    $s = [Math]::Max(0, $h.Index - $ctx)
    $len = [Math]::Min($ctx * 2, $txt.Length - $s)
    Write-Output ("--- ctx @" + $h.Index)
    Write-Output ($txt.Substring($s, $len) -replace "[^\x20-\x7E\r\n]", ".")
}
$tail = $txt.Substring([Math]::Max(0, $txt.Length - 800)) -replace "[^\x20-\x7E\r\n]", "."
Write-Output "=== TAIL ==="
Write-Output $tail

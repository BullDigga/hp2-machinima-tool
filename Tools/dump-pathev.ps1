# Dump recent PATHEV events from the game log buffer (full scan via MemScanPanel).
# Prints the last N events (CNST/MAP/PING/typing history) for diagnosis. ASCII only.
param([int]$tail = 40)
$ErrorActionPreference = "Stop"
Add-Type -Path 'C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Panel\cache\MemScanPanel.dll'
$gp = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
if ( $gp -eq $null ) { Write-Output "GAME NOT RUNNING"; exit 1 }
[MemScanPanel]::StartAsync($gp.Id, $null)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while ( [MemScanPanel]::AsyncState -ne 2 -and $sw.ElapsedMilliseconds -lt 60000 ) { Start-Sleep -Milliseconds 300 }
if ( [MemScanPanel]::AsyncState -ne 2 ) { Write-Output "SCAN TIMEOUT"; exit 1 }
$txt = [MemScanPanel]::AsyncResult
$evs = [regex]::Matches($txt, 'PATHEV:(\d+):(\d+)\|([A-Z]+)\|?([^\r\n]{0,60})')
Write-Output ("total events found: " + $evs.Count)
$skip = [Math]::Max(0, $evs.Count - $tail)
for ( $i = $skip; $i -lt $evs.Count; $i++ ) {
    $m = $evs[$i]
    Write-Output ("gen " + $m.Groups[1].Value + " seq " + $m.Groups[2].Value + " [" + $m.Groups[3].Value + "] " + $m.Groups[4].Value)
}

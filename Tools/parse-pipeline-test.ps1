# Reproduce the panel's exact parse pipeline on a real full scan. ASCII only.
$ErrorActionPreference = "Stop"
Add-Type -Path 'C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Panel\cache\MemScanPanel.dll'
$gp = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
if ( $gp -eq $null ) { Write-Output "GAME NOT RUNNING"; exit 1 }
[MemScanPanel]::StartAsync($gp.Id, $null)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while ( [MemScanPanel]::AsyncState -ne 2 -and $sw.ElapsedMilliseconds -lt 60000 ) { Start-Sleep -Milliseconds 300 }
if ( [MemScanPanel]::AsyncState -ne 2 ) { Write-Output "TIMEOUT"; exit 1 }
$txt = [MemScanPanel]::AsyncResult
if ( $txt.StartsWith("|REGS:") ) { $nl = $txt.IndexOf("`n"); $txt = $txt.Substring($nl + 1) }
Write-Output ("buffer chars: " + $txt.Length)
Write-Output ("contains PATHEV: " + $txt.Contains("PATHEV:"))
Write-Output ("contains MAP|: " + $txt.Contains("|MAP|"))
# the panel's event regex
$rxEv = [regex]'PATHEV:(\d+):(\d+)\|([A-Z]+)\|?([0-9A-Za-z.,:_\-]*)'
$ev = @()
$mgPre = 0
foreach ( $mp2 in $rxEv.Matches($txt) ) { $g3 = [long]$mp2.Groups[1].Value; if ( $g3 -gt $mgPre ) { $mgPre = $g3 } }
foreach ( $m in $rxEv.Matches($txt) ) {
    if ( [long]$m.Groups[1].Value -ne $mgPre ) { continue }
    $ev += New-Object PSObject -Property @{Gen=[long]$m.Groups[1].Value; Seq=[long]$m.Groups[2].Value; T=$m.Groups[3].Value; D=$m.Groups[4].Value}
}
Write-Output ("events after maxGen filter: " + $ev.Count)
$ded = @($ev | Group-Object -Property Seq | ForEach-Object {
    $_.Group | Sort-Object -Property @{ Expression = { $_.D.Length } } -Descending | Select-Object -First 1
} | Sort-Object -Property Seq)
Write-Output ("events after dedup: " + $ded.Count)
$ded | Select-Object -Last 10 | ForEach-Object { Write-Output ("seq " + $_.Seq + " [" + $_.T + "] " + $_.D) }
# DUMPMAP handling check
$dm = @($ded | Where-Object { $_.T -eq 'DUMPMAP' })
Write-Output ("DUMPMAP events: " + $dm.Count + " -> " + ($dm | Select-Object -Last 1).D)

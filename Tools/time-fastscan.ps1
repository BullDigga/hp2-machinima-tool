# Time the fast scan (ExtractRegions) over the cached region list. ASCII only.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Add-Type -Path (Join-Path $root "Panel\cache\MemScanPanel.dll") | Out-Null
$sc = Get-Content (Join-Path $root "Panel\scan-cache.json") -Raw | ConvertFrom-Json
$pairs = @($sc.regions | ForEach-Object { [long]$_ })
$gp = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
if ( $gp -eq $null -or $gp.Id -ne $sc.pid ) { Write-Output "PID mismatch (cache stale)"; exit 1 }
Write-Output ("regions: " + ($pairs.Count / 2) + ", sizes(MB): " + ((1..($pairs.Count/2) | ForEach-Object { [math]::Round($pairs[($_*2)+1] / 1MB, 1) }) -join ', '))
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$txt = [MemScanPanel]::ExtractRegions($gp.Id, [long[]]$pairs)
$sw.Stop()
Write-Output ("fast scan: " + $sw.ElapsedMilliseconds + "ms, text " + $txt.Length + " chars")
$cnt = ([regex]::Matches($txt, 'PATHEV:')).Count
Write-Output ("PATHEV occurrences: " + $cnt)

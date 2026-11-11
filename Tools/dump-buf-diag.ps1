# Diagnostic: dump the game log buffer (PATHEV events) to a file. ASCII only.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dll = Join-Path $root "Panel\cache\MemScanPanel.dll"
Add-Type -Path $dll
$gp = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
if ( $gp -eq $null ) { Write-Output "NO GAME PROCESS"; exit 1 }
Write-Output ("PID: " + $gp.Id)
$txt = [MemScanPanel]::GetLogEvents($gp.Id)
$out = "C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\buf-diag.txt"
[System.IO.File]::WriteAllText($out, $txt, [System.Text.Encoding]::UTF8)
Write-Output ("written " + $txt.Length + " chars -> " + $out)

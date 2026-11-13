# INVERSE of fix-mojibake.ps1 - EXACT line set of the original repair (17 lines).
# Used only to split the OBS commit from the mojibake commit. 1:1 per line.
$path = 'C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Panel\HP2MachinimaPanel.ps1'
$cp1251 = [System.Text.Encoding]::GetEncoding(1251)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$targets = @(3648,3649,3674,3701,3732,3794,3813,3844,3855,3887,3897,3916,3924,3968,3975,3983,4018)
$lines = [System.IO.File]::ReadAllLines($path, $utf8)
$fixed = 0
foreach ( $ln in $targets ) {
    $orig = $lines[$ln - 1]
    $bytes = $utf8.GetBytes($orig)
    $cand = $cp1251.GetString($bytes)
    $dec = ""
    try { $dec = $utf8.GetString($cp1251.GetBytes($cand)) } catch { continue }
    if ( $dec -ne $orig ) { Write-Output ("L" + $ln + ": round-trip FAILED - skipped"); continue }
    $lines[$ln - 1] = $cand
    $fixed++
}
if ( $fixed -gt 0 ) {
    $utf8bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($path, (($lines -join "`r`n") + "`r`n"), $utf8bom)
}
Write-Output ("re-garbled lines: " + $fixed)

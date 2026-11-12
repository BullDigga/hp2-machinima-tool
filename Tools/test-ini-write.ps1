# Test: write a test key into Game.ini [HGame.HPConsole] SavedPathData, then the
# panel sends PathLoad; if the game loads from the ini, the path becomes the test key.
$ErrorActionPreference = "Stop"
$ini = 'C:\Users\Kolya\OneDrive\Документы\Harry - Coding Evolved\Game.ini'
$test = 'SavedPathData=100.000000,200.000000,300.000000,0,0,90.000000,600.000000'
$lines = [System.IO.File]::ReadAllLines($ini)
$idx = -1
for ( $i = 0; $i -lt $lines.Length; $i++ ) {
    if ( $lines[$i] -like 'SavedPathData=*' -and $idx -lt 0 ) { $idx = $i; break }
}
if ( $idx -lt 0 ) { Write-Output "SavedPathData line not found"; exit 2 }
$orig = $lines[$idx]
$lines[$idx] = $test
[System.IO.File]::WriteAllLines($ini, $lines)
Write-Output ("replaced line " + $idx + ": " + $orig.Substring(0, [Math]::Min(80, $orig.Length)) + "...")
[System.IO.File]::WriteAllText('C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\ini-orig.txt', $orig)

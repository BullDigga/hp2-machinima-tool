# Compile HGame.u elevated (ucc make). Closes Game.exe first (standing rule:
# the agent kills games itself). Output log goes to the WORKSPACE with .txt
# extension - a fresh *.log in System\ poisoned the panel's Find-LogFile
# (v5.17.33.1 incident: ucc-make-out.log won "most recent game log" and the
# sync parsed emptiness forever, buttons stayed grey).
# Usage: powershell -File Tools/compile-hgame.ps1  (UAC prompt appears). ASCII only.
$ErrorActionPreference = "Stop"
$sys = 'F:\Harry Potter and the Chamber of Secrets\System'
$out = Join-Path $PSScriptRoot 'ucc-make-out.txt'

$g = Get-Process Game -ErrorAction SilentlyContinue
if ( $g ) {
    Write-Output ("closing Game.exe pid " + $g.Id)
    $g | Stop-Process -Force
    Start-Sleep -Milliseconds 1200
}

$cmd = 'cd /d "' + $sys + '" && ucc.exe make > "' + $out + '" 2>&1'
Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $cmd -Verb RunAs -Wait
Get-Content $out -Tail 6
if ( (Get-Content $out) -match 'Success - 0 error' ) { Write-Output 'COMPILE OK'; exit 0 }
Write-Output 'COMPILE FAILED (see tail above)'
exit 1

# Compile HGame.u elevated (ucc make). Closes Game.exe first (standing rule:
# the agent kills games itself). Output log goes to the WORKSPACE with .txt
# extension - a fresh *.log in System\ poisoned the panel's Find-LogFile
# (v5.17.33.1 incident: ucc-make-out.log won "most recent game log" and the
# sync parsed emptiness forever, buttons stayed grey).
# v5.17.43: ucc make DELETES HGame.u before compiling; a failed compile leaves
# the game without it (v5.17.43 incident: three failed cleanup builds in a row
# deleted HGame.u, the user's next launch died with a UClass::Bind assertion on
# HP1Goat). Backup before ucc, auto-restore after if the save did not happen.
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

# backup HGame.u (any previous good build)
$bak = Join-Path $env:TEMP 'HGame.u.precompile.bak'
$hadU = $false
if ( Test-Path (Join-Path $sys 'HGame.u') ) {
    Copy-Item (Join-Path $sys 'HGame.u') $bak -Force
    $hadU = $true
    Write-Output ("backup: " + $bak)
}

$cmd = 'cd /d "' + $sys + '" && ucc.exe make > "' + $out + '" 2>&1'
Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $cmd -Verb RunAs -Wait
Get-Content $out -Tail 6

# restore if ucc deleted the package and did not save a new one
if ( -not (Test-Path (Join-Path $sys 'HGame.u')) ) {
    if ( $hadU ) {
        Copy-Item $bak (Join-Path $sys 'HGame.u') -Force
        Write-Output 'HGame.u was deleted by the failed compile - RESTORED from pre-compile backup'
    } else {
        Write-Output 'HGame.u MISSING and no backup - install is broken, restore HGame.u.stock.bak manually'
    }
}

if ( (Get-Content $out) -match 'Success - 0 error' ) { Write-Output 'COMPILE OK'; exit 0 }
Write-Output 'COMPILE FAILED (see tail above)'
exit 1

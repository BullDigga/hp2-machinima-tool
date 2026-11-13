# Patch: RESTORE the quiet-console parking (WinLeft=-10000) in the Shift+grave
# KeyEvent branch - inverse of patch-quiet-disable.ps1. Panel batches open the
# console OFF-SCREEN again (the visible console shrank the UE1 viewport + a black
# console window appeared at the bottom of the screen - user report 2026-11-13;
# background probes PathDumpKeys open the console WITHOUT the user typing
# anything). ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$old = "`t`t`t// DIAGNOSTIC: quiet parking DISABLED - console opens visible" + $nl + "`t`t`t// (restore with Tools/patch-quiet-restore.ps1)"
$new = "`t`t`tif ( bQuietConsole && bCreatedRoot && ConsoleWindow != None )" + $nl + "`t`t`t{" + $nl + "`t`t`t`tConsoleWindow.WinLeft = -10000.0;" + $nl + "`t`t`t`tConsoleWindow.WinTop = -10000.0;" + $nl + "`t`t`t}"
if ( $txt.Contains($old) ) {
    $txt = $txt.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $txt, $enc)
    Write-Output "PARKING RESTORED"
    exit 0
}
if ( $txt.Contains("ConsoleWindow.WinLeft = -10000.0") ) { Write-Output "ALREADY RESTORED"; exit 0 }
Write-Output "PATTERN NOT FOUND"
exit 2

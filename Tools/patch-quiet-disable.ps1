# Diagnostic patch: DISABLE the quiet-console parking (WinLeft=-10000) in the
# Shift+grave KeyEvent branch so panel batches open the console VISIBLE on screen.
# Temporary diagnostics build - restore with a follow-up patch after the cause
# is found. ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$old = "`t`t`tif ( bQuietConsole && bCreatedRoot && ConsoleWindow != None )" + $nl + "`t`t`t{" + $nl + "`t`t`t`tConsoleWindow.WinLeft = -10000.0;" + $nl + "`t`t`t`tConsoleWindow.WinTop = -10000.0;" + $nl + "`t`t`t}"
$new = "`t`t`t// DIAGNOSTIC: quiet parking DISABLED - console opens visible" + $nl + "`t`t`t// (restore with Tools/patch-quiet-restore.ps1)"
if ( $txt.Contains($old) ) {
    $txt = $txt.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $txt, $enc)
    Write-Output "PARKING DISABLED"
    exit 0
}
Write-Output "PATTERN NOT FOUND"
exit 2

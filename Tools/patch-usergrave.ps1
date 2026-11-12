# Patch game-side HPConsole.uc: user's plain ` always brings the terminal back on screen.
# The panel's Shift+` quiet mode parks ConsoleWindow at -10000; the user's own grave then
# opened ShowConsole() at that parked position = an INVISIBLE terminal (UWindow wand
# cursor stays, WASD go to the console) - reported by the user as "panel did not close
# the terminal". ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)

$old = "`t`tif (  !bShowConsole )" + "`r`n" + "`t`t{" + "`r`n" + "`t`t`tShowConsole();" + "`r`n" + "`t`t}" + "`r`n" + "`t`telse" + "`r`n" + "`t`t{"
$new = "`t`tif (  !bShowConsole )" + "`r`n" + "`t`t{" + "`r`n" + "`t`t`t// v5.17.30.9b: the user's plain ` must ALWAYS show the terminal on screen." + "`r`n" + "`t`t`t// The panel's Shift+` parks ConsoleWindow at -10000 (quiet mode); without" + "`r`n" + "`t`t`t// restoring coordinates the user's own ` opened it INVISIBLE - the UWindow" + "`r`n" + "`t`t`t// wand cursor stayed, WASD went to the console, and the panel looked like it" + "`r`n" + "`t`t`t// did not close the terminal." + "`r`n" + "`t`t`tif ( bQuietConsole && bCreatedRoot && ConsoleWindow != None && ConsoleWindow.WinLeft < -5000.0 )" + "`r`n" + "`t`t`t{" + "`r`n" + "`t`t`t`tConsoleWindow.WinLeft = ( Root.WinWidth  - ConsoleWindow.WinWidth  ) / 2.0;" + "`r`n" + "`t`t`t`tConsoleWindow.WinTop  = ( Root.WinHeight - ConsoleWindow.WinHeight ) / 2.0;" + "`r`n" + "`t`t`t}" + "`r`n" + "`t`t`tShowConsole();" + "`r`n" + "`t`t}" + "`r`n" + "`t`telse" + "`r`n" + "`t`t{"

if ( $txt.Contains($old) ) {
    $txt = $txt.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $txt, $enc)
    Write-Output "PATCHED (CRLF)"
    exit 0
}
$oldLf = $old.Replace("`r`n", "`n")
if ( $txt.Contains($oldLf) ) {
    $txt = $txt.Replace($oldLf, $new.Replace("`r`n", "`n"))
    [System.IO.File]::WriteAllText($p, $txt, $enc)
    Write-Output "PATCHED (LF)"
    exit 0
}
Write-Output "PATTERN NOT FOUND"
exit 2

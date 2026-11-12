# Patch: user-grave restore position = fixed top-left corner (10,10) instead of the
# center formula (ConsoleWindow may be larger than the Root viewport, making the
# centered coordinates negative = fully off-screen again). ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$old = "`t`t`t`tConsoleWindow.WinLeft = ( Root.WinWidth  - ConsoleWindow.WinWidth  ) / 2.0;" + $nl + "`t`t`t`tConsoleWindow.WinTop  = ( Root.WinHeight - ConsoleWindow.WinHeight ) / 2.0;"
$new = "`t`t`t`tConsoleWindow.WinLeft = 10.0;" + $nl + "`t`t`t`tConsoleWindow.WinTop  = 10.0;"
if ( $txt.Contains($old) ) {
    $txt = $txt.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $txt, $enc)
    Write-Output "PATCHED to top-left corner"
    exit 0
}
Write-Output "PATTERN NOT FOUND"
exit 2

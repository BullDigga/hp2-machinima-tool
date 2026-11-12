# Patch game-side HPConsole.uc: PathPing closes UWindow unconditionally. ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)

$nl = "`r`n"
$old = "exec function PathPing()" + $nl + "{" + $nl + "`tharry(Viewport.Actor).Cam.PathPing();" + $nl + "`tif ( bShowConsole )" + $nl + "`t{" + $nl + "`t`tHideConsole();" + $nl + "`t`tCloseUWindow();" + $nl + "`t}" + $nl + "}"
$new = "exec function PathPing()" + $nl + "{" + $nl + "`tharry(Viewport.Actor).Cam.PathPing();" + $nl + "`tif ( bShowConsole )" + $nl + "`t{" + $nl + "`t`tHideConsole();" + $nl + "`t}" + $nl + "`t// v5.17.30.9 machinima panel: CloseUWindow UNCONDITIONALLY (twice; the second" + $nl + "`t// call is a no-op). The old if(bShowConsole) wrapper skipped CloseUWindow when" + $nl + "`t// PathPing executed while bShowConsole was already False (stuck UWindow session" + $nl + "`t// after a lost Enter) - the UWindow wand cursor stayed on-screen and WASD went" + $nl + "`t// to the console instead of the game. CloseUWindow is safe when nothing is open." + $nl + "`tCloseUWindow();" + $nl + "`tCloseUWindow();" + $nl + "}"

if ( $txt.Contains($old) ) {
    $txt = $txt.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $txt, $enc)
    Write-Output "PATCHED (CRLF)"
    exit 0
}
$oldLf = $old.Replace($nl, "`n")
if ( $txt.Contains($oldLf) ) {
    $txt = $txt.Replace($oldLf, $new.Replace($nl, "`n"))
    [System.IO.File]::WriteAllText($p, $txt, $enc)
    Write-Output "PATCHED (LF)"
    exit 0
}
Write-Output "PATTERN NOT FOUND"
exit 2

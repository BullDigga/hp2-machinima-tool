# Patch v2: PathPing must reset the UWindow state UNCONDITIONALLY - the stuck state
# has bShowConsole already False while the UWindow session is still active (wand
# cursor visible, input eaten). Old code skipped HideConsole() in that state, so the
# cursor never went away even with CloseUWindow x2. ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$old = "`tharry(Viewport.Actor).Cam.PathPing();" + $nl + "`tif ( bShowConsole )" + $nl + "`t{" + $nl + "`t`tHideConsole();" + $nl + "`t}" + $nl + "`t// v5.17.30.9 machinima panel: CloseUWindow UNCONDITIONALLY (twice; the second"
$new = "`tharry(Viewport.Actor).Cam.PathPing();" + $nl + "`t// v5.17.30.9b2: HideConsole UNCONDITIONALLY - the stuck state has bShowConsole" + $nl + "`t// already False while the UWindow session is still active (wand cursor visible," + $nl + "`t// input eaten); hiding only when shown left that state unfixable from the panel" + $nl + "`tHideConsole();" + $nl + "`tbShowConsole = False;" + $nl + "`t// v5.17.30.9 machinima panel: CloseUWindow UNCONDITIONALLY (twice; the second"

if ( $txt.Contains($old) ) {
    $txt = $txt.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $txt, $enc)
    Write-Output "PATCHED (CRLF)"
    exit 0
}
Write-Output "PATTERN NOT FOUND"
exit 2

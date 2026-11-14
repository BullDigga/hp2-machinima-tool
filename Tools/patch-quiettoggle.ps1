# QuietConsole exec: the panel can toggle terminal parking. bQuietConsole=True
# (default) parks the panel-opened console off-screen (-10000); False = console
# opens VISIBLE during panel batches, as the user's own grave does. The panel
# keeps its own setting in settings.json and re-sends "QuietConsole 0/1" on
# every new game session (the class has no config() so SaveConfig is a no-op -
# panel-side persistence is the reliable layer). ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$t1 = "`t"
$t2 = "`t`t"

if ( -not $txt.Contains('exec function QuietConsole') ) {
    $old = 'exec function Cam_Mode (string sInput)'
    if ( -not $txt.Contains($old) ) { Write-Output 'ANCHOR NOT FOUND: Cam_Mode'; exit 2 }
    $new = 'exec function QuietConsole (string sInput)' + $nl +
           '{' + $nl +
           '  // v5.17.41: panel toggle for terminal parking. 1 = quiet (off-screen),' + $nl +
           '  // 0 = visible during panel batches' + $nl +
           '  if ( sInput == "1" || sInput ~= "true" ) { bQuietConsole = True; }' + $nl +
           '  else { bQuietConsole = False; }' + $nl +
           '}' + $nl +
           $nl +
           $old
    $txt = $txt.Replace($old, $new)
    Write-Output 'exec QuietConsole inserted'
}

# v5.17.41.1: mid-session toggle fix. The panel-open branch (Shift+grave) parked
# the console at -10000 while quiet was ON; after switching to visible mode the
# window STAYS parked - ShowConsole shows it off-screen (user report: "terminal
# invisible in both toggle states"). Restore coordinates when not parking.
$old = 'if ( bQuietConsole && bCreatedRoot && ConsoleWindow != None )' + $nl +
       $t2 + '{' + $nl
$marker = 'ConsoleWindow.WinLeft = -10000.0;'
if ( $txt.Contains('v5.17.41.1') ) { Write-Output 'restore branch already present' }
elseif ( $txt.Contains($marker) ) {
    # real indent = 4 tabs (block sits inside KeyDown's Shift branch)
    $t4 = "`t`t`t`t"
    $t5 = "`t`t`t`t`t"
    $old = $t4 + 'if ( bQuietConsole && bCreatedRoot && ConsoleWindow != None )' + $nl +
           $t4 + '{' + $nl +
           $t5 + 'ConsoleWindow.WinLeft = -10000.0;' + $nl +
           $t5 + 'ConsoleWindow.WinTop = -10000.0;' + $nl
    if ( -not $txt.Contains($old) ) { Write-Output 'ANCHOR NOT FOUND: park block (indent mismatch)'; exit 2 }
    $new = $t4 + 'if ( bQuietConsole && bCreatedRoot && ConsoleWindow != None )' + $nl +
           $t4 + '{' + $nl +
           $t5 + 'ConsoleWindow.WinLeft = -10000.0;' + $nl +
           $t5 + 'ConsoleWindow.WinTop = -10000.0;' + $nl +
           $t4 + '}' + $nl +
           $t4 + '// v5.17.41.1: quiet was switched OFF mid-session - the console may still' + $nl +
           $t4 + '// sit parked at -10000 from earlier commands; restore it or it opens INVISIBLE' + $nl +
           $t4 + 'else if ( bCreatedRoot && ConsoleWindow != None && ConsoleWindow.WinLeft < -5000.0 )' + $nl +
           $t4 + '{' + $nl +
           $t5 + 'ConsoleWindow.WinLeft = 10.0;' + $nl +
           $t5 + 'ConsoleWindow.WinTop = 10.0;' + $nl
    $txt = $txt.Replace($old, $new)
    Write-Output 'restore branch inserted'
}

[System.IO.File]::WriteAllText($p, $txt, $enc)
Write-Output 'QUIETTOGGLE PATCHED (exec + mid-session restore)'
exit 0

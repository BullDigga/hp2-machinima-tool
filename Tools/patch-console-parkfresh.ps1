# Patch: park ONLY the console the panel JUST opened (inside if(!bShowConsole)).
# Parking an ALREADY-OPEN console (the user's own terminal, or a stale-flag case)
# made it VANISH mid-air and exposed the UWindow root with the FE book page
# ("Language Browser" = FESoundBrowser) + black bottom bar - user report 2026-11-13.
# ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$tab = "`t"

$old = $tab + $tab + $tab + "if (  !bShowConsole )" + $nl +
       $tab + $tab + $tab + "{" + $nl +
       $tab + $tab + $tab + $tab + "ShowConsole();" + $nl +
       $tab + $tab + $tab + "}" + $nl +
       $tab + $tab + $tab + "if ( bQuietConsole && bCreatedRoot && ConsoleWindow != None )" + $nl +
       $tab + $tab + $tab + "{" + $nl +
       $tab + $tab + $tab + $tab + "ConsoleWindow.WinLeft = -10000.0;" + $nl +
       $tab + $tab + $tab + $tab + "ConsoleWindow.WinTop = -10000.0;" + $nl +
       $tab + $tab + $tab + "}" + $nl +
       $tab + $tab + $tab + "return True;"

$new = $tab + $tab + $tab + "if (  !bShowConsole )" + $nl +
       $tab + $tab + $tab + "{" + $nl +
       $tab + $tab + $tab + $tab + "ShowConsole();" + $nl +
       $tab + $tab + $tab + $tab + "// v5.17.32.6: park ONLY the console the panel JUST opened. Parking an" + $nl +
       $tab + $tab + $tab + $tab + "// ALREADY-OPEN console (the user's own terminal) made it vanish mid-air" + $nl +
       $tab + $tab + $tab + $tab + "// and exposed the FE root (Language Browser page + black bar - user report)" + $nl +
       $tab + $tab + $tab + $tab + "if ( bQuietConsole && bCreatedRoot && ConsoleWindow != None )" + $nl +
       $tab + $tab + $tab + $tab + "{" + $nl +
       $tab + $tab + $tab + $tab + $tab + "ConsoleWindow.WinLeft = -10000.0;" + $nl +
       $tab + $tab + $tab + $tab + $tab + "ConsoleWindow.WinTop = -10000.0;" + $nl +
       $tab + $tab + $tab + $tab + "}" + $nl +
       $tab + $tab + $tab + "}" + $nl +
       $tab + $tab + $tab + "return True;"

if ( $txt.Contains($old) ) {
    $txt = $txt.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $txt, $enc)
    Write-Output "PARK-FRESH PATCHED"
    exit 0
}
if ( $txt.Contains("park ONLY the console the panel JUST opened") ) { Write-Output "ALREADY PATCHED"; exit 0 }
Write-Output "PATTERN NOT FOUND"
exit 2

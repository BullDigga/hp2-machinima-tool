# Book-state events: HPConsole logs PATHEV BOOK|1/0 when the menu-book opens/
# closes over the level. The panel warns "commands won't be executed" while a
# book is up (user report: typed PathAdd in the book did nothing). Uses the
# Cam's iPathGen/iPathSeq like CNST does. ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$t1 = "`t"

if ( $txt.Contains('v5.17.37.2') ) { Write-Output 'ALREADY PATCHED'; exit 0 }

# --- 1. var ---
$old = 'var FEBook menuBook;'
if ( -not $txt.Contains($old) ) { Write-Output 'P1 NOT FOUND: menuBook var'; exit 2 }
$new = $old + $nl +
       'var bool bLastBookOpen;  // v5.17.37.2: BOOK|1/0 transition events for the panel'
$txt = $txt.Replace($old, $new)

# --- 2. Tick: log transitions (before the auto-freecam block) ---
$old = $t1 + '// Machinima tool v3: auto-enable FreeCam when the standard camera settles in'
if ( -not $txt.Contains($old) ) { Write-Output 'P2 NOT FOUND: Tick anchor'; exit 2 }
$new = $t1 + '// v5.17.37.2: BOOK|1/0 transitions - the panel warns "commands won' + "'t" + $nl +
       $t1 + '// be executed" while a menu-book is open over the level' + $nl +
       $t1 + 'if ( menuBook != None && menuBook.bIsOpen != bLastBookOpen )' + $nl +
       $t1 + '{' + $nl +
       $t1 + $t1 + 'bLastBookOpen = menuBook.bIsOpen;' + $nl +
       $t1 + $t1 + 'if ( Viewport != None && Viewport.Actor != None && harry(Viewport.Actor) != None && harry(Viewport.Actor).Cam != None )' + $nl +
       $t1 + $t1 + '{' + $nl +
       $t1 + $t2 + 'harry(Viewport.Actor).Cam.iPathSeq++;' + $nl +
       $t1 + $t2 + 'Log("PATHEV:"$harry(Viewport.Actor).Cam.iPathGen$":"$harry(Viewport.Actor).Cam.iPathSeq$"|BOOK|"$int(menuBook.bIsOpen));' + $nl +
       $t1 + $t1 + '}' + $nl +
       $t1 + '}' + $nl +
       $old
$txt = $txt.Replace($old, $new)

[System.IO.File]::WriteAllText($p, $txt, $enc)
Write-Output 'BOOKSTATE PATCHED (BOOK|1/0 transitions in Tick)'
exit 0

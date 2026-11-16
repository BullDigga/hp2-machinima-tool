# Issue #22 (partial): FE-book stuck page reset in HideConsole. The FE book can
# stay SHOWN over a loaded level (bShowBackground=True, last FE page - e.g. the
# Language Browser grid with Status/Name/Text columns) while bIsOpen already
# settled False; the next UWindow-root activation (the user's terminal, a panel
# send) EXPOSES it and its controls eat the keyboard - commands stop arriving.
# Reset it on every console close; the legit ESC menu (bIsOpen=True) is
# untouched, no StopMusic (the book is not open, level music must not be hit).
# NOTE: applied gate v1 (bShowBackground). A curPage-based gate was tried and
# rolled back - under the console open/close flicker it fired too rarely to
# matter; the exposure needs a deeper UWindow-root fix (issue #22 stays open).
# Idempotent. ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$nl = "`r`n"
$t = [char]9
$t2 = $t + $t

$txt = [System.IO.File]::ReadAllText($p, $enc)
if ( $txt.Contains('v5.17.44 (#22)') ) { Write-Output 'ALREADY PATCHED'; exit 0 }

$old = $t + 'if ( bCreatedRoot )' + $nl +
       $t + '{' + $nl +
       $t2 + 'ConsoleWindow.HideWindow();' + $nl +
       $t + '}'
if ( -not $txt.Contains($old) ) { Write-Output 'ANCHOR NOT FOUND: HideConsole HideWindow block'; exit 2 }
$new = $t + 'if ( bCreatedRoot )' + $nl +
       $t + '{' + $nl +
       $t2 + 'ConsoleWindow.HideWindow();' + $nl +
       $t + '}' + $nl +
       $nl +
       $t2 + '// v5.17.44 (#22): the FE book can stay SHOWN over a loaded level' + $nl +
       $t2 + '// (bShowBackground=True, last FE page - e.g. the Language Browser grid' + $nl +
       $t2 + '// with Status/Name/Text columns) while bIsOpen already settled False;' + $nl +
       $t2 + '// the next UWindow-root activation (the user terminal, a panel send)' + $nl +
       $t2 + '// EXPOSES it and its controls eat the keyboard - commands stop arriving.' + $nl +
       $t2 + '// Kill the stuck page here, same reset as the level-init one; the legit' + $nl +
       $t2 + '// ESC menu (bIsOpen=True) is untouched, no StopMusic (book not open)' + $nl +
       $t2 + 'if ( menuBook != None && !menuBook.bIsOpen && menuBook.bShowBackground )' + $nl +
       $t2 + '{' + $nl +
       $t2 + $t + 'menuBook.bShowBackground = False;' + $nl +
       $t2 + $t + 'menuBook.ChangePage(None);' + $nl +
       $t2 + '}'
$txt = $txt.Replace($old, $new)
[System.IO.File]::WriteAllText($p, $txt, $enc)
Write-Output 'HIDECONSOLE STUCK-PAGE RESET ADDED'
exit 0

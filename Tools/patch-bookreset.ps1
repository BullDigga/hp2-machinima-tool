# Patch: reset the FE book state at level load WITHOUT HideWindow/CloseUWindow
# (both broke the console: HideWindow killed its background skin, CloseBook's
# CloseUWindow at level load killed its INPUT). Replicate the FRONTEND's own
# start-map state (what CloseBook sets) via public fields only:
#   bIsOpen=False, bShowBackground=False, ChangePage(None), StopMusic().
# That is the exact state normal gameplay runs in (frontend-loaded maps), where
# the console always painted and worked. ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$t3 = "`t`t`t"
$t4 = "`t`t`t`t"

$old = $t3 + "harry(Viewport.Actor).Cam.bAutoFreeCamUsed = False;" + $nl
$new = $t3 + "harry(Viewport.Actor).Cam.bAutoFreeCamUsed = False;" + $nl +
       $t3 + "// v5.17.32.16: a console-initiated travel (panel map picker) bypasses the" + $nl +
       $t3 + "// frontend flow, so the FE book stays SHOWN (bShowBackground=True, last page" + $nl +
       $t3 + "// e.g. 'Language Browser') and every UWindow-root activation (panel batches," + $nl +
       $t3 + "// the user's own terminal) exposed it fullscreen. Reset the book to the" + $nl +
       $t3 + "// FRONTEND's own post-start-map state via public fields (NO HideWindow - it" + $nl +
       $t3 + "// breaks the console skin; NO CloseUWindow - it breaks the console input):" + $nl +
       $t3 + "if ( menuBook != None && menuBook.bIsOpen )" + $nl +
       $t3 + "{" + $nl +
       $t4 + "menuBook.StopMusic();" + $nl +
       $t4 + "menuBook.bIsOpen = False;" + $nl +
       $t4 + "menuBook.bShowBackground = False;" + $nl +
       $t4 + "menuBook.ChangePage(None);" + $nl +
       $t3 + "}" + $nl

if ( $txt.Contains($old) ) {
    if ( $txt.Contains("v5.17.32.16: a console-initiated travel") ) { Write-Output "ALREADY PATCHED"; exit 0 }
    $txt = $txt.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $txt, $enc)
    Write-Output "BOOK-RESET PATCHED"
    exit 0
}
Write-Output "PATTERN NOT FOUND"
exit 2

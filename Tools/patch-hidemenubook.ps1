# Patch v3: (1) REVERT the level-load menuBook.HideWindow (v2) - ANY raw HideWindow
# on the FE book breaks the console window's background painting ("терминал без
# фона"). (2) Close the book the GAME'S OWN WAY at level load: menuBook.CloseBook()
# is what the frontend calls when a map starts (stops music, bIsOpen=false,
# bShowBackground=False, CloseUWindow). A console-initiated travel (panel map
# picker: 'open <map>') bypasses the frontend flow, so the book stayed SHOWN with
# bShowBackground=True and every UWindow-root activation (panel batches) painted
# the full-screen black + its last page ("Language Browser" = FESoundBrowser).
# CloseBook at level load = the exact state the normal frontend flow produces.
# ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$t3 = $t * 3
$t4 = $t * 4

# --- (1) revert the level-load HideWindow (v2) ---
$oldHide = $t3 + "// v5.17.32.8: a console-initiated travel (panel map picker) bypasses the" + $nl +
           $t3 + "// frontend flow that hides the FE book - the book stays SHOWN and every" + $nl +
           $t3 + "// UWindow-root activation exposed its page ('Language Browser') + black." + $nl +
           $t3 + "// Hide once per level load = the state the normal frontend flow produces" + $nl +
           $t3 + "if ( menuBook != None )" + $nl +
           $t3 + "{" + $nl +
           $t4 + "menuBook.HideWindow();" + $nl +
           $t3 + "}" + $nl
if ( $txt.Contains($oldHide) ) {
    $txt = $txt.Replace($oldHide, "")
    Write-Output "level-load HideWindow REVERTED"
} elseif ( $txt.Contains("a console-initiated travel (panel map picker)") ) {
    Write-Output "level-load HideWindow: ALREADY REVERTED"
} else {
    Write-Output "level-load HideWindow: PATTERN NOT FOUND"
    exit 2
}

# --- (2) CloseBook at level load ---
$oldTick = $t3 + "harry(Viewport.Actor).Cam.bAutoFreeCamUsed = False;" + $nl
$newTick = $t3 + "harry(Viewport.Actor).Cam.bAutoFreeCamUsed = False;" + $nl +
           $t3 + "// v5.17.32.9: a console-initiated travel (panel map picker) bypasses the" + $nl +
           $t3 + "// frontend flow, so the FE book stays SHOWN (bShowBackground=True) and every" + $nl +
           $t3 + "// UWindow-root activation (panel batches) painted full-screen black + its" + $nl +
           $t3 + "// last page ('Language Browser'). CloseBook = the game's own close routine" + $nl +
           $t3 + "if ( menuBook != None && menuBook.bIsOpen )" + $nl +
           $t3 + "{" + $nl +
           $t4 + "menuBook.CloseBook();" + $nl +
           $t3 + "}" + $nl

if ( $txt.Contains($oldTick) ) {
    $txt = $txt.Replace($oldTick, $newTick)
    Write-Output "level-load CloseBook ADDED"
} elseif ( $txt.Contains("CloseBook = the game's own close routine") ) {
    Write-Output "level-load CloseBook: ALREADY PRESENT"
} else {
    Write-Output "level-load CloseBook: PATTERN NOT FOUND"
    exit 2
}
[System.IO.File]::WriteAllText($p, $txt, $enc)
Write-Output "SAVED"

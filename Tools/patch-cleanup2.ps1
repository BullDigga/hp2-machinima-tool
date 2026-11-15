# Cleanup v2: remove the level-load CloseBook block (v5.17.32.9). ANY menuBook
# manipulation at level load breaks the console window (input dead - user report).
# Back to the known-good pre-menuBook state. ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$old = "// v5.17.32.9: a console-initiated travel (panel map picker) bypasses the" + $nl +
       "// frontend flow, so the FE book stays SHOWN (bShowBackground=True) and every" + $nl +
       "// UWindow-root activation (panel batches) painted full-screen black + its" + $nl +
       "// last page ('Language Browser'). CloseBook = the game's own close routine" + $nl +
       "if ( menuBook != None && menuBook.bIsOpen )" + $nl +
       "{" + $nl +
       "menuBook.CloseBook();" + $nl +
       "}" + $nl
if ( $txt.Contains($old) ) {
    $txt = $txt.Replace($old, "")
    [System.IO.File]::WriteAllText($p, $txt, $enc)
    Write-Output "CloseBook BLOCK REMOVED"
    exit 0
}
if ( $txt.Contains("CloseBook = the game's own close routine") ) { Write-Output "STILL PRESENT (pattern mismatch)"; exit 2 }
Write-Output "ALREADY CLEAN"

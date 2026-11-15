# Cleanup: remove the leftover v2 menuBook.HideWindow block from Tick. ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$t3 = "`t`t`t"
$t4 = "`t`t`t`t"
$old = $t3 + "// v5.17.32.8: a console-initiated travel (panel map picker) bypasses the" + $nl +
       $t3 + "// frontend flow that hides the FE book - the book stays SHOWN and every" + $nl +
       $t3 + "// UWindow-root activation exposed its page ('Language Browser') + black." + $nl +
       $t3 + "// Hide once per level load = the state the normal frontend flow produces" + $nl +
       $t3 + "if ( menuBook != None )" + $nl +
       $t3 + "{" + $nl +
       $t4 + "menuBook.HideWindow();" + $nl +
       $t3 + "}" + $nl
if ( $txt.Contains($old) ) {
    $txt = $txt.Replace($old, "")
    [System.IO.File]::WriteAllText($p, $txt, $enc)
    Write-Output "v2 BLOCK REMOVED"
    exit 0
}
if ( $txt.Contains("menuBook.HideWindow()") ) { Write-Output "HIDEWINDOW STILL PRESENT"; exit 2 }
Write-Output "ALREADY CLEAN"

# Patch: CNST console-state events in HPConsole ShowConsole/HideConsole.
# The panel scans PATHEV events from the log buffer; a CNST|OPEN / CNST|CLOSE event
# tells it whether the console is currently open. With console open the panel skips
# its Shift+grave ensure-open (which would CLOSE the user's already-open terminal
# and lose the commands - user report: "если терминал уже открыл, команды не проходят").
# Uses BaseCam's iPathGen/iPathSeq (public vars) for event ordering. ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"

# idempotency marker
if ( $txt.Contains("|CNST|OPEN") ) { Write-Output "ALREADY PATCHED"; exit 0 }

# UC lines to insert (single-quoted PS strings - no interpolation)
$guard = 'if ( Viewport != None && Viewport.Actor != None && harry(Viewport.Actor) != None && harry(Viewport.Actor).Cam != None )'
$logOpen = 'Log("PATHEV:"$harry(Viewport.Actor).Cam.iPathGen$":"$harry(Viewport.Actor).Cam.iPathSeq$"|CNST|OPEN");'
$logClose = 'Log("PATHEV:"$harry(Viewport.Actor).Cam.iPathGen$":"$harry(Viewport.Actor).Cam.iPathSeq$"|CNST|CLOSE");'

$oldShow = @'
	bShowConsole = True;
	if ( bCreatedRoot )
	{
		ConsoleWindow.ShowWindow();
	}
'@
$oldShow = $oldShow -replace "`n", $nl
$newShow = @'
	bShowConsole = True;
	// v5.17.32.3: CNST OPEN - the panel detects an already-open console and skips ensure-open
	if ( Viewport != None && Viewport.Actor != None && harry(Viewport.Actor) != None && harry(Viewport.Actor).Cam != None )
	{
		harry(Viewport.Actor).Cam.iPathSeq++;
		LOGOPENPLACEHOLDER
	}
	if ( bCreatedRoot )
	{
		ConsoleWindow.ShowWindow();
	}
'@
$newShow = $newShow -replace "`n", $nl -replace 'LOGOPENPLACEHOLDER', $logOpen

$oldHide = @'
	bShowConsole = False;
	if ( bCreatedRoot )
	{
		ConsoleWindow.HideWindow();
	}
'@
$oldHide = $oldHide -replace "`n", $nl
$newHide = @'
	bShowConsole = False;
	// v5.17.32.3: CNST CLOSE - covers the PathPing close and the user's own grave close
	if ( Viewport != None && Viewport.Actor != None && harry(Viewport.Actor) != None && harry(Viewport.Actor).Cam != None )
	{
		harry(Viewport.Actor).Cam.iPathSeq++;
		LOGCLOSEPLACEHOLDER
	}
	if ( bCreatedRoot )
	{
		ConsoleWindow.HideWindow();
	}
'@
$newHide = $newHide -replace "`n", $nl -replace 'LOGCLOSEPLACEHOLDER', $logClose

$ok = $true
if ( $txt.Contains($oldShow) ) { $txt = $txt.Replace($oldShow, $newShow); Write-Output "ShowConsole patched" } else { Write-Output "SHOW PATTERN NOT FOUND"; $ok = $false }
if ( $txt.Contains($oldHide) ) { $txt = $txt.Replace($oldHide, $newHide); Write-Output "HideConsole patched" } else { Write-Output "HIDE PATTERN NOT FOUND"; $ok = $false }
if ( $ok ) {
    [System.IO.File]::WriteAllText($p, $txt, $enc)
    Write-Output "SAVED"
    exit 0
}
exit 2

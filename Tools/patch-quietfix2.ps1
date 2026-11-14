# Quiet-mode diagnostics + plain-grave guard fix. TEMPORARY ClientMessage logs
# (visible in the game's message overlay, screenshot-able) will be removed once
# the visibility issue is confirmed fixed. ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"

if ( $txt.Contains('v5.17.41.2') ) { Write-Output 'ALREADY PATCHED'; exit 0 }

# 1. plain-grave restore: fire whenever parked, not only while quiet is ON
$old = 'if ( bQuietConsole && bCreatedRoot && ConsoleWindow != None && ConsoleWindow.WinLeft < -5000.0 )'
if ( -not $txt.Contains($old) ) { Write-Output 'P1 NOT FOUND: plain guard'; exit 2 }
$new = 'if ( bCreatedRoot && ConsoleWindow != None && ConsoleWindow.WinLeft < -5000.0 )  // v5.17.41.2: restore even after a mid-session quiet OFF'
$txt = $txt.Replace($old, $new)

# 2. diagnostics: ClientMessage in park/restore branches + QuietConsole exec
$old = 'ConsoleWindow.WinLeft = -10000.0;'
if ( -not $txt.Contains($old) ) { Write-Output 'P2 NOT FOUND: park line'; exit 2 }
$new = 'ConsoleWindow.WinLeft = -10000.0;'
$first = $txt.IndexOf($old)
$lineStart = $txt.LastIndexOf("`n", $first) + 1
$indent = $txt.Substring($lineStart, $first - $lineStart)
$txt = $txt.Insert($first + $old.Length, $nl + $indent + 'if ( Viewport != None && Viewport.Actor != None ) Viewport.Actor.ClientMessage("DIAG: parked -10000");')

$old = 'ConsoleWindow.WinLeft = 10.0;' + $nl
$idx = $txt.IndexOf($old)
if ( $idx -lt 0 ) { Write-Output 'P3 NOT FOUND: restore line'; exit 2 }
$lineStart = $txt.LastIndexOf("`n", $idx) + 1
$indent = $txt.Substring($lineStart, $idx - $lineStart)
$txt = $txt.Insert($idx + $old.Length, $indent + 'if ( Viewport != None && Viewport.Actor != None ) Viewport.Actor.ClientMessage("DIAG: restored 10,10");' + $nl)

$old = 'else { bQuietConsole = False; }'
if ( -not $txt.Contains($old) ) { Write-Output 'P4 NOT FOUND: exec else'; exit 2 }
$new = 'else { bQuietConsole = False; }' + $nl +
       '  if ( Viewport != None && Viewport.Actor != None ) Viewport.Actor.ClientMessage("DIAG: QuietConsole="$int(bQuietConsole));'
$txt = $txt.Replace($old, $new)

[System.IO.File]::WriteAllText($p, $txt, $enc)
Write-Output 'QUIETFIX2 PATCHED (plain guard + DIAG messages)'
exit 0

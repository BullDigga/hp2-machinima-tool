# Remove the temporary DIAG ClientMessage lines (v5.17.41.2 diagnostics), keep
# the real plain-grave restore fix. ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"

if ( -not $txt.Contains('DIAG: parked') -and -not $txt.Contains('DIAG: QuietConsole') ) { Write-Output 'NO DIAG LINES'; exit 0 }

# 1. park diag
$old = $nl + 'if ( Viewport != None && Viewport.Actor != None ) Viewport.Actor.ClientMessage("DIAG: parked -10000");'
if ( $txt.Contains($old) ) { $txt = $txt.Replace($old, '') } else { Write-Output 'W1: park diag not found' }

# 2. restore diag
$old = $nl + 'if ( Viewport != None && Viewport.Actor != None ) Viewport.Actor.ClientMessage("DIAG: restored 10,10");'
if ( $txt.Contains($old) ) { $txt = $txt.Replace($old, '') } else { Write-Output 'W2: restore diag not found' }

# 3. exec diag (with its leading newline+spaces)
$old = $nl + '  if ( Viewport != None && Viewport.Actor != None ) Viewport.Actor.ClientMessage("DIAG: QuietConsole="$int(bQuietConsole));'
if ( $txt.Contains($old) ) { $txt = $txt.Replace($old, '') } else { Write-Output 'W3: exec diag not found' }

[System.IO.File]::WriteAllText($p, $txt, $enc)
Write-Output 'DIAG REMOVED'
exit 0

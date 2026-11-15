# Batch-file channel: HPConsole exec PanelRunBatch <file>. The panel writes
# System\<file> (one console command per line) and types ONE command instead of
# 100+ char-by-char lines - 70s of fragile typing silently lost keys at BOTH
# ends of an import (head race at console-open ate the first 2 keys, the tail
# lost the last one; user report: "imported 16 keys, the table has 8/13").
# ConsoleCommand bypasses the console line parser that truncates typed lines
# to the first token ("open Grounds_hub" lost its argument through it).
# Idempotent. ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$nl = "`r`n"

$txt = [System.IO.File]::ReadAllText($p, $enc)
if ( $txt.Contains('exec function PanelRunBatch') ) { Write-Output 'ALREADY PATCHED'; exit 0 }

$anchor = 'exec function Cam_Mode (string sInput)'
if ( -not $txt.Contains($anchor) ) { Write-Output 'ANCHOR NOT FOUND: Cam_Mode'; exit 2 }
$new = 'exec function PanelRunBatch (string sFile)' + $nl +
       '{' + $nl +
       '  // v5.17.43.5: batch-file channel. The panel writes System\<sFile> (one' + $nl +
       '  // console command per line) and types THIS single command instead of' + $nl +
       '  // 100+ char-by-char lines (70s typing silently lost keys at both ends' + $nl +
       '  // of an import). ConsoleCommand bypasses the console line parser that' + $nl +
       '  // truncates typed lines to the first token' + $nl +
       '  if ( Viewport != None && Viewport.Actor != None )' + $nl +
       '  {' + $nl +
       '    Viewport.Actor.ConsoleCommand("exec " $ sFile);' + $nl +
       '  }' + $nl +
       '}' + $nl + $nl +
       $anchor
$txt = $txt.Replace($anchor, $new)
[System.IO.File]::WriteAllText($p, $txt, $enc)
Write-Output 'PANELRUNBATCH ADDED'
exit 0

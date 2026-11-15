# Batch-file channel diagnostics v2: PanelRunBatch <file> now reports what it
# received and what ConsoleCommand("exec ...") returned - via ClientMessage
# (game overlay) AND a PATHEV DIAG event (panel trace). Replaces the v1 stub.
# Idempotent. ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$nl = "`r`n"

$txt = [System.IO.File]::ReadAllText($p, $enc)
if ( $txt.Contains('DIAG: batch=') ) { Write-Output 'DIAG VERSION ALREADY IN'; exit 0 }

$new = @'
exec function PanelRunBatch (string sFile)
{
  // v5.17.43.5: batch-file channel. The panel writes System\<sFile> (one
  // console command per line) and types THIS single command instead of
  // 100+ char-by-char lines (70s typing silently lost keys at both ends
  // of an import). ConsoleCommand bypasses the console line parser that
  // truncates typed lines to the first token.
  // v5.17.43.5.1: DIAG - report the received arg and the exec() result
  // (ClientMessage + PATHEV DIAG event) until the channel is verified
  local string r;
  if ( Viewport != None && Viewport.Actor != None )
  {
    r = Viewport.Actor.ConsoleCommand("exec " $ sFile);
    Viewport.Actor.ClientMessage("DIAG: batch=[" $ sFile $ "] res=[" $ r $ "]");
    harry(Viewport.Actor).Cam.iPathSeq++;
    Log("PATHEV:"$harry(Viewport.Actor).Cam.iPathGen$":"$harry(Viewport.Actor).Cam.iPathSeq$"|DIAG|res="$r);
  }
}
'@

$lines = [System.IO.File]::ReadAllLines($p, $enc)
$i0 = -1
for ( $i = 0; $i -lt $lines.Count; $i++ ) {
    if ( $lines[$i] -match '^exec function PanelRunBatch' ) { $i0 = $i; break }
}
if ( $i0 -lt 0 ) { Write-Output 'V1 FUNCTION NOT FOUND'; exit 2 }
# find the closing brace of the function: first line that is exactly '}'
$i1 = -1
for ( $i = $i0 + 1; $i -lt $lines.Count; $i++ ) {
    if ( $lines[$i].Trim() -eq '}' ) { $i1 = $i; break }
}
if ( $i1 -lt 0 ) { Write-Output 'CLOSING BRACE NOT FOUND'; exit 2 }
$before = $lines[0..($i0 - 1)]
$after = $lines[($i1 + 1)..($lines.Count - 1)]
$blockLines = $new -split "`r?`n"
$out = $before + $blockLines + $after
[System.IO.File]::WriteAllLines($p, $out, $enc)
Write-Output 'DIAG VERSION INSTALLED'
exit 0

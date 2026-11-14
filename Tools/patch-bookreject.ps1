# Book-open REJECT guard: the game refuses Cam commands while the menu-book is
# open (the panel's BOOK|1 knowledge can lag up to a scan). The game-side guard
# is the reliable layer: PathAdd and the packed setters check menuBook.bIsOpen
# and emit REJECTED|book instead of executing. Panel parses REJECTED -> warns.
# ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\BaseCam.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$t1 = "`t"
$t2 = "`t`t"

if ( $txt.Contains('v5.17.37.3') ) { Write-Output 'ALREADY PATCHED'; exit 0 }

# --- 1. BookBlocks helper + REJECT helper (before function PathSmoothStop's var area; anchor on packed helpers) ---
$old = 'function int PackedIdx(string s)'
if ( -not $txt.Contains($old) ) { Write-Output 'P1 NOT FOUND: PackedIdx'; exit 2 }
$new = '// v5.17.37.3: menu-book REJECT guard. The panel BOOK|1 knowledge can lag a' + $nl +
       '// scan - the game-side check is the reliable layer: with the book open,' + $nl +
       '// commands are refused with a REJECTED event instead of executing (a' + $nl +
       '// PathAdd in the book state would add a garbage keyframe at the FE camera)' + $nl +
       'function bool BookBlocks()' + $nl +
       '{' + $nl +
       $t1 + 'local HPConsole hc;' + $nl +
       $t1 + 'hc = HPConsole(PlayerHarry.Player.Console);' + $nl +
       $t1 + 'if ( hc != None && hc.menuBook != None && hc.menuBook.bIsOpen ) { return True; }' + $nl +
       $t1 + 'return False;' + $nl +
       '}' + $nl +
       $nl +
       'function RejectCmd(string kind)' + $nl +
       '{' + $nl +
       $t1 + 'iPathSeq++;' + $nl +
       $t1 + 'Log("PATHEV:"$iPathGen$":"$iPathSeq$"|REJECTED|"$kind);' + $nl +
       $t1 + 'PlayerHarry.ClientMessage("Path: menu-book is open - command NOT executed");' + $nl +
       '}' + $nl +
       $nl +
       $old
$txt = $txt.Replace($old, $new)

# --- 2. PathAddKey guard (the F8 "PathAdd" command lands here) ---
$old = 'function PathAddKey()' + $nl +
       '{' + $nl +
       $t1 + 'local PathKey K;'
if ( -not $txt.Contains($old) ) { Write-Output 'P2 NOT FOUND: PathAddKey head'; exit 2 }
$new = 'function PathAddKey()' + $nl +
       '{' + $nl +
       $t1 + 'local PathKey K;' + $nl +
       $t1 + 'if ( BookBlocks() ) { RejectCmd("book"); return; }'
$txt = $txt.Replace($old, $new)

# --- 3. packed setters guards ---
# SpeedSetPacked
$old = 'function SpeedSetPacked(string s)' + $nl +
       '{' + $nl +
       $t1 + 'local int i; local float v;' + $nl +
       $t1 + 'i = PackedIdx(s);'
if ( -not $txt.Contains($old) ) { Write-Output 'P3 NOT FOUND: SpeedSetPacked'; exit 2 }
$new = 'function SpeedSetPacked(string s)' + $nl +
       '{' + $nl +
       $t1 + 'local int i; local float v;' + $nl +
       $t1 + 'if ( BookBlocks() ) { RejectCmd("speed"); return; }' + $nl +
       $t1 + 'i = PackedIdx(s);'
$txt = $txt.Replace($old, $new)
$old = 'function FovSetPacked(string s)' + $nl +
       '{' + $nl +
       $t1 + 'local int i; local float v;' + $nl +
       $t1 + 'i = PackedIdx(s);'
if ( -not $txt.Contains($old) ) { Write-Output 'P4 NOT FOUND: FovSetPacked'; exit 2 }
$new = 'function FovSetPacked(string s)' + $nl +
       '{' + $nl +
       $t1 + 'local int i; local float v;' + $nl +
       $t1 + 'if ( BookBlocks() ) { RejectCmd("fov"); return; }' + $nl +
       $t1 + 'i = PackedIdx(s);'
$txt = $txt.Replace($old, $new)
$old = 'function HoldSetPacked(string s)' + $nl +
       '{' + $nl +
       $t1 + 'local int i; local float v;' + $nl +
       $t1 + 'i = PackedIdx(s);'
if ( -not $txt.Contains($old) ) { Write-Output 'P5 NOT FOUND: HoldSetPacked'; exit 2 }
$new = 'function HoldSetPacked(string s)' + $nl +
       '{' + $nl +
       $t1 + 'local int i; local float v;' + $nl +
       $t1 + 'if ( BookBlocks() ) { RejectCmd("hold"); return; }' + $nl +
       $t1 + 'i = PackedIdx(s);'
$txt = $txt.Replace($old, $new)

[System.IO.File]::WriteAllText($p, $txt, $enc)
Write-Output 'BOOKREJECT PATCHED (BookBlocks + REJECTED events)'
exit 0

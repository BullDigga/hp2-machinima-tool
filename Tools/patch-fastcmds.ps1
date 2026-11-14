# One-command packed setters: SpeedSet/FovSet/HoldSet take "idx:val" (M212
# console passes only the first argument; no spaces inside). Cuts a table edit
# from 3 typed commands (~3s) to ONE (~0.8s). float("123") cast is proven in
# PathImportIni. ASCII only.
$ErrorActionPreference = "Stop"
$enc = New-Object System.Text.UTF8Encoding($false)
$nl = "`r`n"
$t1 = "`t"
$t2 = "`t`t"

# ==================== BaseCam.uc ====================
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\BaseCam.uc'
$txt = [System.IO.File]::ReadAllText($p, $enc)
if ( $txt.Contains('v5.17.37') ) { Write-Output 'BASECAM ALREADY PATCHED'; exit 0 }

# --- 1. packed helpers + setters (after PathSmoothStop) ---
$old = 'function PathSmoothStop(int e)' + $nl +
       '{' + $nl +
       $t1 + 'bPathSmoothStop = (e != 0);' + $nl +
       $t1 + 'PlayerHarry.ClientMessage("Path: smoothstop " $ bPathSmoothStop);' + $nl +
       '}'
if ( -not $txt.Contains($old) ) { Write-Output 'P1 NOT FOUND: PathSmoothStop'; exit 2 }
$new = $old + $nl + $nl +
       '// v5.17.37: packed one-command setters ("idx:val"). One typed command per' + $nl +
       '// table edit instead of three staged ones (~0.8s vs ~3s)' + $nl +
       'function int PackedIdx(string s)' + $nl +
       '{' + $nl +
       $t1 + 'local int p;' + $nl +
       $t1 + 'p = InStr(s, ":");' + $nl +
       $t1 + 'if ( p <= 0 ) { return -1; }' + $nl +
       $t1 + 'return int(float(Left(s, p)));' + $nl +
       '}' + $nl +
       $nl +
       'function float PackedVal(string s)' + $nl +
       '{' + $nl +
       $t1 + 'local int p;' + $nl +
       $t1 + 'p = InStr(s, ":");' + $nl +
       $t1 + 'if ( p <= 0 ) { return 0.0; }' + $nl +
       $t1 + 'return float(Mid(s, p + 1));' + $nl +
       '}' + $nl +
       $nl +
       'function SpeedSetPacked(string s)' + $nl +
       '{' + $nl +
       $t1 + 'local int i; local float v;' + $nl +
       $t1 + 'i = PackedIdx(s);' + $nl +
       $t1 + 'if ( i < 0 || i >= PathKeys.Length ) { PlayerHarry.ClientMessage("Path: bad idx"); return; }' + $nl +
       $t1 + 'v = PackedVal(s);' + $nl +
       $t1 + 'if ( v <= 0.0 ) { PlayerHarry.ClientMessage("Path: bad speed"); return; }' + $nl +
       $t1 + 'PathKeys[i].fSpeed = v;' + $nl +
       $t1 + 'iPathSeq++;' + $nl +
       $t1 + 'Log("PATHEV:"$iPathGen$":"$iPathSeq$"|SPEED|"$i$","$string(v));' + $nl +
       $t1 + 'PlayerHarry.ClientMessage("Path: key "$i$" speed = "$v);' + $nl +
       '}' + $nl +
       $nl +
       'function FovSetPacked(string s)' + $nl +
       '{' + $nl +
       $t1 + 'local int i; local float v;' + $nl +
       $t1 + 'i = PackedIdx(s);' + $nl +
       $t1 + 'if ( i < 0 || i >= PathKeys.Length ) { PlayerHarry.ClientMessage("Path: bad idx"); return; }' + $nl +
       $t1 + 'v = PackedVal(s);' + $nl +
       $t1 + 'v = FClamp(v, 10.0, 170.0);' + $nl +
       $t1 + 'PathKeys[i].fFOV = v;' + $nl +
       $t1 + 'iPathSeq++;' + $nl +
       $t1 + 'Log("PATHEV:"$iPathGen$":"$iPathSeq$"|FOVKEY|"$i$","$string(v));' + $nl +
       $t1 + 'PlayerHarry.ClientMessage("Path: key "$i$" fov = "$v);' + $nl +
       '}' + $nl +
       $nl +
       'function HoldSetPacked(string s)' + $nl +
       '{' + $nl +
       $t1 + 'local int i; local float v;' + $nl +
       $t1 + 'i = PackedIdx(s);' + $nl +
       $t1 + 'if ( i < 0 || i >= PathKeys.Length ) { PlayerHarry.ClientMessage("Path: bad idx"); return; }' + $nl +
       $t1 + 'v = PackedVal(s);' + $nl +
       $t1 + 'v = FMax(0.0, v);' + $nl +
       $t1 + 'PathKeys[i].fHold = v;' + $nl +
       $t1 + 'iPathSeq++;' + $nl +
       $t1 + 'Log("PATHEV:"$iPathGen$":"$iPathSeq$"|KEYHOLD|"$i$","$string(v));' + $nl +
       $t1 + 'PlayerHarry.ClientMessage("Path: key "$i$" hold = "$v);' + $nl +
       '}'
$txt = $txt.Replace($old, $new)

[System.IO.File]::WriteAllText($p, $txt, $enc)
Write-Output 'BASECAM: packed setters patched'

# ==================== HPConsole.uc ====================
$p2 = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$txt2 = [System.IO.File]::ReadAllText($p2, $enc)
if ( $txt2.Contains('v5.17.37') ) { Write-Output 'HPCONSOLE ALREADY PATCHED'; exit 0 }
$old = 'exec function AddHoldVal(int v)' + $nl +
       '{' + $nl +
       '	harry(Viewport.Actor).Cam.StagedKey.fHold = float(v) / 10.0;' + $nl +
       '}'
if ( -not $txt2.Contains($old) ) { Write-Output 'P2 NOT FOUND: AddHoldVal'; exit 2 }
$new = $old + $nl + $nl +
       '// v5.17.37: packed one-command setters ("idx:val", no spaces - the M212' + $nl +
       '// console passes only the first argument). One typed command per edit' + $nl +
       'exec function SpeedSet(string s)' + $nl +
       '{' + $nl +
       '	harry(Viewport.Actor).Cam.SpeedSetPacked(s);' + $nl +
       '}' + $nl +
       $nl +
       'exec function FovSet(string s)' + $nl +
       '{' + $nl +
       '	harry(Viewport.Actor).Cam.FovSetPacked(s);' + $nl +
       '}' + $nl +
       $nl +
       'exec function HoldSet(string s)' + $nl +
       '{' + $nl +
       '	harry(Viewport.Actor).Cam.HoldSetPacked(s);' + $nl +
       '}'
$txt2 = $txt2.Replace($old, $new)
[System.IO.File]::WriteAllText($p2, $txt2, $enc)
Write-Output 'HPCONSOLE: packed execs patched'
exit 0

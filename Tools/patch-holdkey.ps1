# Issue #9: per-keyframe HOLD. New PathKey.fHold seconds: after arriving at key
# k the camera HOVERS there for fHold seconds (barely-perceptible sinusoidal
# drift, ~0.5u position / ~9 rotator units - issue #9 "едва-едва", NOT frozen).
# Timeline (TlKind/TlRef/TlDur) = hold entries interleaved with move segments,
# built by PathBuildTimeline at every play start; fTotalDur = moves + holds.
# Commands (M212 console = 1 argument only, tenths encoded):
#   AddHoldVal v    - staged key hold (panel import, before AddCommit)
#   HoldIdx i / HoldVal v / HoldApply - set hold of existing key (panel table)
#   -> PATHEV ...|KEYHOLD|i,seconds ; DUMP KEY lines get a 9th value.
# ASCII only. UC text in single-quoted PS strings.
$ErrorActionPreference = "Stop"
$enc = New-Object System.Text.UTF8Encoding($false)
$nl = "`r`n"
$t1 = "`t"
$t2 = "`t`t"
$t3 = "`t`t`t"
$t4 = "`t`t`t`t"

# ==================== BaseCam.uc ====================
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\BaseCam.uc'
$txt = [System.IO.File]::ReadAllText($p, $enc)

if ( $txt.Contains('v5.17.35 (#9)') ) { Write-Output 'BASECAM ALREADY PATCHED'; exit 0 }

# --- 1. PathKey struct: fHold ---
$old = '	var float fSpeed;' + $nl + '};' + $nl + 'var array<PathKey> PathKeys;'
if ( -not $txt.Contains($old) ) { Write-Output 'P1 NOT FOUND: PathKey struct'; exit 2 }
$new = '	var float fSpeed;' + $nl +
       '	var float fHold;    // v5.17.35 (#9): seconds the camera hovers at this key (0 = none)' + $nl +
       '};' + $nl + 'var array<PathKey> PathKeys;'
$txt = $txt.Replace($old, $new)

# --- 2. staging + timeline vars (before bPrevModeInit) ---
$old = 'var bool bPrevModeInit;'
if ( -not $txt.Contains($old) ) { Write-Output 'P2 NOT FOUND: bPrevModeInit'; exit 2 }
$new = 'var int iStagedHoldIdx;  // v5.17.35 (#9): staging for HoldIdx/HoldVal/HoldApply' + $nl +
       'var float fStagedHold;' + $nl +
       'var array<byte> TlKind;  // v5.17.35 (#9): timeline entry: 0 = move segment, 1 = hold at key' + $nl +
       'var array<int> TlRef;    // timeline: segment index (move) or key index (hold)' + $nl +
       'var array<float> TlDur;  // timeline entry durations' + $nl +
       $old
$txt = $txt.Replace($old, $new)

# --- 3. timeline builder + staged hold apply (after PathApplyStagedFov) ---
$old = 'function PathApplyStagedFov()' + $nl +
       '{' + $nl +
       $t1 + 'PathSetKeyFov(iStagedFovIdx, fStagedSpeed);' + $nl +
       '}'
if ( -not $txt.Contains($old) ) { Write-Output 'P3 NOT FOUND: PathApplyStagedFov'; exit 2 }
$new = $old + $nl + $nl +
       '// v5.17.35 (#9): staged hold set (multi-arg broken the same way as speed/fov)' + $nl +
       'function PathApplyStagedHold()' + $nl +
       '{' + $nl +
       $t1 + 'if ( iStagedHoldIdx < 0 || iStagedHoldIdx >= PathKeys.Length )' + $nl +
       $t1 + '{' + $nl +
       $t2 + 'PlayerHarry.ClientMessage("Path: bad index "$iStagedHoldIdx$" (have "$PathKeys.Length$")");' + $nl +
       $t2 + 'return;' + $nl +
       $t1 + '}' + $nl +
       $t1 + 'PathKeys[iStagedHoldIdx].fHold = FMax(0.0, fStagedHold);' + $nl +
       $t1 + 'iPathSeq++;' + $nl +
       $t1 + 'Log("PATHEV:"$iPathGen$":"$iPathSeq$"|KEYHOLD|"$iStagedHoldIdx$","$string(PathKeys[iStagedHoldIdx].fHold));' + $nl +
       $t1 + 'PlayerHarry.ClientMessage("Path: key "$iStagedHoldIdx$" hold = "$PathKeys[iStagedHoldIdx].fHold);' + $nl +
       '}' + $nl + $nl +
       '// v5.17.35 (#9): play timeline = hold entries interleaved with move segments.' + $nl +
       '// Hold[k] = seconds hovering at key k after arriving (key 0 = before the first' + $nl +
       '// move, last key = freeze-ish hover at the very end). fTotalDur = moves + holds' + $nl +
       'function TlAddEntry(byte kind, int refi, float dur)' + $nl +
       '{' + $nl +
       $t1 + 'TlKind[TlKind.Length] = kind;' + $nl +
       $t1 + 'TlRef[TlRef.Length] = refi;' + $nl +
       $t1 + 'TlDur[TlDur.Length] = dur;' + $nl +
       $t1 + 'fTotalDur += dur;' + $nl +
       '}' + $nl + $nl +
       'function PathBuildTimeline()' + $nl +
       '{' + $nl +
       $t1 + 'local int i;' + $nl +
       $t1 + 'TlKind.Remove(0, TlKind.Length);' + $nl +
       $t1 + 'TlRef.Remove(0, TlRef.Length);' + $nl +
       $t1 + 'TlDur.Remove(0, TlDur.Length);' + $nl +
       $t1 + 'fTotalDur = 0.0;' + $nl +
       $t1 + 'if ( PathKeys.Length < 2 )' + $nl +
       $t1 + '{' + $nl +
       $t2 + 'return;' + $nl +
       $t1 + '}' + $nl +
       $t1 + 'if ( PathKeys[0].fHold > 0.0 )' + $nl +
       $t1 + '{' + $nl +
       $t2 + 'TlAddEntry(1, 0, PathKeys[0].fHold);' + $nl +
       $t1 + '}' + $nl +
       $t1 + 'for ( i = 0; i < PathKeys.Length - 1; i++ )' + $nl +
       $t1 + '{' + $nl +
       $t2 + 'TlAddEntry(0, i, PathSegDur[i]);' + $nl +
       $t2 + 'if ( PathKeys[i+1].fHold > 0.0 )' + $nl +
       $t2 + '{' + $nl +
       $t3 + 'TlAddEntry(1, i+1, PathKeys[i+1].fHold);' + $nl +
       $t2 + '}' + $nl +
       $t1 + '}' + $nl +
       '}'
$txt = $txt.Replace($old, $new)

# --- 4. play starts: build the timeline (both play functions share the tail) ---
$old = $t1 + 'fPathElapsed = 0.0;' + $nl +
       $t1 + 'fPreFov = PlayerHarry.FovAngle;' + $nl +
       $t1 + "GotoState('StatePathPlaying');"
$cnt = ([regex]::Matches($txt, [regex]::Escape($old))).Count
if ( $cnt -ne 2 ) { Write-Output ('P4 UNEXPECTED COUNT: ' + $cnt); exit 2 }
$new = $t1 + 'PathBuildTimeline();' + $nl + $old
$txt = $txt.Replace($old, $new)

# --- 5. dump KEY lines: 9th value = hold ---
$old = $t2 + 's = s$","$string(K.rRot.Yaw)$","$string(K.rRot.Pitch)$","$string(K.fFOV)$","$string(K.fSpeed);'
if ( -not $txt.Contains($old) ) { Write-Output 'P5 NOT FOUND: dump key line'; exit 2 }
$new = $t2 + 's = s$","$string(K.rRot.Yaw)$","$string(K.rRot.Pitch)$","$string(K.fFOV)$","$string(K.fSpeed)$","$string(K.fHold);'
$txt = $txt.Replace($old, $new)

# --- 6. ini export: hold appended ---
$old = $t3 + '$ "," $ PathKeys[i].fFOV $ "," $ PathKeys[i].fSpeed;'
if ( -not $txt.Contains($old) ) { Write-Output 'P6 NOT FOUND: ini export'; exit 2 }
$new = $t3 + '$ "," $ PathKeys[i].fFOV $ "," $ PathKeys[i].fSpeed $ "," $ PathKeys[i].fHold;'
$txt = $txt.Replace($old, $new)

# --- 7. ini import: optional 8th value = hold ---
$old = $t3 + 'if ( i >= 0 )' + $nl +
       $t3 + '{' + $nl +
       $t4 + '// v3 format: ...,fov,speed' + $nl +
       $t4 + 'ffov = float(Left(sItem, i));' + $nl +
       $t4 + 'sItem = Mid(sItem, i + 1);' + $nl +
       $t4 + 'fspd = float(sItem);' + $nl +
       $t3 + '}'
if ( -not $txt.Contains($old) ) { Write-Output 'P7 NOT FOUND: ini import'; exit 2 }
$new = $t3 + 'if ( i >= 0 )' + $nl +
       $t3 + '{' + $nl +
       $t4 + '// v3/v4 format: ...,fov,speed[,hold]' + $nl +
       $t4 + 'ffov = float(Left(sItem, i));' + $nl +
       $t4 + 'sItem = Mid(sItem, i + 1);' + $nl +
       $t4 + 'i = InStr(sItem, ",");' + $nl +
       $t4 + 'if ( i >= 0 )' + $nl +
       $t4 + '{' + $nl +
       $t4 + $t1 + 'fspd = float(Left(sItem, i));' + $nl +
       $t4 + $t1 + 'K.fHold = FMax(0.0, float(Mid(sItem, i + 1)));' + $nl +
       $t4 + '}' + $nl +
       $t4 + 'else' + $nl +
       $t4 + '{' + $nl +
       $t4 + $t1 + 'fspd = float(sItem);' + $nl +
       $t4 + '}' + $nl +
       $t3 + '}'
$txt = $txt.Replace($old, $new)
if ( $txt.Contains('$t4') ) { Write-Output 'P7 BUG: unresolved variable'; exit 2 }

# --- 8. Tick locals ---
$old = $t2 + 'local float fT, fSeg, fU, fU2, fU3, fAcc;' + $nl + $t2 + 'local int i, i0, i3;'
if ( -not $txt.Contains($old) ) { Write-Output 'P8 NOT FOUND: Tick locals'; exit 2 }
$new = $t2 + 'local float fT, fSeg, fU, fU2, fU3, fAcc, fT2;' + $nl + $t2 + 'local int i, i0, i3, e;'
$txt = $txt.Replace($old, $new)

# --- 9. Tick: timeline walk + hover branch (span replace) ---
$orig = $t2 + 'fAcc = 0.0;' + $nl +
        $t2 + 'i = 0;' + $nl +
        $t2 + 'while ( i < PathSegDur.Length - 1 && fPathElapsed >= fAcc + PathSegDur[i] )' + $nl +
        $t2 + '{' + $nl +
        $t3 + 'fAcc += PathSegDur[i];' + $nl +
        $t3 + 'i++;' + $nl +
        $t2 + '}' + $nl
$endA = $t2 + 'i0 = i - 1;'
$start = $txt.IndexOf($orig)
$endIdx = $txt.IndexOf($endA)
if ( $start -lt 0 -or $endIdx -lt 0 -or $endIdx -le $start ) { Write-Output 'P9 SPAN NOT FOUND'; exit 2 }
$new = $t2 + '// v5.17.35 (#9): walk the timeline (holds interleaved with move segments).' + $nl +
       $t2 + '// During a hold the camera does NOT freeze: barely-perceptible sinusoidal' + $nl +
       $t2 + '// hover (position ~0.5u, rotation ~9 rotator units) - issue #9 "edve-edve"' + $nl +
       $t2 + 'fAcc = 0.0;' + $nl +
       $t2 + 'e = 0;' + $nl +
       $t2 + 'while ( e < TlDur.Length - 1 && fPathElapsed >= fAcc + TlDur[e] )' + $nl +
       $t2 + '{' + $nl +
       $t3 + 'fAcc += TlDur[e];' + $nl +
       $t3 + 'e++;' + $nl +
       $t2 + '}' + $nl +
       $t2 + 'if ( TlKind[e] == 1 )' + $nl +
       $t2 + '{' + $nl +
       $t3 + '// hover at key TlRef[e]: key pose + tiny drift' + $nl +
       $t3 + 'fT2 = fPathElapsed - fAcc;' + $nl +
       $t3 + 'vPos = PathKeys[TlRef[e]].vLoc;' + $nl +
       $t3 + 'vPos.X += 0.5 * Sin(fT2 * 1.7 + float(TlRef[e]) * 2.3);' + $nl +
       $t3 + 'vPos.Y += 0.5 * Cos(fT2 * 1.9 + float(TlRef[e]) * 1.1);' + $nl +
       $t3 + 'vPos.Z += 0.7 * Sin(fT2 * 1.3 + float(TlRef[e]) * 0.7);' + $nl +
       $t3 + 'rRot = PathKeys[TlRef[e]].rRot;' + $nl +
       $t3 + 'rRot.Yaw   += int(9.0 * Sin(fT2 * 1.1 + float(TlRef[e])));' + $nl +
       $t3 + 'rRot.Pitch += int(6.0 * Sin(fT2 * 1.5 + float(TlRef[e]) * 1.3));' + $nl +
       $t3 + 'rDestRotation = rRot;' + $nl +
       $t3 + 'rCurrRotation = rRot;' + $nl +
       $t3 + 'DesiredRotation = rRot;' + $nl +
       $t3 + 'SetRotation(rRot);' + $nl +
       $t3 + 'SetLocation(vPos);' + $nl +
       $t3 + 'vDestPosition = vPos;' + $nl +
       $t3 + 'vCurrPosition = vPos;' + $nl +
       $t3 + 'PlayerHarry.FovAngle = PathKeys[TlRef[e]].fFOV;' + $nl +
       $t2 + '}' + $nl +
       $t2 + 'else' + $nl +
       $t2 + '{' + $nl +
       $t2 + 'i = TlRef[e];' + $nl +
       $t2 + 'fU = (fPathElapsed - fAcc) / FMax(TlDur[e], 0.001);' + $nl +
       $t2 + 'fU = FMin(1.0, fU);' + $nl +
       $nl
$txt = $txt.Substring(0, $start) + $new + $txt.Substring($endIdx)

# --- 10. close the else after the FOV interpolation ---
$old = $t2 + '// FOV interpolation' + $nl +
       $t2 + 'PlayerHarry.FovAngle = PathKeys[i].fFOV' + $nl +
       $t3 + '+ (PathKeys[i+1].fFOV - PathKeys[i].fFOV) * fU;'
if ( -not $txt.Contains($old) ) { Write-Output 'P10 NOT FOUND: fov interpolation'; exit 2 }
$new = $old + $nl + $t2 + '}'
$txt = $txt.Replace($old, $new)

# --- 11. BeginState: timeline guard ---
$old = $t1 + 'function BeginState()' + $nl +
       $t1 + '{' + $nl +
       $t2 + 'fPathElapsed = 0.0;' + $nl +
       $t1 + '}'
if ( -not $txt.Contains($old) ) { Write-Output 'P11 NOT FOUND: BeginState'; exit 2 }
$new = $t1 + 'function BeginState()' + $nl +
       $t1 + '{' + $nl +
       $t2 + 'fPathElapsed = 0.0;' + $nl +
       $t2 + 'if ( TlDur.Length == 0 )' + $nl +
       $t2 + '{' + $nl +
       $t3 + 'PathBuildTimeline();' + $nl +
       $t2 + '}' + $nl +
       $t1 + '}'
$txt = $txt.Replace($old, $new)

[System.IO.File]::WriteAllText($p, $txt, $enc)
Write-Output 'BASECAM: hold key patched'

# ==================== HPConsole.uc ====================
$p2 = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$txt2 = [System.IO.File]::ReadAllText($p2, $enc)
if ( $txt2.Contains('v5.17.35 (#9)') ) { Write-Output 'HPCONSOLE ALREADY PATCHED'; exit 0 }
$old = 'exec function SpeedApply()' + $nl +
       '{' + $nl +
       '	harry(Viewport.Actor).Cam.PathApplyStagedSpeed();' + $nl +
       '}'
if ( -not $txt2.Contains($old) ) { Write-Output 'P12 NOT FOUND: SpeedApply'; exit 2 }
$new = $old + $nl + $nl +
       '// v5.17.35 (#9): staged hold set (seconds in TENTHS: HoldVal 15 = 1.5s).' + $nl +
       '// AddHoldVal sets the hold of the STAGED key (panel import, before AddCommit)' + $nl +
       'exec function HoldIdx(int v)' + $nl +
       '{' + $nl +
       '	harry(Viewport.Actor).Cam.iStagedHoldIdx = v;' + $nl +
       '}' + $nl +
       $nl +
       'exec function HoldVal(int v)' + $nl +
       '{' + $nl +
       '	harry(Viewport.Actor).Cam.fStagedHold = float(v) / 10.0;' + $nl +
       '}' + $nl +
       $nl +
       'exec function HoldApply()' + $nl +
       '{' + $nl +
       '	harry(Viewport.Actor).Cam.PathApplyStagedHold();' + $nl +
       '}' + $nl +
       $nl +
       'exec function AddHoldVal(int v)' + $nl +
       '{' + $nl +
       '	harry(Viewport.Actor).Cam.StagedKey.fHold = float(v) / 10.0;' + $nl +
       '}'
$txt2 = $txt2.Replace($old, $new)
[System.IO.File]::WriteAllText($p2, $txt2, $enc)
Write-Output 'HPCONSOLE: hold commands patched'
exit 0

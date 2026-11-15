# Issue #4: smooth rotations.
# Position already rides a Catmull-Rom spline (BaseCam StatePathPlaying Tick),
# but rotation used per-segment smoothstep -> rotation speed drops to ZERO at
# EVERY keyframe (the camera "pauses" its turn at each key on multi-key paths),
# and FOV did the same. Fix:
#   1) yaw/pitch/roll via the SAME Catmull-Rom over neighbors i-1..i+2, with
#      rotator wrap unwrapping (continuous angular velocity);
#   2) FOV on the same spline, clamped;
#   3) global ease-in/out (cosine) over the WHOLE path, toggle: PathEase 1/0
#      (panel checkbox CbPathEase; default ON via defaultproperties).
# ASCII only. UC text pieces are SINGLE-quoted PS strings (no interpolation).
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\BaseCam.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$t1 = "`t"
$t2 = "`t`t"
$t3 = "`t`t`t"

if ( $txt.Contains('v5.17.33 (#4)') ) { Write-Output 'ALREADY PATCHED'; exit 0 }

# --- 1. var ---
$old = 'var int iPathSeq;'
$new = 'var int iPathSeq;' + $nl +
       'var bool bPathEase;      // v5.17.33 (#4): global ease-in/out of the whole path (PathEase 1/0)'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: var iPathSeq'; exit 2 }
$txt = $txt.Replace($old, $new)

# --- 2. PathEase command (after PathStopPath) ---
$old = 'function PathStopPath()' + $nl +
       '{' + $nl +
       $t1 + 'if ( IsInState(' + "'" + 'StatePathPlaying' + "'" + ') )' + $nl +
       $t1 + '{' + $nl +
       $t2 + 'GotoState(' + "'" + 'StateFreeCam' + "'" + ');' + $nl +
       $t2 + 'PlayerHarry.ClientMessage("Path: stopped");' + $nl +
       $t1 + '}' + $nl +
       '}'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: PathStopPath'; exit 2 }
$new = $old + $nl + $nl +
       '// v5.17.33 (#4): global ease toggle (panel checkbox CbPathEase). The M212' + $nl +
       '// console passes ONLY the first argument - a single int is safe' + $nl +
       'function PathEase(int e)' + $nl +
       '{' + $nl +
       $t1 + 'bPathEase = (e != 0);' + $nl +
       $t1 + 'PlayerHarry.ClientMessage("Path: ease " $ bPathEase);' + $nl +
       '}'
$txt = $txt.Replace($old, $new)

# --- 3. Tick locals (add spline temporaries) ---
$old = $t2 + 'local float fT, fSeg, fU, fU2, fU3, fAcc;' + $nl +
       $t2 + 'local int i, i0, i3;' + $nl +
       $t2 + 'local vector vP0, vP1, vP2, vP3, vPos;' + $nl +
       $t2 + 'local rotator rRot;' + $nl +
       $t2 + 'local int dYaw, dPitch, dRoll;'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: Tick locals'; exit 2 }
$new = $t2 + 'local float fT, fSeg, fU, fU2, fU3, fAcc, fE;' + $nl +
       $t2 + 'local int i, i0, i3;' + $nl +
       $t2 + 'local vector vP0, vP1, vP2, vP3, vPos;' + $nl +
       $t2 + 'local rotator rRot;' + $nl +
       $t2 + 'local int dYaw, dPitch, dRoll;' + $nl +
       $t2 + 'local float fY0, fY1, fY2, fY3, fP0, fP1, fP2, fP3, fR0, fR1, fR2, fR3, fF0, fF1, fF2, fF3, fRes;'
$txt = $txt.Replace($old, $new)

# --- 4. global ease clock (before the segment lookup) ---
$old = $t2 + 'fAcc = 0.0;' + $nl +
       $t2 + 'i = 0;' + $nl +
       $t2 + 'while ( i < PathSegDur.Length - 1 && fPathElapsed >= fAcc + PathSegDur[i] )'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: segment lookup'; exit 2 }
$new = $t2 + '// v5.17.33 (#4): global ease-in/out over the WHOLE path (not per segment):' + $nl +
       $t2 + '// cosine ease redistributes path time - slow start, faster middle, slow' + $nl +
       $t2 + '// stop. fT is the eased clock; PLAYEND below still checks raw fPathElapsed' + $nl +
       $t2 + 'if ( bPathEase && fTotalDur > 0.0 )' + $nl +
       $t2 + '{' + $nl +
       $t3 + 'fE = fPathElapsed / fTotalDur;' + $nl +
       $t3 + 'if ( fE < 0.0 ) { fE = 0.0; }' + $nl +
       $t3 + 'if ( fE > 1.0 ) { fE = 1.0; }' + $nl +
       $t3 + 'fT = (0.5 - 0.5 * Cos(fE * 3.14159265)) * fTotalDur;' + $nl +
       $t2 + '}' + $nl +
       $t2 + 'else' + $nl +
       $t2 + '{' + $nl +
       $t3 + 'fT = fPathElapsed;' + $nl +
       $t2 + '}' + $nl +
       $t2 + 'fAcc = 0.0;' + $nl +
       $t2 + 'i = 0;' + $nl +
       $t2 + 'while ( i < PathSegDur.Length - 1 && fT >= fAcc + PathSegDur[i] )'
$txt = $txt.Replace($old, $new)

# --- 5. eased clock in fU computation ---
$old = $t3 + 'fU = (fPathElapsed - fAcc) / FMax(PathSegDur[i], 0.001);'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: fU computation'; exit 2 }
$new = $t3 + 'fU = (fT - fAcc) / FMax(PathSegDur[i], 0.001);'
$txt = $txt.Replace($old, $new)

# --- 6. rotation: Catmull-Rom with wrap unwrapping ---
$old = $t2 + '// smoothstep for rotation between keys' + $nl +
       $t2 + 'fU = fU * fU * (3.0 - 2.0 * fU);' + $nl +
       $nl +
       $t2 + 'dYaw   = PathKeys[i+1].rRot.Yaw   - PathKeys[i].rRot.Yaw;' + $nl +
       $t2 + 'dPitch = PathKeys[i+1].rRot.Pitch - PathKeys[i].rRot.Pitch;' + $nl +
       $t2 + 'dRoll  = PathKeys[i+1].rRot.Roll  - PathKeys[i].rRot.Roll;' + $nl +
       $t2 + 'dYaw   = ((dYaw   + 32768) & 65535) - 32768;' + $nl +
       $t2 + 'dPitch = ((dPitch + 32768) & 65535) - 32768;' + $nl +
       $t2 + 'dRoll  = ((dRoll  + 32768) & 65535) - 32768;' + $nl +
       $nl +
       $t2 + 'rRot.Yaw   = PathKeys[i].rRot.Yaw   + int(float(dYaw)   * fU);' + $nl +
       $t2 + 'rRot.Pitch = PathKeys[i].rRot.Pitch + int(float(dPitch) * fU);' + $nl +
       $t2 + 'rRot.Roll  = PathKeys[i].rRot.Roll  + int(float(dRoll)  * fU);'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: rotation block'; exit 2 }
$new = $t2 + '// v5.17.33 (#4): rotation via the SAME Catmull-Rom spline as position' + $nl +
       $t2 + '// (old per-segment smoothstep zeroed rotation speed at EVERY key - the' + $nl +
       $t2 + '// camera paused its turn at each keyframe). Rotators wrap at 32768, so' + $nl +
       $t2 + '// every neighbor is unwrapped around key i before splining' + $nl +
       $t2 + 'fY1 = float(PathKeys[i].rRot.Yaw);' + $nl +
       $t2 + 'dYaw = PathKeys[i+1].rRot.Yaw - PathKeys[i].rRot.Yaw;' + $nl +
       $t2 + 'dYaw = ((dYaw + 32768) & 65535) - 32768;' + $nl +
       $t2 + 'fY2 = fY1 + float(dYaw);' + $nl +
       $t2 + 'dYaw = PathKeys[i0].rRot.Yaw - PathKeys[i].rRot.Yaw;' + $nl +
       $t2 + 'dYaw = ((dYaw + 32768) & 65535) - 32768;' + $nl +
       $t2 + 'fY0 = fY1 + float(dYaw);' + $nl +
       $t2 + 'dYaw = PathKeys[i3].rRot.Yaw - PathKeys[i+1].rRot.Yaw;' + $nl +
       $t2 + 'dYaw = ((dYaw + 32768) & 65535) - 32768;' + $nl +
       $t2 + 'fY3 = fY2 + float(dYaw);' + $nl +
       $nl +
       $t2 + 'fP1 = float(PathKeys[i].rRot.Pitch);' + $nl +
       $t2 + 'dPitch = PathKeys[i+1].rRot.Pitch - PathKeys[i].rRot.Pitch;' + $nl +
       $t2 + 'dPitch = ((dPitch + 32768) & 65535) - 32768;' + $nl +
       $t2 + 'fP2 = fP1 + float(dPitch);' + $nl +
       $t2 + 'dPitch = PathKeys[i0].rRot.Pitch - PathKeys[i].rRot.Pitch;' + $nl +
       $t2 + 'dPitch = ((dPitch + 32768) & 65535) - 32768;' + $nl +
       $t2 + 'fP0 = fP1 + float(dPitch);' + $nl +
       $t2 + 'dPitch = PathKeys[i3].rRot.Pitch - PathKeys[i+1].rRot.Pitch;' + $nl +
       $t2 + 'dPitch = ((dPitch + 32768) & 65535) - 32768;' + $nl +
       $t2 + 'fP3 = fP2 + float(dPitch);' + $nl +
       $nl +
       $t2 + 'fR1 = float(PathKeys[i].rRot.Roll);' + $nl +
       $t2 + 'dRoll = PathKeys[i+1].rRot.Roll - PathKeys[i].rRot.Roll;' + $nl +
       $t2 + 'dRoll = ((dRoll + 32768) & 65535) - 32768;' + $nl +
       $t2 + 'fR2 = fR1 + float(dRoll);' + $nl +
       $t2 + 'dRoll = PathKeys[i0].rRot.Roll - PathKeys[i].rRot.Roll;' + $nl +
       $t2 + 'dRoll = ((dRoll + 32768) & 65535) - 32768;' + $nl +
       $t2 + 'fR0 = fR1 + float(dRoll);' + $nl +
       $t2 + 'dRoll = PathKeys[i3].rRot.Roll - PathKeys[i+1].rRot.Roll;' + $nl +
       $t2 + 'dRoll = ((dRoll + 32768) & 65535) - 32768;' + $nl +
       $t2 + 'fR3 = fR2 + float(dRoll);' + $nl +
       $nl +
       $t2 + 'fRes = (fY1 * 2.0' + $nl +
       $t3 + '+ (fY2 - fY0) * fU' + $nl +
       $t3 + '+ (fY0 * 2.0 - fY1 * 5.0 + fY2 * 4.0 - fY3) * fU2' + $nl +
       $t3 + '+ (fY3 - fY0 + fY1 * 3.0 - fY2 * 3.0) * fU3) * 0.5;' + $nl +
       $t2 + 'rRot.Yaw = int(fRes);' + $nl +
       $nl +
       $t2 + 'fRes = (fP1 * 2.0' + $nl +
       $t3 + '+ (fP2 - fP0) * fU' + $nl +
       $t3 + '+ (fP0 * 2.0 - fP1 * 5.0 + fP2 * 4.0 - fP3) * fU2' + $nl +
       $t3 + '+ (fP3 - fP0 + fP1 * 3.0 - fP2 * 3.0) * fU3) * 0.5;' + $nl +
       $t2 + 'rRot.Pitch = int(fRes);' + $nl +
       $nl +
       $t2 + 'fRes = (fR1 * 2.0' + $nl +
       $t3 + '+ (fR2 - fR0) * fU' + $nl +
       $t3 + '+ (fR0 * 2.0 - fR1 * 5.0 + fR2 * 4.0 - fR3) * fU2' + $nl +
       $t3 + '+ (fR3 - fR0 + fR1 * 3.0 - fR2 * 3.0) * fU3) * 0.5;' + $nl +
       $t2 + 'rRot.Roll = int(fRes);'
$txt = $txt.Replace($old, $new)

# --- 7. FOV: same spline, clamped ---
$old = $t2 + '// FOV interpolation' + $nl +
       $t2 + 'PlayerHarry.FovAngle = PathKeys[i].fFOV' + $nl +
       $t3 + '+ (PathKeys[i+1].fFOV - PathKeys[i].fFOV) * fU;'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: FOV block'; exit 2 }
$new = $t2 + '// v5.17.33 (#4): FOV on the same spline (no per-key stops), clamped' + $nl +
       $t2 + 'fF1 = PathKeys[i].fFOV;' + $nl +
       $t2 + 'fF2 = PathKeys[i+1].fFOV;' + $nl +
       $t2 + 'fF0 = PathKeys[i0].fFOV;' + $nl +
       $t2 + 'fF3 = PathKeys[i3].fFOV;' + $nl +
       $t2 + 'fRes = (fF1 * 2.0' + $nl +
       $t3 + '+ (fF2 - fF0) * fU' + $nl +
       $t3 + '+ (fF0 * 2.0 - fF1 * 5.0 + fF2 * 4.0 - fF3) * fU2' + $nl +
       $t3 + '+ (fF3 - fF0 + fF1 * 3.0 - fF2 * 3.0) * fU3) * 0.5;' + $nl +
       $t2 + 'PlayerHarry.FovAngle = FClamp(fRes, 10.0, 170.0);'
$txt = $txt.Replace($old, $new)

# --- 8. defaultproperties: ease ON by default ---
$old = '    bSyncPositionWithTarget=True'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: defaultproperties'; exit 2 }
$new = '    bSyncPositionWithTarget=True' + $nl + $nl + '    bPathEase=True'
$txt = $txt.Replace($old, $new)

[System.IO.File]::WriteAllText($p, $txt, $enc)
Write-Output 'SMOOTHROT PATCHED (rot+FOV catmull-rom, global PathEase)'
exit 0

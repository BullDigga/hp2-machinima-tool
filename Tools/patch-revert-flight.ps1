# Revert the whole #4 experiment (user verdict: mode switching not useful).
# Restores BaseCam.uc to the pre-experiment flight: per-segment smoothstep
# rotation, per-segment FOV, no global ease, no rotation modes. Removes
# bPathEase / iRotMode vars, PathEase / PathSetMode commands, ease clock.
# Keeps unrelated panel-side fixes (log-file guard, watchdogs). ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\BaseCam.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$t1 = "`t"
$t2 = "`t`t"
$t3 = "`t`t`t"

if ( -not $txt.Contains('v5.17.34 (#4)') ) { Write-Output 'NOTHING TO REVERT'; exit 0 }

# --- 1. vars out ---
$old = 'var bool bPathEase;      // v5.17.33 (#4): global ease-in/out of the whole path (PathEase 1/0)' + $nl
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: var bPathEase'; exit 2 }
$txt = $txt.Replace($old, '')
$old = 'var int iRotMode;       // v5.17.34 (#4): 0=classic smoothstep, 1=spline (default), 2=linear' + $nl
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: var iRotMode'; exit 2 }
$txt = $txt.Replace($old, '')

# --- 2. PathEase + PathSetMode functions out ---
$old = '// v5.17.33 (#4): global ease toggle (panel checkbox CbPathEase). The M212' + $nl +
       '// console passes ONLY the first argument - a single int is safe' + $nl +
       'function PathEase(int e)' + $nl +
       '{' + $nl +
       $t1 + 'bPathEase = (e != 0);' + $nl +
       $t1 + 'PlayerHarry.ClientMessage("Path: ease " $ bPathEase);' + $nl +
       '}' + $nl + $nl +
       '// v5.17.34 (#4): rotation mode + ease in ONE command (M212 console passes' + $nl +
       '// only the first argument). me = mode*10 + ease: 11 = spline+ease (default),' + $nl +
       '// 00 = classic raw, 20 = linear without ease' + $nl +
       'function PathSetMode(int me)' + $nl +
       '{' + $nl +
       $t1 + 'iRotMode = me / 10;' + $nl +
       $t1 + 'if ( iRotMode < 0 ) { iRotMode = 0; }' + $nl +
       $t1 + 'if ( iRotMode > 2 ) { iRotMode = 2; }' + $nl +
       $t1 + 'bPathEase = (me % 10) != 0;' + $nl +
       $t1 + 'PlayerHarry.ClientMessage("Path: rotmode " $ iRotMode $ ", ease " $ bPathEase);' + $nl +
       '}' + $nl + $nl
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: PathEase+PathSetMode'; exit 2 }
$txt = $txt.Replace($old, '')

# --- 3. Tick locals back to original ---
$old = $t2 + 'local float fT, fSeg, fU, fU2, fU3, fAcc, fE;' + $nl +
       $t2 + 'local int i, i0, i3;' + $nl +
       $t2 + 'local vector vP0, vP1, vP2, vP3, vPos;' + $nl +
       $t2 + 'local rotator rRot;' + $nl +
       $t2 + 'local int dYaw, dPitch, dRoll;' + $nl +
       $t2 + 'local float fY0, fY1, fY2, fY3, fP0, fP1, fP2, fP3, fR0, fR1, fR2, fR3, fF0, fF1, fF2, fF3, fRes;'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: Tick locals (new)'; exit 2 }
$new = $t2 + 'local float fT, fSeg, fU, fU2, fU3, fAcc;' + $nl +
       $t2 + 'local int i, i0, i3;' + $nl +
       $t2 + 'local vector vP0, vP1, vP2, vP3, vPos;' + $nl +
       $t2 + 'local rotator rRot;' + $nl +
       $t2 + 'local int dYaw, dPitch, dRoll;'
$txt = $txt.Replace($old, $new)

# --- 4. ease clock out (raw fPathElapsed back) ---
$old = $t2 + '// v5.17.33 (#4): global ease-in/out over the WHOLE path (not per segment):' + $nl +
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
       $t2 + '}' + $nl
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: ease clock'; exit 2 }
$txt = $txt.Replace($old, '')
$old = $t2 + 'while ( i < PathSegDur.Length - 1 && fT >= fAcc + PathSegDur[i] )'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: while fT'; exit 2 }
$txt = $txt.Replace($old, $t2 + 'while ( i < PathSegDur.Length - 1 && fPathElapsed >= fAcc + PathSegDur[i] )')
$old = $t3 + 'fU = (fT - fAcc) / FMax(PathSegDur[i], 0.001);'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: fU fT'; exit 2 }
$txt = $txt.Replace($old, $t3 + 'fU = (fPathElapsed - fAcc) / FMax(PathSegDur[i], 0.001);')

# --- 5. the whole mode-branch region back to the original smoothstep block ---
# Span: from "if ( iRotMode == 0 )" up to (exclusive) the LAST
# "if ( fPathElapsed >= fTotalDur )" (= the PLAYEND check after FOV).
# Restored text: original smoothstep rotation + rDestRotation/SetRotation lines
# + original linear FOV (in the file the FOV block sits AFTER SetRotation).
$orig = $t2 + '// smoothstep for rotation between keys' + $nl +
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
        $t2 + 'rRot.Roll  = PathKeys[i].rRot.Roll  + int(float(dRoll)  * fU);' + $nl +
        $nl +
        $t2 + 'rDestRotation = rRot;' + $nl +
        $t2 + 'rCurrRotation = rRot;' + $nl +
        $t2 + 'DesiredRotation = rRot;' + $nl +
        $t2 + 'SetRotation(rRot);' + $nl +
        $t2 + 'vDestPosition = vPos;' + $nl +
        $t2 + 'vCurrPosition = vPos;' + $nl +
        $nl +
        $t2 + '// FOV interpolation' + $nl +
        $t2 + 'PlayerHarry.FovAngle = PathKeys[i].fFOV' + $nl +
        $t3 + '+ (PathKeys[i+1].fFOV - PathKeys[i].fFOV) * fU;' + $nl +
        $nl
$start = $txt.IndexOf($t2 + 'if ( iRotMode == 0 )')
$endA  = $txt.LastIndexOf($t2 + 'if ( fPathElapsed >= fTotalDur )')
if ( $start -lt 0 -or $endA -lt 0 -or $endA -le $start ) { Write-Output 'SPAN NOT FOUND (mode branch / PLAYEND check)'; exit 2 }
$txt = $txt.Substring(0, $start) + $orig + $txt.Substring($endA)

# --- 6. defaultproperties entries out ---
$old = $nl + $nl + '    bPathEase=True' + $nl + $nl + '    iRotMode=1'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: defaultproperties'; exit 2 }
$txt = $txt.Replace($old, '')

[System.IO.File]::WriteAllText($p, $txt, $enc)
Write-Output 'FLIGHT REVERTED (original smoothstep rotation/FOV, no ease, no modes)'
exit 0

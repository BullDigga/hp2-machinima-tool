# Issue #4 step 2: selectable rotation modes (panel radio buttons).
#   0 = CLASSIC: pre-spline behavior - per-segment smoothstep, rotation stops
#       at every key (the old variant)
#   1 = SPLINE: Catmull-Rom rotation + FOV, continuous turn (current default)
#   2 = LINEAR: constant angular speed per segment, linear FOV (reference)
# Single command PathSetMode <mode*10 + ease> (M212 console passes only the
# first argument): "11" = spline+ease, "00" = classic raw. PathEase stays for
# manual console use. ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\BaseCam.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$t1 = "`t"
$t2 = "`t`t"
$t3 = "`t`t`t"
$t4 = "`t`t`t`t"

if ( $txt.Contains('v5.17.34 (#4)') ) { Write-Output 'ALREADY PATCHED'; exit 0 }

# --- 1. var ---
$old = 'var bool bPathEase;      // v5.17.33 (#4): global ease-in/out of the whole path (PathEase 1/0)'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: var bPathEase'; exit 2 }
$new = $old + $nl +
       'var int iRotMode;       // v5.17.34 (#4): 0=classic smoothstep, 1=spline (default), 2=linear'
$txt = $txt.Replace($old, $new)

# --- 2. PathSetMode command (after PathEase) ---
$old = '// v5.17.33 (#4): global ease toggle (panel checkbox CbPathEase). The M212' + $nl +
       '// console passes ONLY the first argument - a single int is safe' + $nl +
       'function PathEase(int e)' + $nl +
       '{' + $nl +
       $t1 + 'bPathEase = (e != 0);' + $nl +
       $t1 + 'PlayerHarry.ClientMessage("Path: ease " $ bPathEase);' + $nl +
       '}'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: PathEase'; exit 2 }
$new = $old + $nl + $nl +
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
       '}'
$txt = $txt.Replace($old, $new)

# --- 3. mode 0 (classic) branch opening + else before the spline block ---
$old = $t2 + '// v5.17.33 (#4): rotation via the SAME Catmull-Rom spline as position'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: spline comment'; exit 2 }
$new = $t2 + 'if ( iRotMode == 0 )' + $nl +
       $t2 + '{' + $nl +
       $t2 + $t1 + '// v5.17.34 mode 0 = CLASSIC (pre-spline behavior): per-segment' + $nl +
       $t2 + $t1 + '// smoothstep - rotation stops at every keyframe' + $nl +
       $t2 + $t1 + 'fU = fU * fU * (3.0 - 2.0 * fU);' + $nl +
       $t2 + $t1 + 'dYaw   = PathKeys[i+1].rRot.Yaw   - PathKeys[i].rRot.Yaw;' + $nl +
       $t2 + $t1 + 'dPitch = PathKeys[i+1].rRot.Pitch - PathKeys[i].rRot.Pitch;' + $nl +
       $t2 + $t1 + 'dRoll  = PathKeys[i+1].rRot.Roll  - PathKeys[i].rRot.Roll;' + $nl +
       $t2 + $t1 + 'dYaw   = ((dYaw   + 32768) & 65535) - 32768;' + $nl +
       $t2 + $t1 + 'dPitch = ((dPitch + 32768) & 65535) - 32768;' + $nl +
       $t2 + $t1 + 'dRoll  = ((dRoll  + 32768) & 65535) - 32768;' + $nl +
       $t2 + $t1 + 'rRot.Yaw   = PathKeys[i].rRot.Yaw   + int(float(dYaw)   * fU);' + $nl +
       $t2 + $t1 + 'rRot.Pitch = PathKeys[i].rRot.Pitch + int(float(dPitch) * fU);' + $nl +
       $t2 + $t1 + 'rRot.Roll  = PathKeys[i].rRot.Roll  + int(float(dRoll)  * fU);' + $nl +
       $t2 + $t1 + 'PlayerHarry.FovAngle = PathKeys[i].fFOV' + $nl +
       $t2 + $t1 + $t1 + '+ (PathKeys[i+1].fFOV - PathKeys[i].fFOV) * fU;' + $nl +
       $t2 + '}' + $nl +
       $t2 + 'else' + $nl +
       $t2 + '{' + $nl +
       $old
$txt = $txt.Replace($old, $new)

# --- 4. FOV keys up front (needed by BOTH mode 1 and mode 2), mode-2 branch ---
$old = $t2 + '// v5.17.33 (#4): FOV on the same spline (no per-key stops), clamped' + $nl +
       $t2 + 'fF1 = PathKeys[i].fFOV;' + $nl +
       $t2 + 'fF2 = PathKeys[i+1].fFOV;' + $nl +
       $t2 + 'fF0 = PathKeys[i0].fFOV;' + $nl +
       $t2 + 'fF3 = PathKeys[i3].fFOV;'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: fov keys'; exit 2 }
$new = $t2 + '// v5.17.34: FOV keys up front (mode 2 uses fF1/fF2, spline uses all four)' + $nl +
       $t2 + 'fF1 = PathKeys[i].fFOV;' + $nl +
       $t2 + 'fF2 = PathKeys[i+1].fFOV;' + $nl +
       $t2 + 'fF0 = PathKeys[i0].fFOV;' + $nl +
       $t2 + 'fF3 = PathKeys[i3].fFOV;' + $nl +
       $nl +
       $t2 + 'if ( iRotMode == 2 )' + $nl +
       $t2 + '{' + $nl +
       $t2 + $t1 + '// v5.17.34 mode 2 = LINEAR: constant angular speed per segment' + $nl +
       $t2 + $t1 + 'rRot.Yaw   = int(fY1 + (fY2 - fY1) * fU);' + $nl +
       $t2 + $t1 + 'rRot.Pitch = int(fP1 + (fP2 - fP1) * fU);' + $nl +
       $t2 + $t1 + 'rRot.Roll  = int(fR1 + (fR2 - fR1) * fU);' + $nl +
       $t2 + $t1 + 'PlayerHarry.FovAngle = FClamp(fF1 + (fF2 - fF1) * fU, 10.0, 170.0);' + $nl +
       $t2 + '}' + $nl +
       $t2 + 'else' + $nl +
       $t2 + '{' + $nl +
       $t2 + $t1 + '// v5.17.33 (#4): FOV on the same spline (no per-key stops), clamped'
$txt = $txt.Replace($old, $new)

# --- 5. close the two else-branches after the spline FOV ---
$old = $t2 + 'PlayerHarry.FovAngle = FClamp(fRes, 10.0, 170.0);'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: fov clamp'; exit 2 }
$new = $old + $nl + $t2 + '}' + $nl + $t2 + '}'
$txt = $txt.Replace($old, $new)

# --- 6. defaultproperties: spline mode default ---
$old = '    bPathEase=True'
if ( -not $txt.Contains($old) ) { Write-Output 'PATTERN NOT FOUND: defaultproperties'; exit 2 }
$new = '    bPathEase=True' + $nl + $nl + '    iRotMode=1'
$txt = $txt.Replace($old, $new)

[System.IO.File]::WriteAllText($p, $txt, $enc)
Write-Output 'ROTMODES PATCHED (0=classic, 1=spline, 2=linear; PathSetMode <mode*10+ease>)'
exit 0

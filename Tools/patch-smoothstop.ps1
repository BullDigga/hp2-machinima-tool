# Smooth start/stop of path playback (user: "резко-резко останавливается").
# The flight slams to a halt at the final keyframe (position velocity != 0 at
# the end) and jumps to full speed at the start. Fix: cosine ease on the
# timeline parameter of the FIRST move segment (ease-in, slow start) and the
# LAST move segment (ease-out, decelerate to zero at the final key). A 2-key
# path gets a full ease-in-out. Toggle: PathSmoothStop 1/0 (panel checkbox,
# default ON). Position spline, rotation and FOV all use the eased parameter.
# ASCII only.
$ErrorActionPreference = "Stop"
$p = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\BaseCam.uc'
$enc = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($p, $enc)
$nl = "`r`n"
$t1 = "`t"
$t2 = "`t`t"
$t3 = "`t`t`t"
$t4 = "`t`t`t`t"

if ( $txt.Contains('v5.17.36') ) { Write-Output 'ALREADY PATCHED'; exit 0 }

# --- 1. var ---
$old = 'var float fStagedHold;'
if ( -not $txt.Contains($old) ) { Write-Output 'P1 NOT FOUND: fStagedHold'; exit 2 }
$new = $old + $nl +
       'var bool bPathSmoothStop;  // v5.17.36: ease-in on the first segment, ease-out on the last (PathSmoothStop 1/0)'
$txt = $txt.Replace($old, $new)

# --- 2. command (after PathApplyStagedHold) ---
$old = $t1 + 'PlayerHarry.ClientMessage("Path: key "$iStagedHoldIdx$" hold = "$PathKeys[iStagedHoldIdx].fHold);' + $nl +
       '}'
if ( -not $txt.Contains($old) ) { Write-Output 'P2 NOT FOUND: PathApplyStagedHold tail'; exit 2 }
$new = $old + $nl + $nl +
       '// v5.17.36: smooth start/stop toggle (panel checkbox). The M212 console' + $nl +
       '// passes ONLY the first argument - a single int is safe' + $nl +
       'function PathSmoothStop(int e)' + $nl +
       '{' + $nl +
       $t1 + 'bPathSmoothStop = (e != 0);' + $nl +
       $t1 + 'PlayerHarry.ClientMessage("Path: smoothstop " $ bPathSmoothStop);' + $nl +
       '}'
$txt = $txt.Replace($old, $new)

# --- 3. Tick: ease the timeline parameter on edge segments ---
$old = $t2 + 'fU = (fPathElapsed - fAcc) / FMax(TlDur[e], 0.001);' + $nl +
       $t2 + 'fU = FMin(1.0, fU);'
if ( -not $txt.Contains($old) ) { Write-Output 'P3 NOT FOUND: fU computation'; exit 2 }
$new = $t2 + 'fU = (fPathElapsed - fAcc) / FMax(TlDur[e], 0.001);' + $nl +
       $t2 + 'fU = FMin(1.0, fU);' + $nl +
       $t2 + '// v5.17.36: smooth start/stop - ease the parameter on edge segments.' + $nl +
       $t2 + '// Position spline, rotation and FOV all read the eased value: the' + $nl +
       $t2 + '// camera accelerates from zero at key 0 and decelerates to zero at the' + $nl +
       '// final key (user: "rezko-rezko ostanavlivaetsya"). 2-key path: full' + $nl +
       '// ease-in-out. Toggle: PathSmoothStop 1/0 (bPathSmoothStop, default ON)' + $nl +
       $t2 + 'if ( bPathSmoothStop )' + $nl +
       $t2 + '{' + $nl +
       $t3 + 'if ( PathKeys.Length == 2 )' + $nl +
       $t3 + '{' + $nl +
       $t4 + 'fU = 0.5 - 0.5 * Cos(fU * 3.14159265);' + $nl +
       $t3 + '}' + $nl +
       $t3 + 'else if ( i == 0 )' + $nl +
       $t3 + '{' + $nl +
       $t4 + 'fU = 1.0 - Cos(fU * 1.5707963);' + $nl +
       $t3 + '}' + $nl +
       $t3 + 'else if ( i == PathKeys.Length - 2 )' + $nl +
       $t3 + '{' + $nl +
       $t4 + 'fU = Sin(fU * 1.5707963);' + $nl +
       $t3 + '}' + $nl +
       $t2 + '}'
$txt = $txt.Replace($old, $new)

# --- 4. defaultproperties: ON by default ---
$old = '    bSyncPositionWithTarget=True'
if ( -not $txt.Contains($old) ) { Write-Output 'P4 NOT FOUND: defaultproperties'; exit 2 }
$new = '    bSyncPositionWithTarget=True' + $nl + $nl + '    bPathSmoothStop=True'
$txt = $txt.Replace($old, $new)

[System.IO.File]::WriteAllText($p, $txt, $enc)
Write-Output 'SMOOTHSTOP PATCHED (ease-in first segment, ease-out last, PathSmoothStop 1/0)'
exit 0

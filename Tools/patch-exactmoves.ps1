# Issue #14: exact-direction free-cam keys. FINAL consolidated state (applied to
# the game sources in several passes; this script is idempotent and documents the
# complete change for fresh installs).
#   T = strictly UP  (was G)   G = strictly DOWN (was T)   <- swapped per user test
#   F = TURN camera left in place (yaw only, XYZ frozen)
#   H = TURN camera right in place
# Rotation rate = CurrentSet.fMoveSpeed * 6 (~20 deg/s at fly speed 600) so the
# panel's Fly speed setting scales turns, same as the T/G vertical moves.
# CRITICAL LESSON: Rotator.Yaw is an INT - adding fRotSpeed*dt (0.08/tick) was
# eaten by int truncation and the rotation silently did nothing; fMoveSpeed*6*dt
# (~57/tick) survives. Keys are panel-remappable: exec CamBindUp/Down/Left/Right.
# ASCII only.
$ErrorActionPreference = "Stop"
$enc = New-Object System.Text.UTF8Encoding($false)
$nl = [string][char]13 + [char]10
$t  = [char]9
$t2 = $t + $t
$t3 = $t2 + $t

# ---- 1. baseConsole.uc: flags + remappable bind vars ----
$p1 = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\baseConsole.uc'
$txt = [System.IO.File]::ReadAllText($p1, $enc)
if ( -not $txt.Contains('bExactUpKeyDown') ) {
    $old = 'var bool bRotateDownKeyDown;'
    if ( -not $txt.Contains($old) ) { Write-Output 'P1 FAIL'; exit 2 }
    $new = $old + $nl +
        '// v5.17.42 (#14): exact-direction moves; keys are panel-remappable (byte VK)' + $nl +
        'var bool bExactUpKeyDown;' + $nl +
        'var bool bExactDownKeyDown;' + $nl +
        'var bool bExactLeftKeyDown;' + $nl +
        'var bool bExactRightKeyDown;' + $nl +
        'var byte ExactUpKey;' + $nl +
        'var byte ExactDownKey;' + $nl +
        'var byte ExactLeftKey;' + $nl +
        'var byte ExactRightKey;'
    [System.IO.File]::WriteAllText($p1, $txt.Replace($old, $new), $enc)
    Write-Output 'baseConsole: vars added'
}

# ---- 2. HPConsole.uc: KeyEvent if-chain + bind execs + defaults ----
$p2 = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\Internal\HPConsole.uc'
$txt = [System.IO.File]::ReadAllText($p2, $enc)
if ( -not $txt.Contains('CamBindDown') ) {
    # 2a. if-chain right after "k = Key;" (the one followed by "switch (Action)")
    $lines = [System.IO.File]::ReadAllLines($p2, $enc)
    $sw = -1
    for ( $i = 0; $i -lt $lines.Count - 1; $i++ ) {
        if ( $lines[$i] -match '^\s+k = Key;\s*$' -and $lines[$i+1] -match '^\s+switch \(Action\)\s*$' ) { $sw = $i + 1; break }
    }
    if ( $sw -lt 0 ) { Write-Output 'P2 FAIL: no k=Key+switch pair'; exit 2 }
    $ins = @(
        $t + '// v5.17.42 (#14): exact-direction keys; switch cases cannot compare' + $nl,
        $t + '// against the remappable byte vars, so an if-chain instead' + $nl,
        $t + 'if ( Action == IST_Press )' + $nl,
        $t + '{' + $nl,
        $t2 + 'if ( int(k) == ExactUpKey ) { bExactUpKeyDown = True; }' + $nl,
        $t2 + 'if ( int(k) == ExactDownKey ) { bExactDownKeyDown = True; }' + $nl,
        $t2 + 'if ( int(k) == ExactLeftKey ) { bExactLeftKeyDown = True; }' + $nl,
        $t2 + 'if ( int(k) == ExactRightKey ) { bExactRightKeyDown = True; }' + $nl,
        $t + '}' + $nl,
        $t + 'else if ( Action == IST_Release )' + $nl,
        $t + '{' + $nl,
        $t2 + 'if ( int(k) == ExactUpKey ) { bExactUpKeyDown = False; }' + $nl,
        $t2 + 'if ( int(k) == ExactDownKey ) { bExactDownKeyDown = False; }' + $nl,
        $t2 + 'if ( int(k) == ExactLeftKey ) { bExactLeftKeyDown = False; }' + $nl,
        $t2 + 'if ( int(k) == ExactRightKey ) { bExactRightKeyDown = False; }' + $nl,
        $t + '}'
    )
    $lines = $lines[0..($sw-1)] + $ins + $lines[$sw..($lines.Count-1)]
    $txt = ($lines -join $nl) + $nl
    # 2b. bind execs before Cam_Mode
    $anchor = 'exec function Cam_Mode (string sInput)'
    if ( -not $txt.Contains($anchor) ) { Write-Output 'P2b FAIL'; exit 2 }
    $binds = 'exec function CamBindUp (byte bKey)' + $nl +
        '{' + $nl +
        '  // v5.17.42 (#14): panel remap of the exact-move keys (single arg)' + $nl +
        '  ExactUpKey = bKey;' + $nl +
        '}' + $nl + $nl +
        'exec function CamBindDown (byte bKey)' + $nl + '{' + $nl + '  ExactDownKey = bKey;' + $nl + '}' + $nl + $nl +
        'exec function CamBindLeft (byte bKey)' + $nl + '{' + $nl + '  ExactLeftKey = bKey;' + $nl + '}' + $nl + $nl +
        'exec function CamBindRight (byte bKey)' + $nl + '{' + $nl + '  ExactRightKey = bKey;' + $nl + '}' + $nl + $nl
    $txt = $txt.Replace($anchor, $binds + $anchor)
    # 2c. defaults (T=84 UP, G=71 DOWN - swapped per user test)
    $dp = 'defaultproperties' + $nl + '{'
    if ( -not $txt.Contains($dp) ) { Write-Output 'P2c FAIL'; exit 2 }
    $txt = $txt.Replace($dp, $dp + $nl +
        '    // v5.17.42.1 (#14): T=84 UP, G=71 DOWN (user swap); F=70/H=72 turn yaw' + $nl +
        '    ExactUpKey=84' + $nl +
        '    ExactDownKey=71' + $nl +
        '    ExactLeftKey=70' + $nl +
        '    ExactRightKey=72')
    [System.IO.File]::WriteAllText($p2, $txt, $enc)
    Write-Output 'HPConsole: chain + execs + defaults added'
}

# ---- 3. BaseCam.uc: StateFreeCam.Tick exact blocks ----
$p3 = 'F:\Harry Potter and the Chamber of Secrets\HGame\Classes\BaseCam.uc'
$txt = [System.IO.File]::ReadAllText($p3, $enc)
if ( -not $txt.Contains('bExactDownKeyDown') ) {
    # 3a. vertical T/G block after the vanilla bUp/bDown block
    $old = $t2 + 'if ( baseConsole(PlayerHarry.Player.Console).bUpKeyDown )' + $nl +
        $t2 + '{' + $nl +
        $t3 + 'vDestPosition += (vect(0.00,0.00,1.00) >> Rotation) * CurrentSet.fMoveSpeed * fTimeDelta;' + $nl +
        $t2 + '}' + $nl +
        $t2 + 'else if ( baseConsole(PlayerHarry.Player.Console).bDownKeyDown )' + $nl +
        $t2 + '{' + $nl +
        $t3 + 'vDestPosition += (vect(0.00,0.00,-1.00) >> Rotation) * CurrentSet.fMoveSpeed * fTimeDelta;' + $nl +
        $t2 + '}'
    if ( -not $txt.Contains($old) ) { Write-Output 'P3 FAIL: no bUp/bDown block'; exit 2 }
    $new = $old + $nl + $nl +
        $t2 + '// v5.17.42 (#14): exact moves. T/G = strictly vertical (world Z, independent' + $nl +
        $t2 + '// of camera pitch); F/H = TURN the camera in place (yaw only, XYZ frozen) -' + $nl +
        $t2 + '// the arrow keys move along the TILTED camera axes and drift height' + $nl +
        $t2 + 'if ( baseConsole(PlayerHarry.Player.Console).bExactDownKeyDown )' + $nl +
        $t2 + '{' + $nl +
        $t3 + 'vDestPosition.Z -= CurrentSet.fMoveSpeed * fTimeDelta;' + $nl +
        $t2 + '}' + $nl +
        $t2 + 'else if ( baseConsole(PlayerHarry.Player.Console).bExactUpKeyDown )' + $nl +
        $t2 + '{' + $nl +
        $t3 + 'vDestPosition.Z += CurrentSet.fMoveSpeed * fTimeDelta;' + $nl +
        $t2 + '}' + $nl +
        $t2 + 'if ( baseConsole(PlayerHarry.Player.Console).bExactLeftKeyDown || baseConsole(PlayerHarry.Player.Console).bExactRightKeyDown )' + $nl +
        $t2 + '{' + $nl +
        $t3 + '// v5.17.42.1: Rotator.Yaw is an INT - adding fRotSpeed*dt (0.08/tick) was' + $nl +
        $t3 + '// eaten by truncation and the rotation silently did nothing; rate =' + $nl +
        $t3 + '// fMoveSpeed * 6 (~20 deg/s at fly speed 600) tracks the FLY SPEED setting' + $nl +
        $t3 + 'if ( baseConsole(PlayerHarry.Player.Console).bExactLeftKeyDown )' + $nl +
        $t3 + '{' + $nl +
        $t3 + $t + 'rDestRotation.Yaw -= CurrentSet.fMoveSpeed * 6.0 * fTimeDelta;' + $nl +
        $t3 + '}' + $nl +
        $t3 + 'else' + $nl +
        $t3 + '{' + $nl +
        $t3 + $t + 'rDestRotation.Yaw += CurrentSet.fMoveSpeed * 6.0 * fTimeDelta;' + $nl +
        $t3 + '}' + $nl +
        $t2 + '}'
    $txt = $txt.Replace($old, $new)
    [System.IO.File]::WriteAllText($p3, $txt, $enc)
    Write-Output 'BaseCam: exact blocks added'
}
Write-Output 'EXACTMOVES PATCH APPLIED (idempotent)'
exit 0

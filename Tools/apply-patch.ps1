# apply-patch.ps1 — вставляет блок PathSystem перед defaultproperties в BaseCam.uc
# и exec-команды в конец HPConsole.uc (перед defaultproperties, если есть)

$ErrorActionPreference = "Stop"
$root = "C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Src\HP2UScriptDecompile\HGame\Classes"
$include = "C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Patches\PathSystem.include.uc"

$block = Get-Content $include -Raw

# --- BaseCam.uc ---
$f = Join-Path $root "BaseCam.uc"
$t = Get-Content $f -Raw
if ( $t -match 'Machinima camera path tool' )
{
    Write-Output "BaseCam.uc: already patched, skipping"
}
else
{
    $i = $t.IndexOf("defaultproperties")
    if ( $i -lt 0 ) { throw "defaultproperties not found in BaseCam.uc" }
    $t = $t.Insert($i, $block)
    Set-Content -Path $f -Value $t -Encoding ASCII
    Write-Output "BaseCam.uc: patched (block inserted at $i)"
}

# --- HPConsole.uc ---
$f2 = Join-Path $root "Internal\HPConsole.uc"
$t2 = Get-Content $f2 -Raw
if ( $t2 -match 'Machinima path tool' )
{
    Write-Output "HPConsole.uc: already patched, skipping"
}
else
{
$execBlock = @'

// ==================== Machinima path tool (BullDigga) ====================

exec function PathAdd()
{
	harry(Viewport.Actor).Camera.PathAddKey();
}

exec function PathClear()
{
	harry(Viewport.Actor).Camera.PathClearKeys();
}

exec function PathList()
{
	harry(Viewport.Actor).Camera.PathListKeys();
}

exec function PathPlay(float fSeconds)
{
	harry(Viewport.Actor).Camera.PathPlayPath(fSeconds);
}

exec function PathStop()
{
	harry(Viewport.Actor).Camera.PathStopPath();
}

// ==================== end machinima path tool ====================

'@
    # важно: у игрока (класс harry) переменная камеры называется Cam
    $execBlock = $execBlock -replace '\.Camera\.PathAddKey\(\)', '.Cam.PathAddKey()'
    $execBlock = $execBlock -replace '\.Camera\.PathClearKeys\(\)', '.Cam.PathClearKeys()'
    $execBlock = $execBlock -replace '\.Camera\.PathListKeys\(\)', '.Cam.PathListKeys()'
    $execBlock = $execBlock -replace '\.Camera\.PathPlayPath\(fSeconds\)', '.Cam.PathPlayPath(fSeconds)'
    $execBlock = $execBlock -replace '\.Camera\.PathStopPath\(\)', '.Cam.PathStopPath()'

    $j = $t2.IndexOf("defaultproperties")
    if ( $j -ge 0 )
    {
        $t2 = $t2.Insert($j, $execBlock)
    }
    else
    {
        $t2 = $t2 + $execBlock
    }
    Set-Content -Path $f2 -Value $t2 -Encoding ASCII
    Write-Output "HPConsole.uc: patched"
}

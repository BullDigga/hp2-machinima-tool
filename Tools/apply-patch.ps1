# apply-patch.ps1 v2 - inserts/replaces the PathSystem block in BaseCam.uc
# and the exec commands in HPConsole.uc (idempotent)

$ErrorActionPreference = "Stop"
$root = "C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Src\HP2UScriptDecompile\HGame\Classes"
$include = "C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Patches\PathSystem.include.uc"

$block = Get-Content $include -Raw
$decl = Get-Content "C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Patches\PathSystem.decl.uc" -Raw
$beginMark = "// ==================== Machinima camera path tool"
$endMark = "// ==================== end machinima camera path tool"
$endMark2 = "// ==================== end machinima camera path tool v2"

function Remove-OldBlock([string]$text) {
    # remove everything from begin marker to end marker (either version)
    $bi = $text.IndexOf($beginMark)
    while ( $bi -ge 0 )
    {
        $e1 = $text.IndexOf($endMark, $bi)
        $e2 = $text.IndexOf($endMark2, $bi)
        $e = -1
        if ( $e1 -ge 0 -and $e2 -ge 0 ) { $e = [Math]::Min($e1, $e2) }
        elseif ( $e2 -ge 0 ) { $e = $e2 }
        elseif ( $e1 -ge 0 ) { $e = $e1 }
        if ( $e -lt 0 ) { throw "begin marker found but no end marker" }
        $e = $text.IndexOf("`n", $e) + 1   # keep through end of the marker line
        $text = $text.Remove($bi, $e - $bi)
        $bi = $text.IndexOf($beginMark)
    }
    return $text
}

# --- BaseCam.uc ---
$f = Join-Path $root "BaseCam.uc"
$t = Get-Content $f -Raw
$t = Remove-OldBlock $t
# удалить старые объявления, если остались (idempotent)
$t = $t -replace "(?s)\r?\n// ==================== Machinima camera path tool v2 \(declarations\)\r?\n.*?var float fPathDuration;\r?\n\r?\n", "`r`n"
# объявления: struct + vars идут ПЕРЕД struct CamSettings (правило UC1: struct в начале класса)
if ( $t -notmatch "struct PathKey" )
{
    $j = $t.IndexOf("struct CamSettings")
    if ( $j -lt 0 ) { throw "struct CamSettings not found in BaseCam.uc" }
    $t = $t.Insert($j, $decl)
    Write-Output "BaseCam.uc: declarations inserted at $j"
}
# код: функции + стейт перед defaultproperties
$i = $t.IndexOf("defaultproperties")
if ( $i -lt 0 ) { throw "defaultproperties not found in BaseCam.uc" }
$t = $t.Insert($i, $block)
Set-Content -Path $f -Value $t -Encoding ASCII
Write-Output "BaseCam.uc: code block v2 installed"

# --- HPConsole.uc ---
$f2 = Join-Path $root "Internal\HPConsole.uc"
$t2 = Get-Content $f2 -Raw
$bi = $t2.IndexOf("// ==================== Machinima path tool")
if ( $bi -ge 0 )
{
    $e = $t2.IndexOf("// ==================== end machinima path tool", $bi)
    if ( $e -lt 0 ) { throw "HPConsole: end marker not found" }
    $e = $t2.IndexOf("`n", $e) + 1
    $t2 = $t2.Remove($bi, $e - $bi)
    Write-Output "HPConsole.uc: old execs removed"
}

$execBlock = @'
// ==================== Machinima path tool v2 (BullDigga) ====================

exec function PathAdd()
{
	harry(Viewport.Actor).Cam.PathAddKey();
}

exec function PathClear()
{
	harry(Viewport.Actor).Cam.PathClearKeys();
}

exec function PathList()
{
	harry(Viewport.Actor).Cam.PathListKeys();
}

exec function PathPlay(float fSeconds)
{
	harry(Viewport.Actor).Cam.PathPlayPath(fSeconds);
}

exec function PathStop()
{
	harry(Viewport.Actor).Cam.PathStopPath();
}

exec function PathDel(int iIndex)
{
	harry(Viewport.Actor).Cam.PathDeleteKey(iIndex);
}

exec function PathGoto(int iIndex)
{
	harry(Viewport.Actor).Cam.PathGotoKey(iIndex);
}

exec function PathSetKeySpeed(int iIndex, float fSpeed)
{
	harry(Viewport.Actor).Cam.PathSetKeySpeed(iIndex, fSpeed);
}

exec function PathPlaySpeed()
{
	harry(Viewport.Actor).Cam.PathPlaySpeedPath();
}

exec function PathSave()
{
	harry(Viewport.Actor).Cam.PathExportIni();
}

exec function PathLoad()
{
	harry(Viewport.Actor).Cam.PathImportIni();
}

// ==================== end machinima path tool v2 ====================

'@
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
Write-Output "HPConsole.uc: execs v2 installed"

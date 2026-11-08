# fix-struct.ps1 — переносит struct PathKey и var'ы в начало BaseCam.uc
$ErrorActionPreference = "Stop"
$f = "C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Src\HP2UScriptDecompile\HGame\Classes\BaseCam.uc"
$t = Get-Content $f -Raw

# 1) убрать struct+vars из хвостового блока (где они после стейтов)
$tailPattern = "(?s)struct PathKey\r?\n\{.*?\};\r?\n\r?\nvar array<PathKey> PathKeys;\r?\nvar float fPathElapsed;\r?\nvar float fPathDuration;\r?\n"
if ( $t -match $tailPattern )
{
    $t = $t -replace $tailPattern, ""
    Write-Output "removed tail struct/vars"
}
else
{
    Write-Output "tail struct/vars not found (already moved?)"
}

# 2) вставить struct ПЕРЕД struct CamSettings
$structBlock = "struct PathKey`r`n{`r`n`tvar vector vLoc;`r`n`tvar rotator rRot;`r`n};`r`n`r`n"
if ( $t -notmatch "struct PathKey" )
{
    $t = $t -replace "(struct CamSettings\r?\n\{)", ($structBlock + "`$1")
    Write-Output "struct inserted before CamSettings"
}

# 3) вставить vars после блока struct PathKey (перед struct CamSettings идут vars)
$varsBlock = "var array<PathKey> PathKeys;`r`nvar float fPathElapsed;`r`nvar float fPathDuration;`r`n`r`n"
if ( $t -notmatch "var array<PathKey>" )
{
    $t = $t -replace "(struct PathKey\r?\n\{\r?\n\tvar vector vLoc;\r?\n\tvar rotator rRot;\r?\n\};\r?\n)", ("`$1" + $varsBlock)
    Write-Output "vars inserted"
}

Set-Content -Path $f -Value $t -Encoding ASCII
Write-Output "done"

# fix-decl.ps1 - replaces old PathKey declaration block with v4 (fSpeed, PathSegDur, fTotalDur)
$old = @"
struct PathKey
{
	var vector vLoc;
	var rotator rRot;
	var float fFOV;
	var float fSpeed;
};

var array<PathKey> PathKeys;
var float fPathElapsed;
var float fPathDuration;
var config string SavedPathData;
"@
$new = @"
struct PathKey
{
	var vector vLoc;
	var rotator rRot;
	var float fFOV;
	var float fSpeed;
};

var array<PathKey> PathKeys;
var array<float> PathSegDur;
var float fPathElapsed;
var float fPathDuration;
var float fTotalDur;
var config string SavedPathData;
"@
foreach ($f in @(
    "F:\Harry Potter and the Chamber of Secrets\HGame\Classes\BaseCam.uc",
    "C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Src\HP2UScriptDecompile\HGame\Classes\BaseCam.uc"
)) {
    $t = Get-Content $f -Raw
    if ( $t -notmatch "var array<float> PathSegDur" ) {
        if ( $t.Contains($old) ) {
            $t = $t.Replace($old, $new)
            Set-Content $f $t -Encoding ASCII
            Write-Output "decl updated: $f"
        } else {
            # запасной вариант: вставить новые var после var float fPathDuration;
            $t = $t.Replace("var float fPathDuration;", "var float fPathDuration;`r`nvar array<float> PathSegDur;`r`nvar float fTotalDur;")
            if ( $t -notmatch "var float fSpeed;" ) {
                $t = $t.Replace("`tvar float fFOV;", "`tvar float fFOV;`r`n`tvar float fSpeed;")
            }
            Set-Content $f $t -Encoding ASCII
            Write-Output "decl patched (fallback): $f"
        }
    } else {
        Write-Output "already v4: $f"
    }
}

// ==================== Machinima camera path tool v2 (declarations) ====================

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



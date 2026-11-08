// ==================== Machinima camera path tool v2 (declarations) ====================

struct PathKey
{
	var vector vLoc;
	var rotator rRot;
	var float fFOV;
};

var array<PathKey> PathKeys;
var float fPathElapsed;
var float fPathDuration;
var config string SavedPathData;



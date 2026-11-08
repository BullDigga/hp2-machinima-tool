
// ==================== Machinima camera path tool v2 code (BullDigga / HP2 Machinima Tool) ====================

function PathAddKey()
{
	local PathKey K;
	K.vLoc = vCurrPosition;
	K.rRot = rCurrRotation;
	K.fFOV = PlayerHarry.FovAngle;
	PathKeys[PathKeys.Length] = K;
	PlayerHarry.ClientMessage("Path: key "$PathKeys.Length$" added");
}

function PathClearKeys()
{
	PathKeys.Remove(0, PathKeys.Length);
	PlayerHarry.ClientMessage("Path: all keys cleared");
}

function PathDeleteKey(int i)
{
	if ( i < 0 || i >= PathKeys.Length )
	{
		PlayerHarry.ClientMessage("Path: bad index "$i$" (have "$PathKeys.Length$")");
		return;
	}
	PathKeys.Remove(i, 1);
	PlayerHarry.ClientMessage("Path: key "$i$" removed ("$PathKeys.Length$" left)");
}

function PathGotoKey(int i)
{
	if ( i < 0 || i >= PathKeys.Length )
	{
		PlayerHarry.ClientMessage("Path: bad index "$i$" (have "$PathKeys.Length$")");
		return;
	}
	if ( IsInState('StatePathPlaying') )
	{
		GotoState('StateFreeCam');
	}
	vCurrPosition = PathKeys[i].vLoc;
	vDestPosition = PathKeys[i].vLoc;
	rCurrRotation = PathKeys[i].rRot;
	rDestRotation = PathKeys[i].rRot;
	DesiredRotation = rDestRotation;
	SetLocation(vCurrPosition);
	SetRotation(rCurrRotation);
	PlayerHarry.FovAngle = PathKeys[i].fFOV;
	if ( !IsInState('StateFreeCam') )
	{
		GotoState('StateFreeCam');
	}
	PlayerHarry.ClientMessage("Path: jumped to key "$i);
}

function PathListKeys()
{
	local int i;
	if ( PathKeys.Length == 0 )
	{
		PlayerHarry.ClientMessage("Path: no keys");
		return;
	}
	for ( i = 0; i < PathKeys.Length; i++ )
	{
		PlayerHarry.ClientMessage("Path key "$i$": "$string(PathKeys[i].vLoc)$" rot "$string(PathKeys[i].rRot)$" fov "$PathKeys[i].fFOV);
	}
}

function PathStopPath()
{
	if ( IsInState('StatePathPlaying') )
	{
		GotoState('StateFreeCam');
		PlayerHarry.ClientMessage("Path: stopped");
	}
}

function PathPlayPath(float fDuration)
{
	if ( PathKeys.Length < 2 )
	{
		PlayerHarry.ClientMessage("Path: need at least 2 keys (have "$PathKeys.Length$")");
		return;
	}
	if ( fDuration <= 0.0 )
	{
		fDuration = 10.0;
	}
	fPathDuration = fDuration;
	fPathElapsed = 0.0;
	GotoState('StatePathPlaying');
	PlayerHarry.ClientMessage("Path: playing "$fPathDuration$"s over "$PathKeys.Length$" keys");
}

// --- ini persistence (config string SavedPathData) ---

function PathExportIni()
{
	local int i;
	local string s;
	for ( i = 0; i < PathKeys.Length; i++ )
	{
		s = s $ PathKeys[i].vLoc.X $ "," $ PathKeys[i].vLoc.Y $ "," $ PathKeys[i].vLoc.Z
			$ "," $ PathKeys[i].rRot.Yaw $ "," $ PathKeys[i].rRot.Pitch
			$ "," $ PathKeys[i].fFOV;
		if ( i < PathKeys.Length - 1 )
		{
			s = s $ ";";
		}
	}
	SavedPathData = s;
	// пишем через class-defaults: static SaveConfig кладёт [HGame.BaseCam] в Default.ini
	Class'HGame.BaseCam'.default.SavedPathData = s;
	Class'HGame.BaseCam'.static.SaveConfig();
	PlayerHarry.ClientMessage("Path: exported "$PathKeys.Length$" keys to ini");
}

function PathImportIni()
{
	local string s, sItem;
	local int i, p;
	local PathKey K;
	local float fx, fy, fz, fyaw, fpitch, ffov;

	PathKeys.Remove(0, PathKeys.Length);
	s = SavedPathData;
	if ( s == "" )
	{
		s = Class'HGame.BaseCam'.default.SavedPathData;
	}
	if ( s == "" )
	{
		PlayerHarry.ClientMessage("Path: ini data is empty");
		return;
	}
	while ( true )
	{
		p = InStr(s, ";");
		if ( p >= 0 )
		{
			sItem = Left(s, p);
			s = Mid(s, p + 1);
		}
		else
		{
			sItem = s;
			s = "";
		}
		if ( sItem != "" )
		{
			i = InStr(sItem, ",");
			fx = float(Left(sItem, i));
			sItem = Mid(sItem, i + 1);
			i = InStr(sItem, ",");
			fy = float(Left(sItem, i));
			sItem = Mid(sItem, i + 1);
			i = InStr(sItem, ",");
			fz = float(Left(sItem, i));
			sItem = Mid(sItem, i + 1);
			i = InStr(sItem, ",");
			fyaw = float(Left(sItem, i));
			sItem = Mid(sItem, i + 1);
			i = InStr(sItem, ",");
			fpitch = float(Left(sItem, i));
			sItem = Mid(sItem, i + 1);
			ffov = float(sItem);

			K.vLoc.X = fx;
			K.vLoc.Y = fy;
			K.vLoc.Z = fz;
			K.rRot.Yaw = int(fyaw);
			K.rRot.Pitch = int(fpitch);
			K.fFOV = ffov;
			PathKeys[PathKeys.Length] = K;
		}
		if ( p < 0 )
		{
			break;
		}
	}
	PlayerHarry.ClientMessage("Path: imported "$PathKeys.Length$" keys from ini");
}

state StatePathPlaying
{
	ignores TakeDamage, SeePlayer, EnemyNotVisible, HearNoise, KilledBy, Trigger, Bump, HitWall, HeadZoneChange, FootZoneChange, ZoneChange, Falling, WarnTarget, Died, LongFall, PainTimer;

	function BeginState()
	{
		fPathElapsed = 0.0;
	}

	function Tick(float fTimeDelta)
	{
		local float fT, fSeg, fU, fU2, fU3;
		local int i, i0, i3;
		local vector vP0, vP1, vP2, vP3, vPos;
		local rotator rRot;
		local int dYaw, dPitch, dRoll;

		fPathElapsed += fTimeDelta;
		fT = FMin(1.0, fPathElapsed / fPathDuration);

		fSeg = fT * (PathKeys.Length - 1);
		i = int(fSeg);
		if ( i > PathKeys.Length - 2 )
		{
			i = PathKeys.Length - 2;
		}
		fU = fSeg - float(i);

		i0 = i - 1;
		if ( i0 < 0 )
		{
			i0 = 0;
		}
		i3 = i + 2;
		if ( i3 > PathKeys.Length - 1 )
		{
			i3 = PathKeys.Length - 1;
		}

		vP0 = PathKeys[i0].vLoc;
		vP1 = PathKeys[i].vLoc;
		vP2 = PathKeys[i+1].vLoc;
		vP3 = PathKeys[i3].vLoc;

		// Catmull-Rom spline through key positions
		fU2 = fU * fU;
		fU3 = fU2 * fU;
		vPos = (vP1 * 2.0
			+ (vP2 - vP0) * fU
			+ (vP0 * 2.0 - vP1 * 5.0 + vP2 * 4.0 - vP3) * fU2
			+ (vP3 - vP0 + vP1 * 3.0 - vP2 * 3.0) * fU3) * 0.5;

		SetLocation(vPos);

		// smoothstep for rotation between keys
		fU = fU * fU * (3.0 - 2.0 * fU);

		dYaw   = PathKeys[i+1].rRot.Yaw   - PathKeys[i].rRot.Yaw;
		dPitch = PathKeys[i+1].rRot.Pitch - PathKeys[i].rRot.Pitch;
		dRoll  = PathKeys[i+1].rRot.Roll  - PathKeys[i].rRot.Roll;
		dYaw   = ((dYaw   + 32768) & 65535) - 32768;
		dPitch = ((dPitch + 32768) & 65535) - 32768;
		dRoll  = ((dRoll  + 32768) & 65535) - 32768;

		rRot.Yaw   = PathKeys[i].rRot.Yaw   + int(float(dYaw)   * fU);
		rRot.Pitch = PathKeys[i].rRot.Pitch + int(float(dPitch) * fU);
		rRot.Roll  = PathKeys[i].rRot.Roll  + int(float(dRoll)  * fU);

		rDestRotation = rRot;
		rCurrRotation = rRot;
		DesiredRotation = rRot;
		SetRotation(rRot);
		vDestPosition = vPos;
		vCurrPosition = vPos;

		// FOV interpolation
		PlayerHarry.FovAngle = PathKeys[i].fFOV
			+ (PathKeys[i+1].fFOV - PathKeys[i].fFOV) * fU;

		if ( fT >= 1.0 )
		{
			GotoState('StateFreeCam');
		}
	}
}

// ==================== end machinima camera path tool v2 code ====================




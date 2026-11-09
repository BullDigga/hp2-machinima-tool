
// ==================== Machinima camera path tool v2 code (BullDigga / HP2 Machinima Tool) ====================

function PathAddKey()
{
	local PathKey K;
	K.vLoc = vCurrPosition;
	K.rRot = rCurrRotation;
	K.fFOV = PlayerHarry.FovAngle;
	K.fSpeed = CurrentSet.fMoveSpeed;
	if ( K.fSpeed <= 0.0 )
	{
		K.fSpeed = 250.0;
	}
	PathKeys[PathKeys.Length] = K;
	Log("PATHADD:"$string(K.vLoc.X)$","$string(K.vLoc.Y)$","$string(K.vLoc.Z)$","$string(K.rRot.Yaw)$","$string(K.rRot.Pitch)$","$string(K.fFOV)$","$string(K.fSpeed));
	PlayerHarry.ClientMessage("Path: key "$PathKeys.Length$" added");
}

function PathClearKeys()
{
	PathKeys.Remove(0, PathKeys.Length);
	Log("PATHCLEAR");
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
	Log("PATHDEL:"$i);
	PlayerHarry.ClientMessage("Path: key "$i$" removed ("$PathKeys.Length$" left)");
}

function PathSetKeySpeed(int i, float s)
{
	if ( i < 0 || i >= PathKeys.Length )
	{
		PlayerHarry.ClientMessage("Path: bad index "$i$" (have "$PathKeys.Length$")");
		return;
	}
	if ( s <= 0.0 )
	{
		PlayerHarry.ClientMessage("Path: speed must be > 0");
		return;
	}
	PathKeys[i].fSpeed = s;
	Log("PATHSPEED:"$i$","$string(s));
	PlayerHarry.ClientMessage("Path: key "$i$" speed = "$s);
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
	local int i;
	local float even;
	if ( PathKeys.Length < 2 )
	{
		PlayerHarry.ClientMessage("Path: need at least 2 keys (have "$PathKeys.Length$")");
		return;
	}
	if ( fDuration <= 0.0 )
	{
		fDuration = 10.0;
	}
	// равномерные сегменты
	PathSegDur.Remove(0, PathSegDur.Length);
	even = fDuration / (PathKeys.Length - 1);
	for ( i = 0; i < PathKeys.Length - 1; i++ )
	{
		PathSegDur[PathSegDur.Length] = even;
	}
	fTotalDur = fDuration;
	fPathElapsed = 0.0;
	GotoState('StatePathPlaying');
	PlayerHarry.ClientMessage("Path: playing "$fTotalDur$"s over "$PathKeys.Length$" keys");
}

// проигрывание с скоростью каждого сегмента (из fSpeed кейфреймов)
function PathPlaySpeedPath()
{
	local int i;
	local float seg, sp, dur;
	if ( PathKeys.Length < 2 )
	{
		PlayerHarry.ClientMessage("Path: need at least 2 keys (have "$PathKeys.Length$")");
		return;
	}
	PathSegDur.Remove(0, PathSegDur.Length);
	fTotalDur = 0.0;
	for ( i = 0; i < PathKeys.Length - 1; i++ )
	{
		seg = VSize(PathKeys[i+1].vLoc - PathKeys[i].vLoc);
		sp = PathKeys[i].fSpeed;
		if ( sp <= 0.0 )
		{
			sp = 250.0;
		}
		dur = seg / sp;
		if ( dur < 0.05 )
		{
			dur = 0.05;
		}
		PathSegDur[PathSegDur.Length] = dur;
		fTotalDur += dur;
	}
	fPathElapsed = 0.0;
	GotoState('StatePathPlaying');
	PlayerHarry.ClientMessage("Path: playing "$fTotalDur$"s (speed mode) over "$PathKeys.Length$" keys");
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
	// default-объект хранит данные, SaveConfig от instance пишет их в Default.ini
	Class'HGame.BaseCam'.default.SavedPathData = s;
	SaveConfig();
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
		local float fT, fSeg, fU, fU2, fU3, fAcc;
		local int i, i0, i3;
		local vector vP0, vP1, vP2, vP3, vPos;
		local rotator rRot;
		local int dYaw, dPitch, dRoll;

		fPathElapsed += fTimeDelta;

		// найти текущий сегмент по накопленному времени (per-segment длительности)
		fAcc = 0.0;
		i = 0;
		while ( i < PathSegDur.Length - 1 && fPathElapsed >= fAcc + PathSegDur[i] )
		{
			fAcc += PathSegDur[i];
			i++;
		}
		if ( fPathElapsed >= fTotalDur )
		{
			// финал: встать точно на последний кадр
			i = PathKeys.Length - 2;
			fU = 1.0;
		}
		else
		{
			fU = (fPathElapsed - fAcc) / FMax(PathSegDur[i], 0.001);
			fU = FMin(1.0, fU);
		}

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

		if ( fPathElapsed >= fTotalDur )
		{
			GotoState('StateFreeCam');
		}
	}
}

// ==================== end machinima camera path tool v2 code ====================




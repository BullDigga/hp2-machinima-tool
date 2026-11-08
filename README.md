# HP2 Machinima Tool

A free-camera keyframe path tool for **Harry Potter and the Chamber of Secrets** (PC), built on top of [Metallicafan212's HP2 Engine / Extended Mod](https://discord.gg/2HG6Q7Ypau).

Fly your camera anywhere in the castle, drop keyframes along the way, then play the whole flight back as a smooth, engine-interpolated spline — perfect for recording machinima with OBS.

Inspired by the WoW Machinima Tool.

## ✅ Working now

- **Camera path system** (UnrealScript, compiled into `HGame.u`):
  - `PathAdd` — drop a keyframe (position + rotation) at the current free-camera pose
  - `PathPlay <seconds>` — the camera glides along a Catmull-Rom spline through all
    keyframes, interpolated **inside the engine every tick** (zero input jitter)
  - `PathStop`, `PathClear`, `PathList`
- **Free camera controls** (M212 engine): `Cam_Mode 9` detaches the camera;
  arrow keys fly it, WASD still moves Harry. `Cam_Mode 3` returns to the follow camera.
- **Control panel** (`Panel/`) — a tiny always-on-top WPF window with buttons
  (Add Keyframe / Play / Stop / List / Clear / HideHud / QuickLoad). It finds the
  game window, opens the console, types the command and closes the console —
  you never touch the keyboard.

## Requirements

- Harry Potter and the Chamber of Secrets with **M212 Engine v3.4A+** (HP2 Extended)
- Windows 10/11 x64

## Install (patched HGame.u)

1. Back up `system/HGame.u`.
2. Copy the decomp folders (`HGame/`, `HPModels/`, `HPParticle/`, `HProps/`,
   `HPSounds/`) from [HP2UScriptDecompile](https://github.com/metallicafan212/HP2UScriptDecompile)
   (branch `Scaling-Patch`) next to the game's `system/` folder.
3. Apply the patch: run `Tools/apply-patch.ps1` against those folders
   (it inserts the path system into `BaseCam.uc` and the console execs into
   `HPConsole.uc`).
4. Run `system/compile-machinima.bat` **as administrator** — it deletes the stale
   `HGame.u` (important: UCC carries over old compiled classes otherwise) and
   rebuilds from sources.

Stock `*.u` backups go to `system/*.u.stock.bak` — rename to restore.

## Usage

1. Launch the game, load a level.
2. Console (`` ` ``): `HideHud`, `Cam_Mode 9`.
3. Start `Panel/Start Panel.bat` (or use the console directly).
4. Fly the camera (arrow keys), click **ADD KEYFRAME** at each pose.
5. Set seconds, click **PLAY** — camera flies the spline; record with OBS.

Full details: [Docs/USAGE.md](Docs/USAGE.md). Roadmap: [Docs/ROADMAP.md](Docs/ROADMAP.md).

## Console commands

| Command | Description |
|---|---|
| `PathAdd` | Add a keyframe at the current free-camera pose |
| `PathList` | Print all keyframes (position + rotation) |
| `PathClear` | Remove all keyframes |
| `PathPlay <seconds>` | Fly the path over `<seconds>` |
| `PathStop` | Stop a playing path |
| `HideHud` | Hide the HUD / lightning overlay |
| `Cam_Mode 9` / `Cam_Mode 3` | Free camera / standard follow camera |
| `SloMo 0.5` | Slow the whole world down |
| `QuickSave` / `QuickLoad` | Reset the scene between takes |

## Known limitations

- Keyframes live in memory only (cleared on level change); ini persistence is planned.
- Flying outside the level geometry renders washed-out zones — stay inside.

## Credits

- **Metallicafan212** — HP2 Engine/Editor, decompiled HGame sources
- **AdamJD & the HP2 modding community** — camera system (StateFreeCam, Cam_* commands)
- **BullDigga** — project author

## License

[MIT](LICENSE)

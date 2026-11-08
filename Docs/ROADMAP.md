# Roadmap

## Phase 1 — In-engine camera path (current)

1. **Locate the camera class** in the HGame decomp (the object behind
   `harry(Viewport.Actor).Cam` — owns `StateFreeCam`, `ECamMode`, `CamSet*` structs).
2. **Add keyframe storage**: `struct PathKey { vector Loc; rotator Rot; float FOV; }`,
   `array<PathKey> PathKeys` on the camera class.
3. **Exec commands** (on the player controller, next to the existing `Cam_*` execs):
   - `PathAdd` — capture current free-cam view location/rotation into `PathKeys`
   - `PathRemoveLast`, `PathClear`, `PathList`
   - `PathPlay <float totalSeconds>` — enter a new camera state that walks the
     keyframes each tick using Catmull-Rom interpolation (position) and
     quaternion/rotator lerp (rotation); supports per-key hold times later
   - `PathSpeed <float>` / `PathStop`
   - `PathSave <name>` / `PathLoad <name>` — persist paths to an ini
     (`SaveConfig`-style or custom `IniFile` writes)
4. **Rebuild HGame.u** with M212's UCC, install into the game `system/`,
   smoke-test in the Entry Hall.

## Phase 2 — Control panel

- Small WPF app (single exe) that sends console commands via SendInput:
  buttons *Add Keyframe / Play / Stop / Clear*, duration slider, path list.
- Reads the game log to display keyframe coordinates after each `PathAdd`.

## Phase 3 — Nice-to-haves

- Per-keyframe duration (ease-in/ease-out per segment)
- Look-at targets instead of raw rotation
- FOV keyframing (dolly zoom)
- Export path to a `.txt` for sharing

## Known constraints

- Keyframes capture the **free camera** view — use `Cam_Mode 9` (or M212 debug fly)
  before dropping keys.
- The game must run with the patched `HGame.u`; keep a backup of the stock one.

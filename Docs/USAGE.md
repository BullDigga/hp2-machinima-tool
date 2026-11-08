# Usage Guide

## Quick start

1. Launch the game, load into any level.
2. Open the console with **` (backquote)** and run:

```
HideHud        (optional) hides the HUD and the lightning overlay
Cam_Mode 9     detach the camera (FreeCam)
```

3. Fly the camera with **arrow keys** (WASD still moves Harry — keep him
   out of shot or use him as an actor).
4. At each camera position you like, open the console and run:

```
PathAdd        drop a keyframe (position + rotation)
```

5. Add at least 2 keyframes (3+ recommended for the spline to curve).
6. Play the flight:

```
PathPlay 15    fly the whole path in 15 seconds
PathStop       abort mid-flight
```

The camera glides along a Catmull-Rom spline (positions) with smoothstepped
rotation between keyframes, interpolated inside the engine every tick —
record it with OBS while it plays.

## Commands

| Command | Description |
|---|---|
| `PathAdd` | Add a keyframe at the current free-camera pose |
| `PathList` | Print all keyframes (position + rotation) |
| `PathClear` | Remove all keyframes |
| `PathPlay <seconds>` | Fly the path over `<seconds>` |
| `PathStop` | Stop a playing path |

## Handy extras

| Command | Description |
|---|---|
| `HideHud` | Hide the HUD / lightning overlay |
| `Cam_Mode 9` / `Cam_Mode 3` | Free camera / standard follow camera |
| `SloMo 0.5` | Slow the whole world down (filmic motion) |
| `Invisible 1` | Hide Harry |
| `QuickSave` / `QuickLoad` | Reset the scene between takes |

## Tips

- Fly slowly when adding keyframes: close keys = tight curve, far keys = long glides.
- 3+ keyframes make the spline curve; with exactly 2 you get a straight glide.
- The camera returns to FreeCam when the path ends, staying at the last keyframe.
- Avoid flying outside the level geometry — unloaded zones render washed out.
- Keyframes currently live in memory only (cleared on level change); ini
  persistence is planned.

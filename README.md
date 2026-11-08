# HP2 Machinima Tool

A free-camera keyframe path tool for **Harry Potter and the Chamber of Secrets** (PC), built on top of [Metallicafan212's HP2 Engine / Extended Mod](https://discord.gg/2HG6Q7Ypau).

Fly your camera anywhere in the castle, drop keyframes along the way, then play the whole flight back as a smooth, engine-interpolated spline — perfect for recording machinima with OBS.

Inspired by the WoW Machinima Tool.

## Features (planned)

- ✈️ Free-fly camera (M212 engine debug fly)
- 📍 `PathAdd` — drop a keyframe (position + rotation + FOV) at any moment
- 🎬 `PathPlay <seconds>` — camera flies along a Catmull-Rom spline through all keyframes, interpolated **inside the engine** (every tick, zero input jitter)
- ⏱️ Adjustable total duration / flight speed
- 💾 `PathSave <name>` / `PathLoad <name>` — persist flight paths to config
- 🧹 `PathClear`, `PathList`
- 🖥️ Optional control panel (small window app) that drives the console commands

## Status

🚧 Work in progress. See [Docs/ROADMAP.md](Docs/ROADMAP.md).

## Requirements

- Harry Potter and the Chamber of Secrets with **M212 Engine v3.4A+** (HP2 Extended)
- The HP2 HGame decomp project (for building the modified `HGame.u`)
- Windows 10/11 x64

## Build & Install

*TBD — see ROADMAP.*

## Usage

*TBD — see ROADMAP.*

## Credits

- **Metallicafan212** — HP2 Engine/Editor, decompiled HGame sources
- **AdamJD & the HP2 modding community** — camera system (StateFreeCam, Cam_* commands)
- **BullDigga** — project author

## License

[MIT](LICENSE)

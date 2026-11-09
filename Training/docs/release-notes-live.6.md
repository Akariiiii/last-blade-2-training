# Last Blade 2 Live Training v0.1.0-live.6

## Changes

- **Display → Lightweight HUD** keeps timing and damage visible while reducing
  drawing work. The repeated 240-frame probe used 1,680 draw calls instead of
  15,162 with the full HUD. Measurements still update every emulated frame.
- Paused redraws reuse the last snapshot. Observation hooks stay registered
  across character and stage changes.
- **Display → Throw boxes** shows the spacing band for ground throws and the
  target-origin bounds for air throws at the native check frame. Throw whiffs
  show startup, total duration, and recovery.
- **Display → Jump / wakeup timing** adds jump startup and get-up or roll timing.
  When a roll has no observed native hurtbox, the HUD displays **No hurtbox seen**.
- **Actions → Stage for next match** applies the selected stage when you return
  to character select with **Alt+1**. **Auto** uses the game's choice.

## Install or update

Extract the ZIP and replace the entire **Training** folder. In standalone
offline Fightcade FBNeo, load `Training/lastblade2-training.lua`. Supply your own
Last Blade 2 ROM and Neo Geo BIOS.

## Validation

The extracted package passes 568 Lua assertions in 11 suites and syntax checks
for all 27 Lua files. The original-ROM feedback audit passed 24 scoped checks,
including normal and command throw hits and whiffs, one air throw whiff, two
Lee roll directions, and four stage selections. The release changes only the
revision string after this audit.

The hidden-window runs did not reproduce the reported cumulative slowdown.
Foreground FPS and successful air throw coverage remain open. Lightweight HUD
reduces overlay drawing while FBNeo continues to render the stage.

See `docs/VALIDATION.md` in the ZIP for evidence and coverage.

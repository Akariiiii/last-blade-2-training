# Last Blade 2 Live Training v0.1.0-live.5

Ground recovery controls for the dummy, with recovery before wakeup counter.

## Changes

- **Dummy → Ground recovery:** Off (default), Roll forward or Roll backward.
- **Recovery frequency:** Always (default), or Random with a 50% recovery chance
  chosen once per knockdown. The chosen direction follows P2's current facing.
- With **Counter trigger → After wakeup**, the dummy attempts recovery first,
  then counters when grounded control returns. Counter delay starts there.
- Recovery Off and Random skips suppress guard directions while down, preventing
  held-back guard from accidentally selecting a roll.
- Menu, Manual P2 and dummy recording/playback suspend the recovery policy.
- Recovery sends native direction inputs only; the game retains its recovery
  restrictions. No actor state or ROM patches are used to force a recovery.

## Install or update

Extract the ZIP and replace the **entire Training folder**. In standalone offline
Fightcade FBNeo, load `Training/lastblade2-training.lua`. Supply your own Last
Blade 2 ROM and Neo Geo BIOS. The same Lua package is used on Windows and macOS
through Wine. Configure recovery under **Start → Dummy**.

Normal use creates no log or recording files. This package includes Lua source,
pure tests, documentation and the MIT license; no ROM, BIOS, emulator, savestate,
recordings or private diagnostic data are included.

## Validation and limits

- 536 pure assertions across 11 Lua 5.1 suites; all 27 Lua files syntax-checked.
- Ground recovery: 14 original-ROM cases, with 68 checks passing in a separate
  audit of unchanged native RAM traces. The original harness FAIL receipt is
  preserved: its attack-entry hook omitted low roll scripts and it incorrectly
  classified the tested command throw as unrollable.
- Packaging changes only the profile revision from live.4 to live.5 after those
  native runs; all other runtime Lua bytes match the tested recovery snapshot.
- This is scoped recovery validation, not a full final-source release rerun,
  all-character or balance-mod certification. No completely unrollable hard-
  knockdown move was identified in this bounded pass. Native refusal remains
  authoritative. Air recovery is outside this feature.
- Foreground FPS and native Windows UI acceptance remain pending. Persistent
  recordings, rewind and position reset remain outside this package.

See `docs/VALIDATION.md` for the full evidence boundaries.

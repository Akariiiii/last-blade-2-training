# Training feature comparison and acceptance boundary

Reviewed2026-10-20 against the [official 3rd_training_lua README](https://github.com/Grouflon/3rd_training_lua/blob/master/README.md), especially Main features and the v0.3–v0.10 changelog. This is a comparison of behavior and scope. This project uses original Last Blade2 logic/code; no 3rd Strike Lua, frame tables, recordings or artwork were copied.

“Implemented” below means present in this Lua package. Unit tests are not emulator or all-character acceptance. Features being integrated must be checked in FBNeo before claiming parity.

| Reference feature | Last Blade2 implementation / status |
|---|---|
| Eight recording slots | Implemented module: eight in-memory slots, each capped at3,600 frames. Coin×2 arms recording; P1 controls P2 in standby/recording. Coin starts/stops recording/replay. Eleven-frame single/double distinction matches the reference. Replay controls P2. |
| Repeated/random recordings | Once, repeat-slot, weighted random, ordered-once and repeated-ordered transports. Explicit inter-clip neutral gap, default1 frame; zero gap can be selected. |
| Recording as a reaction | Recorder API permits an explicit playback trigger. Automatic reaction-to-recording integration is not certified by the recorder module itself. |
| Round timer | Infinite time defaults On: native clock held at60 with INF label. Toggle Off resumes normal countdown. |
| P2 HP recovery | Defaults On,60f no-contact wait; configurable30–300f. Waits until the attempt/contact recovery is complete. No KO revival. |
| Menu accessibility / transitions | Focusable tab header uses A/Left/Right; C/D shortcuts remain. Turbo only for loading transitions, released before selection/combat and on stop/load/timeout. |
| Reset-position / custom scenario saves | Not implemented; use normal emulator savestates for setups. |
| Save/load recording files | Not provided by the recorder. Explicit `export_slot`/`import_slot` copy validated in-memory data; no automatic persistence or file picker. |
| First-frame counterattack | Dummy action attempts are separate from native admission proof. There is no claim of an exact legal first frame for every move, recovery, block, deflect or wake-up. |
| Collision and input display | Native attack/hurt/push observations and both input histories exist. Grab range is a native predicate reference, not a universal strike-style throw rectangle. |
| Parry/red-parry drills | 3rd Strike mechanics do not directly map to Last Blade2 deflect. No claim of the reference drill's full equivalent. |
| Gauges, damage and advantage | Native HP/meter/stun and observed damage/timing are available. Control-ready advantage is conditional; it does not certify every defensive action at that frame. |
| Character selection/hidden characters | Lua load / Alt+1 returns to native selection. P1 controls P1 character, P2 character, P1 mode, P2 mode, with release barriers. Native hidden/EX input paths remain; every hidden recipe is not certified. |
| Charge/mash-specific practice | No dedicated character-specific charge/mash success trainer. Recording can reproduce held/tapped inputs without inventing charge thresholds. |
| State-load handling | Stop/reset transport and partial measurements when the app handles a load/discontinuity; slots remain in Lua memory. This does not restore recordings across script restarts. |
| Menu and presentation | Last Blade2-specific menus/overlays. Similar function does not imply pixel-for-pixel UI equivalence. |

## Recorder API

`require("lb2.recorder").new({max_frames=3600, rng=optional_function})` constructs a passive recorder. No constructor, normal tick or menu change writes files, captures screenshots or touches game RAM.

- `start_record(slot, true)` records P1 controller input while driving P2, normalized against P2 facing. `start_record(slot)` retains the legacy P1-only API. Either overwrites only that slot and records subsequent ticks. At the frame cap it stops automatically. `stop()` stops transport without clearing slots/settings and queues a neutral P2 release if playback owned input.
- `start_playback({slot=1, mode="once"})` or `{slots={1,2}, mode="ordered", gap_frames=1}` starts transport. Random/ordered modes use enabled nonempty slots by default. Repeat-slot uses the selected slot. Empty selection returns an error and does not start.
- `tick({physical_p1={left=true, buttons="A"}, p1_facing=1, engine=42})` is pure transport. Facing1 means forward is physical Right; other facing values mean forward is Left. Each recorded frame stores back/forward relative to P1's current facing. `input={direction="6", buttons="A"}` may instead supply an already-relative sample. Optional engine IDs suppress repeated paused-frame advancement.
- `before(frame, keys)` is the FBNeo key adapter. Dummy recording routes physical P1 to P2 with P1 neutral; legacy recording samples P1. Playback uses P2's current facing. It returns `keys, active, request`; inactive operation leaves all keys unchanged. Active playback and the final release replace only P2 directions, A/B/C/D and Start. Simultaneous opposite directions are preserved in the actual replay flags, even though their text label normalizes to5.
- `items()` and `change(key,delta)` support the Recording menu. Stop on opening the menu/reset; skip transport ticks while navigating. Record dummy arms standby; Coin begins recording after closing. Play starts after closing/release. Start also opens/closes the menu.
- `clear(slot)` affects only that slot, stopping incompatible active transport first. `reset()` stops/releases while preserving slot contents. Explicit data import validates the dense frame array, direction flags, buttons and frame limit before changing a slot.

Playback measures real input time, including neutral and held-button frames. It does not skip hitpause, force character state, restore positions, promise identical outcomes after a side change, or automatically rewind game state. Replaying commands with different resources, target states, modes or spacing can select different game behavior. A one-frame release is deliberate after stop/end; inter-clip gaps are configurable independently.

## Current checks

`lua Training/tests/recorder.lua` currently passes57 assertions covering passivity, exact frame limits, facing transforms, simultaneous directions, P1 preservation, P2 release, paused-frame deduplication, ordered/repeat/random behavior, weighted selection, bad RNG output, slot isolation and bounded import/export. Native menu record/close/play/release has executed in FBNeo with exact held-button/direction checks; see the repository validation notes for the native-check scope. This is bounded acceptance, not all-character or all-transport-mode native certification.

## Deflect boundary

The tested standing D response is distinguished from ordinary block only after
both native reactions are observed: defender125/126 and source52/53 (hex). A D
press, zero damage or the broad guard predicate alone does not prove success.
Other low/air/character-specific deflect routes are not universally classified.
The dummy now sends one two-frame D pulse per interaction and releases it;
repeated D edges could otherwise invoke the game's follow-up attack.

Live.3 rendering: outline collision boxes by default, optional filled interiors,
clipped/deduplicated drawing and compressed phase strips. Full observation stays
at every emulated frame. Foreground FPS remains configuration-dependent.

Live.4 stun display distinguishes native depletion, prime window and dizzy; the
internal capacity reset does not falsely empty a primed gauge. Block counters
re-arm per contact, offer bounded retries until native admission and provide a
Switch before counter option. No universal first-frame counter claim.

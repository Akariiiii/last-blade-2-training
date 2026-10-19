# Last Blade 2 Live Training

An emulator-side training overlay for **Fightcade FBNeo + Last Blade 2**.
Version **0.1.0-live.4**, experimental. The saved Frame Lab viewer remains separate.

The game renders its own sprites. Normal use stores bounded measurements in RAM
and writes **no recording files, screenshots or per-frame logs**.

## Run

1. Extract the **entire `Training` folder** anywhere accessible to FBNeo. Keep
   `lastblade2-training.lua` and `lb2/` together.
2. Open Last Blade 2 in Fightcade's **standalone offline FBNeo**. You supply
   the ROM and Neo Geo BIOS.
3. Choose **Game → Lua Scripting → New Lua Script Window** and load
   **`lastblade2-training.lua`**. The script returns to native character select.
4. Use **P1 directions + A** to select **P1 character → P2 character → P1 mode →
   P2 mode**. Release buttons between confirmations. The game requires both
   characters before either mode; hidden/EX selections retain native inputs.
5. Once the native introductions finish, P1 controls your character and P2 is
   an idle dummy. Open the GUI with **Alt+2**. It opens on the tab header:
   **Left/Right or A changes tabs**, Down enters options, Up returns to the header.
   Left/Right/A changes an option, and B closes. Menu-closing buttons are released
   before gameplay or recording resumes.

P1 **Start** opens/closes the menu immediately; its input is consumed so the
menu press does not start a native taunt. Alt+2 remains an alternate shortcut. Native character-select countdown
is held while selecting; no ROM bytes or packaged savestates are used. Returning
to select and entering battle automatically use FBNeo turbo. Interactive
character/mode selection and combat use normal speed. Stop, state load and
selection timeout release turbo. **Actions → Fast transitions** disables this.
The speedup affects host pacing/rendering; CPU percentage is not changed.

On macOS, use the FBNeo included with Fightcade under Wine. Its file picker can
reach a macOS path through `Z:\Users\…`. This Lua package contains no emulator.
Loading this script does not change your emulator's window or volume settings.
Use windowed mode and set emulator volume to zero if you want muted practice.

Map FBNeo's Lua hotkeys as preferred:

| Lua hotkey | Action |
|---|---|
| 1 / Alt+1 | Return to character select |
| 2 / Alt+2 | Open / close GUI |
| 3 / Alt+3 | Collision boxes |
| 4 / Alt+4 | Statistics HUD |
| 5 / Alt+5 | Clear measurements / stop transport |

These are FBNeo's default Lua hotkey bindings; remap them in your emulator if
needed. GUI tabs: **Display, Dummy, Resources, Actions, Recording**. Display
options include input-history length, timeline/details, background opacity and
HUD position offsets. **C/D are game buttons**, using your FBNeo mappings;
they are optional tab shortcuts, not necessarily keyboard letters C and D.

Use the emulator's **Pause / Frame Advance** controls to inspect one emulated
frame at a time. Redrawing a paused frame does not add measurement frames. Menu
navigation does not itself pause the game. Backward stepping is deferred; in-memory input replay is available below.

## Display

- Red attack boxes, green hurtboxes, blue pushboxes, including registered owned
  projectile collision. Pre-response native rectangles preserve shapes that the
  game clears during contact handling.
- Origin-to-origin distance in game units. The purple ground-grab reference uses
  reviewed character/mode limits and target allowances. It extends toward the
  current target; it is **not** a centered total-width box. Passing distance alone
  does not prove throw eligibility, facing admission or immunity status.
- Stun-depletion bars below each native HP bar, with used/capacity values.
  Actual HP, meter and stun remaining/capacity. The move statistic uses the
  selected native stun operand; gauge depletion can differ when the game primes
  or triggers dizziness. See Stun gauge below.
- Per-attempt hit damage, chip damage, meter gain, contact frames and timeline.
- Startup, observed active samples, recovery and ground-control advantage when
  the necessary boundaries have been observed.

The HUD labels Startup, Hit frame, Active, Rec, Adv(ctrl), Damage, Chip, Stun
and Meter separately. Stun is the selected native operand for the attempt.
Active counts use `b` for the fighter body and `o` for owned collision tasks;
these can use different clocks and are not added into a single universal window.
The damage sequence and contact gaps show the latest four contact frames. Gaps
include intervening hitpause; they do not prove a combo or a punishable opening.
Script IDs are hexadecimal identities, **not automatically inferred move names**.

### Measurement boundaries

Startup begins at the **native script initializer**, not at the first directional
motion or an earlier buffered button. It excludes identified source hitpause,
including an unchanged release sample. First active includes geometry observed
before response processing. Contacts before known geometry retain a bound (`<=`),
not an invented exact startup. Active counts describe the observed attempt;
contact, cancel or invulnerability can prevent them from describing the complete
authored whiff window. Projectiles use their independent observed frame ticks.

Recovery is last observed activity to the owner's first grounded control-ready
sample. Projectile lifetime can exceed owner recovery; the tool leaves that
conventional recovery value unset. Air moves wait for grounded control readiness;
their duration therefore depends on jump height and contact timing.

**Adv(ctrl) = defender grounded-control-ready frame − attacker grounded-control-ready
frame**, after the last observed contact. A negative value favors the defender.
This is an observed control boundary, **not a universal proof that block, deflect,
every cancel or a particular retaliation becomes legal on that same frame**.
Interrupted, superseded or incomplete attempts do not receive ordinary advantage.
Knockdown results include the observed return to ground control; they are not
universal wake-up/techability data. Grabs are detected at the native successful
gate; delayed throw damage does not define their startup or a conventional active box.

## Dummy and resources

**P2 defaults to neutral dummy**: physical P2 directions/buttons are suppressed.
P1 input remains yours. Set **Dummy → P2 control → Manual** when you explicitly
want independent P2 controls. Observation does not change ROM or actor state;
selection setup, timer freeze, dummy inputs and recovery are separate training
actions. Manual disables these resource writes as well as dummy input control.

- Guard: none, held standing/crouching, release after first guard contact,
  switch standing↔crouching, random block/no-block, D deflect attempts or
  switch-guard→4A probes. Held-back inputs can walk; use the corner for controlled
  measurements. Random guard chooses a policy per observed interaction.
- Counter triggers: after hit, block, either, or observed grounded wake-up.
  Choose a normal, button chord or one of the listed motions and0–60f delay.
  Every resolved hit/block contact re-arms the counter, without requiring30
  quiet frames. Normal/chord block counters retry bounded button edges and stop on
  actual native attack admission. Motions wait for native grounded readiness and
  run once: looping236 could otherwise form623 and select the wrong special. They release buttons between retries and hold
  the requested stance. **Switch before counter** changes guard first on block;
  hit/wakeup counters do not receive that switch. Input attempts expire after180f.
  Delay0 offers early normal/chord edges; nonzero delay begins at observed
  grounded control readiness. These are **attempts**, not universal
  first-frame/actionability proofs.
  Switch→4A remains a convenient preset. D attempts
  use one two-frame pulse per interaction, then release; they do not guarantee
  success. The tested standing deflect is labelled only after both native
  reaction states appear. Other low/air/character-specific routes remain scoped.
- **Infinite time defaults On:** the native clock is held at60, with an INF
  indicator. The normal clock resumes when disabled. ROM bytes, clock mode and
  native divider are untouched; a validated post-decrement hook prevents flicker.
- **P2 HP after combo defaults On**, with **Recovery wait =1.0s /60f**.
  Resources lets you disable it or choose0.5–5s in0.5s steps. Recovery waits for
  no new contact during that interval, defender readiness, no active attack boxes
  and no incomplete measurement. It never heals between hits in a continuing
  combo/throw or while P2 is still down/stunned. If recovery lasts longer than the
  selected wait, healing occurs after it finishes. This is nonlethal recovery;
  it does not revive an already-KO'd dummy or reset positions.
- Both-player idle HP and meter refill remain separate opt-in options. Resource
  writes happen after observation; healed values become the next baseline, so
  damage/chip/stun statistics survive recovery. Menu/playback suppress HP refill.


## Input recording

The button workflow follows [3rd Training's official command list](https://github.com/Grouflon/3rd_training_lua/blob/master/3rd_training.lua):

| P1 input in battle | Action |
|---|---|
| Start | Open/close training menu |
| Coin twice, less than11f apart | Enter/exit recording mode |
| Coin once while waiting to record | Start recording the selected slot |
| Coin once while recording | Stop recording and return to normal control |
| Coin once in normal/playback mode | Start/stop replay |

A single tap resolves after11emulated frames to distinguish a double tap. Coin
means the emulator's **P1 Coin binding**, not a fixed keyboard key. Holding Coin
counts once. In recording standby and while recording, **P1's controller drives
P2; P1 stays neutral**. The HUD shows REC WAIT / REC / PLAY. Perform the sequence
with P2, stop, then replay it against your normal P1. Coin/Start are excluded
from the new recording flow. There is no savestate/position reset on replay.

**Recording** has eight in-memory slots, capped at3,600 frames each. Select a
slot in that tab. **Record dummy** arms the same standby mode; close the menu
and tap Coin to begin. **Play to P2** remains a menu alternative. Playback uses
P2's current facing; P1 remains live. Modes: once, repeat selected slot, weighted
random enabled slots, ordered once, repeated ordered. Inter-clip neutral gaps
are configurable; stop/end releases playback buttons.

No recording files are created. Slots survive measurement resets/savestate loads
inside the same Lua session, but restarting Lua discards them. Playback does not
restore spacing, state, resources or positions; different conditions can produce
different moves/outcomes. This is input replay, not a saved game replay system.

For Hit / Block / Whiff comparisons perform separate attempts with the required
spacing, guard and target state. This prototype does not predict all outcomes
from one hit, nor publish a complete character frame-data table.

## Stun gauge

The move statistic **Stun** is the selected native stun operand, not a clamped
change in the remaining gauge. A borrowing/priming hit can show64 even though
the engine resets remaining to capacity. A weak operand during prime may be
ignored by the gauge; the move value is still shown accurately.

Compact96px bars sit below HP. Ordinary fill is capacity minus remaining stun.
The game's byte borrow **resets the internal remaining value and primes a
follow-up window**; the displayed bar stays full orange with **STUN: PRIMED**.
A qualifying stun operand (at least24) during that window triggers **STUN: DIZZY**
in red. A weaker hit does not necessarily trigger dizziness. Exact remaining0
alone is not primed. Prime expiry returns to the actual native gauge; the native
post-dizzy timer residue does not keep the HUD marked dizzy.

## Rendering and performance

Collision boxes default to outlines. Display → Filled collision boxes restores
translucent interiors. Timeline phases are drawn as contiguous strips with the
same per-frame contacts. Identical box geometry/color is rendered once; native
collision observations remain separate and complete. Measurements still run
every emulated frame, including when the timeline is hidden.

These changes reduce drawing work. Hidden-window tests cannot certify foreground
FPS on every Wine/video configuration; a successful test is not a claim that all
stage, combo or rendering slowdowns are fixed.

## Compatibility and scope

The script validates the `lastbld2` driver name and small instruction signatures
at every installed hook. Unknown code contracts disable the overlay rather than
installing hooks at guessed locations. Passing these checks is **not a full-ROM
hash verification**. Original ROM is the initial acceptance target; a balance mod
needs its own acceptance test even if these hook sites match.

Bounded buffers: 600 timeline samples per attempt, 64 contact-frame records,
12 input-history entries per player and 192 events of each kind per frame.
Overflow is reported. Savestate loads, player changes and discontinuous emulated
frame counters discard partial measurements.

Not implemented: persistent replay files, rewind, browser live bridge, predictive autoguard,
all-character move-name resolution, automatic universal cancel/techability tests,
or online rollback integration.

## Source and tests

| Module | Responsibility |
|---|---|
| `lb2/profile.lua` | Reviewed addresses, instruction contracts, range metadata |
| `lb2/game.lua` | Read-only RAM sampling, collision decoding, camera projection |
| `lb2/hooks.lua` | Read-only execution observations before contact resolution |
| `lb2/observe.lua` | Pure bounded per-attempt measurement state machine |
| `lb2/controls.lua`, `dummy.lua` | Tabbed GUI, dummy input policy, idle refill |
| `lb2/select.lua` | Native select flow, P1 routing, temporary turbo ownership |
| `lb2/resources.lua` | Validated clock freeze and delayed P2 HP recovery |
| `lb2/transport.lua` | Coin single/double-tap and recording mode workflow |
| `lb2/recorder.lua` | Bounded in-memory recording/playback transport |
| `lb2/input_display.lua` | Drawn direction arrows and colored A/B/C/D history |
| `lb2/hud.lua`, `draw.lua` | Overlay rendering, clipped outlines and phase strips |
| `lb2/app.lua` | Callbacks, lifecycle and reset behavior |

Run pure state-machine tests from the project root with Lua 5.1:

```sh
lua Training/tests/run.lua
lua Training/tests/select.lua
lua Training/tests/dummy.lua
lua Training/tests/hud.lua
lua Training/tests/recorder.lua
lua Training/tests/integration.lua
lua Training/tests/resources.lua
lua Training/tests/draw.lua
lua Training/tests/transport.lua
lua Training/tests/stun.lua
```

These pure tests do not launch FBNeo or require a ROM. Native-emulator checks
are separate; see the repository validation notes for their acceptance limits.

Inspired by the training workflow of
[Grouflon's 3rd Training Lua](https://github.com/Grouflon/3rd_training_lua):
in-game menu, input history, dummy guard/retaliation and post-attempt measurements.
See [feature-parity.md](docs/feature-parity.md) for implemented and deferred scope.
This is an independent implementation for Last Blade 2; no 3S source, ROM assets,
recordings or precomputed game graphics are included. Code is MIT licensed.

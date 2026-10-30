# Last Blade 2 Training

Live training mode for **The Last Blade 2** in **Fightcade FBNeo**, written in
Lua 5.1. Current version: **0.1.0-live.5 — experimental**.

The game draws the sprites while Lua observes collision and timing in the current
attempt. Normal use creates no video, image, recording or per-frame log files.
This is a separate project from the
[saved Frame Lab viewer](https://github.com/Akariiiii/last-blade-frame-lab).

## Install and start

1. Download this repository using **Code → Download ZIP**, or clone it. Extract
   it and keep the entire `Training/` folder together.
2. Run Last Blade 2 (`lastbld2`) in Fightcade's **standalone offline FBNeo** with
   Lua scripting support. Supply your own game ROM and Neo Geo BIOS.
3. Open **Game → Lua Scripting → New Lua Script Window** and load
   [`Training/lastblade2-training.lua`](Training/lastblade2-training.lua).
4. The script returns to character select. Use **P1 directions + A** to choose
   **P1 character → P2 character → P1 mode → P2 mode**. Release buttons between
   confirmations. P1 controls both selections; in battle P2 becomes the dummy.
5. Press **P1 Start** to open the training menu. On the tab header use
   **Left/Right or A** to change tabs, **Down** to enter options, **Up** to return
   to the header, **Left/Right/A** to change a value and **B** to close.

On **Windows**, load the same Lua file directly in FBNeo. On **macOS**, use
Fightcade's Windows FBNeo through Wine; the file picker can reach macOS files at
`Z:\Users\…`. This repository does not bundle an emulator or launcher. Set FBNeo
to windowed mode and volume zero for muted practice. The Lua script does not
change window focus or audio settings. Native Windows UI acceptance is pending.

## Controls

A/B/C/D, Start and Coin refer to your **FBNeo P1 bindings**, not literal keyboard
letters. These are the default Lua hotkeys; check FBNeo's mappings if they differ.

| Input | Action |
|---|---|
| P1 Start / Alt+2 | Open or close training menu |
| Alt+1 | Return to character select |
| Alt+3 | Toggle collision boxes |
| Alt+4 | Toggle statistics HUD |
| Alt+5 | Clear measurements and stop recording/playback |
| FBNeo Pause / Frame Advance | Inspect one emulated frame at a time |

Menu tabs: **Display · Dummy · Resources · Actions · Recording**.

## Practice and recording

- **Resources:** infinite time and P2 HP recovery are enabled by default. Healing
  waits for 60 frames without contact and completed recovery; configure 30–300f.
  It does not revive a KO or reset positions.
- **Dummy:** neutral, held/released/switched/random guard, deflect attempts and
  counters after hit/block/wakeup. Enable **Switch before counter** for a
  switch-guard counter probe. Counters are bounded input attempts; universal
  first-legal-frame timing is not certified.
- **Ground recovery:** Dummy → Ground recovery selects Off / Roll forward / Roll
  backward. Recovery frequency is Always or Random (50% per knockdown). With
  After wakeup, roll runs first and the counter/delay starts at grounded control
  readiness. Native recovery restrictions remain in force.
- **Display:** attack/hurt/pushboxes, owned projectile collisions, distance,
  input history, stun gauges and actual-attempt startup/active/recovery,
  damage/chip/stun/meter and control-ready advantage.

Recording follows the 3rd Training Coin/Start workflow:

| P1 Coin input | Action |
|---|---|
| Twice, less than 11 frames apart | Enter/exit recording standby |
| Once in standby | Start recording selected slot |
| Once during recording | Stop recording and return to normal control |
| Once during normal play or playback | Start/stop replay |

Choose a slot under **Start → Recording**. In standby/recording, **P1's controller
drives P2 and P1 stays neutral**. Perform the dummy sequence, tap Coin to stop,
then tap Coin in normal play to replay it against your P1. Single taps resolve
after 11 emulated frames to distinguish double taps. Start/Coin are excluded
from clips. Eight slots hold up to 3,600 frames each, with once/repeat/random/
ordered playback. Slots exist only in memory: restarting Lua discards them.
Replay does not restore positions or a savestate.

## Read the measurements

**Adv(ctrl) = defender grounded-control-ready frame − attacker ready frame.**
Positive favors the attacker; negative favors the defender. Values describe the
actual attempt and depend on spacing, contact, guard behavior and landing height.
This is not a universal guarantee of when every block, deflect or cancel is legal.
Unknown or incomplete boundaries remain unset or explicitly bounded.

The **Stun** move value is the native selected stun operand. The gauge separately
tracks depletion: orange **PRIMED** means a qualifying follow-up can trigger dizzy,
and red **DIZZY** means the native dizzy state is observed. The game's internal
refill on prime does not empty the displayed bar.

The purple grab-range reference extends **toward the opponent**. Range alone
does not prove that a throw is legal in the opponent's current state.

## Documentation and development

- [Full usage and measurement guide](Training/README.md)
- [Feature comparison and deferred scope](Training/docs/feature-parity.md)
- [Validation and known limitations](docs/VALIDATION.md)
- [Source layout and test instructions](CONTRIBUTING.md)

The package checks the driver and instruction signatures before installing
hooks. This is not a full-ROM hash check. Observation and training inputs/resource
assistance are distinct from gameplay balance patches; a modified ROM needs its
own acceptance tests. Use offline training; online rollback integration is not
implemented. Severe foreground FPS drops on some Wine/video setups remain under
investigation; reduced drawing work is not a verified universal FPS fix.

## License and credits

MIT; retain the [repository license](LICENSE) and [training source license](Training/LICENSE)
when redistributing their respective code. ROMs, BIOS, emulator binaries, game
artwork, capture datasets and third-party Lua code are not included or licensed
by this project.

Inspired by [Grouflon's 3rd Training Lua](https://github.com/Grouflon/3rd_training_lua).
This is an independent Last Blade 2 implementation; no 3S code or assets are included.

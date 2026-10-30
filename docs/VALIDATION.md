# Validation — 0.1.0-live.5

Checkpoint: 2026-10-30. Ground-recovery release package. Source-only package; no emulator or game data included.

## Pure checks

536 assertions pass in 11 Lua 5.1 suites. All 27 Lua files pass syntax checks.
See [CONTRIBUTING.md](../CONTRIBUTING.md) for reproducible commands.

## Native checks and qualification

The development workspace retains bounded native FBNeo receipts for:

- Counter behavior: 10 cases / 11 checks, including repeated block, optional
  switch guard, hit/whiff, delay, random guard and multi-hit interactions.
- Coin/Start recording workflow: 9 checks on the mod06 runtime, including P2
  replay and actual button/direction frames.
- Natural stun depletion, prime and dizzy transitions with Amano.
- Original-ROM acceptance: 44 checks, 11 cases and 150 paired actor-frame samples
  matching the observation baseline.

These are the **historical live.4 composite validation**, not a completed native
rerun of every current source byte. The baseline release had a later HUD stun
expression change covered by pure renderer tests. The ground-recovery patch also
changes dummy/controls; its separate bounded native checks are listed below.

A subsequent final-source native rerun crashed in Wine/FBNeo **before Lua ran**,
including an empty script. The root cause is unresolved. This prevents claiming
a complete final-source native pass. Earlier timer/selection and rendering checks
belong to live.3 and do not constitute a new live.4 acceptance run.

## Ground recovery development checks — 2026-10-30

- Original-ROM production run:14cases, with68checks passing in a separate audit
  of unchanged native RAM traces. Covers both roll directions and actual
  displacement, mirrored facing, Off/held guard, both Random outcomes, wakeup
  normal/motion counter admission and delay after grounded readiness.
- The original harness verdict remains FAIL: its attack-entry hook omits the low
  roll scripts. The separate corrected audit reads native RAM script transitions
  and preserves the original receipt. The command throw tested is recoverable.
- 0 Training RAM writes in these resource-disabled trials, unchanged runtime source
  hashes; hidden/windowed/audio0/CPU100 and verified focus protection.
- An additional four-route diagnostic observed a DM/DP followed by recovery and
  a normal hit without false wakeup. The intended SDM input admitted a DP instead;
  it is not SDM acceptance. No completely unrollable hard-knockdown move was
  identified in this bounded pass. Native input/control gates remain unchanged;
  recovery cannot override a refusal. Air recovery is outside this feature.
- The new pure suite covers per-knockdown RNG, roll/counter order, delay,
  input release, KO, both facings and menu/manual/recording/playback ownership.

The release profile revision changed from live.4 to live.5 after these runs.
All other runtime Lua bytes match the recovery run snapshot; the revision change
is checked as an exact metadata-only replacement. No new native run is claimed.

These are scoped development checks, not a full release acceptance rerun,
all-character proof, foreground FPS acceptance or balance-mod validation.

## Limits

- No all-character, every-cancel, first-legal-frame-counter or online rollback
  certification. Native Windows UI acceptance is pending.
- Foreground FPS drops reported with overlays/combos remain unresolved. Rendering
  work was reduced, but a universal FPS improvement has not been established.
- Frame advantage describes observed grounded control boundaries, not universal
  block/deflect permission. Jumps, grabs, knockdowns and independent projectiles
  require the measurement qualifications in the usage guide.
- Replay is bounded in-memory input playback, without persistence, position
  resets or rewind. Full feature parity with 3rd Training is not claimed.
- Private evidence and ROM-dependent harnesses are not shipped. Pure tests are
  reproducible from this repository; native claims are scoped development results.

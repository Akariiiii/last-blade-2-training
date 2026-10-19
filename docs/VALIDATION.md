# Validation — 0.1.0-live.4

Checkpoint: 2026-10-20. Source-only package; no emulator or game data included.

## Pure checks

409 assertions pass in 10 Lua 5.1 suites. All 26 Lua files pass syntax checks.
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

These are **composite validation**, not a completed native rerun of every final
source byte. All current runtime Lua matches those receipts except the final HUD
stun-number expression and its comments. That expression now displays the native
stun operand rather than a clamped gauge delta. It is covered by pure renderer
tests and comparison against the prior native-tested source.

A subsequent final-source native rerun crashed in Wine/FBNeo **before Lua ran**,
including an empty script. The root cause is unresolved. This prevents claiming
a complete final-source native pass. Earlier timer/selection and rendering checks
belong to live.3 and do not constitute a new live.4 acceptance run.

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

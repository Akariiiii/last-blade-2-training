# Development

## Layout

| Path | Purpose |
|---|---|
| `Training/lastblade2-training.lua` | FBNeo entrypoint; resolves modules relative to itself |
| `Training/lb2/` | Game profile, observations, dummy, resources, recorder and HUD |
| `Training/tests/` | Pure Lua tests; no emulator or game assets needed |
| `Training/docs/` | Feature scope and API notes |
| `docs/VALIDATION.md` | Current acceptance boundaries |

Keep the entrypoint and `lb2/` together when installing. Run the following from
the repository root with **Lua 5.1** on your PATH:

```sh
for suite in run select dummy hud recorder integration resources draw transport stun; do
  lua "Training/tests/$suite.lua" || exit 1
done
find Training -name '*.lua' -exec luac -p {} +
```

The current suite has 409 assertions across 10 suites and 26 syntax-checked Lua
files. A pure-test pass does not replace native-emulator or gameplay acceptance.

Document any changed RAM/instruction contracts with their address space, observed
behavior and supported build. Preserve unknown measurements as unknown. Avoid
automatic files/logging in the normal entrypoint, keep observation buffers bounded,
and measure rendering performance separately from gameplay-state equivalence.

Do not commit ROMs, BIOS, emulator binaries, savestates, captures, Wine prefixes,
credentials or private test evidence. Native tests should be offline, windowed,
muted and must not steal focus from other applications.

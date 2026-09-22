# Offline test harnesses

Four Lua suites that load the real addon against a stub WoW API and check it without a
client. Roughly seventy assertions, all green as of commit `cddf553`.

They cannot tell you how anything looks or feels. They can tell you that every file loads
in TOC order, that every closure resolves, that no control silently fails to build, and
that a handful of behaviours nobody can eyeball are actually correct.

## Running them

From the repo root. The argument is the addon directory.

```sh
for t in harness locomotion-test crafting-test engine-test; do
    printf '%-18s ' "$t"
    lua PulseChecklist/tests/$t.lua Pulse 2>&1 | tail -1
done
```

Any Lua 5.1–5.5 works; the stubs paper over the differences. A failing suite prints the
failing assertion with what it got and what it wanted, then a `FAILURES: n` line.

Pair them with a syntax pass, which catches a different class of mistake:

```sh
find Pulse -name '*.lua' -exec luac -p {} +
```

## What each one covers

| Suite | Asserts |
|---|---|
| `harness.lua` | Loads every `Core/` file, every module and the whole `UI/Panel/` tree, then builds all 20 pages — 1,141 rows, 841 controls, 162 index entries. Every getter, dependency predicate, visibility predicate and options function runs; every value round-trips through its own setter. Also: no spec fails to build, no dropdown is still wired to Blizzard's menu, every cue-index line navigates, the dependency pass greys and ungreys correctly, and 27 profile-scope assertions |
| `locomotion-test.lua` | The ground-contact guard — swimming, flying, gliding, falling, and the rising half of a jump, which `IsFalling` does not report |
| `crafting-test.lua` | Craft rhythm end to end through real `CastActivity` events: profession resolution, strike scheduling, the final blow landing on completion but not on an abandoned craft, per-profession toggles and strengths |
| `engine-test.lua` | The asynchronous cancellation boundary. `StopAll` must void already-scheduled `PlayMode` steps and ramp steps, while a cue fired *after* it still plays |

## Two things worth knowing

**`engine-test` was checked against the broken code.** Delete the five
`engineGeneration ~= generation` guards from `Core/Engine.lua` and it fails with 4 leaked
`PlayMode` steps and 40 ramp steps instead of 3. A test that has never failed has not been
tested.

**The stubs auto-create widget methods, but only methods.** `harness.lua`'s
`METHOD_PREFIXES` list returns a no-op for anything starting with `Set`, `Get`, `Is` and so
on, and `nil` for everything else — because the panel relies on a real frame returning nil
for an unset field (`if row.MeasureHeight then`, `if control.IncrementButton then`).
Widening that list to a prefix like `Increment` would turn the *field*
`control.IncrementButton` into a function and silently defeat the guard it is meant to
test. Add exact names to `METHOD_NAMES` instead.

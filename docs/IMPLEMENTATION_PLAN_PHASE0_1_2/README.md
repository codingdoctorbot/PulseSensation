# Phase 0–2 implementation package

Everything the implementer of `IMPLEMENTATION_PLAN_PHASE0_1_2.md` (in this folder) needs besides the plan itself: ready patches, the evidence behind the plan's claims, the tools that produced it, and a one-command re-verification.

**Nothing in this folder is loaded by the game, linted by `scripts/test.sh`, or shipped by `scripts/package.sh`:**
- `test.sh` lints only `PulseHaptics/ PulseDebug/ PulseChecklist/`.
- The folder has no `.toc` file.
- Packaging zips only the addon folders.

The repository's addon code is untouched: the patches are text until someone applies them.

**Baseline:**
- `0c74dc3` (`main`).
- The working-tree `.luacheckrc` (uncommitted additions).
- The untracked `PulseProbe/` folder.

`git apply --check patches/00-ALL-cumulative.patch` passes against that state (dry run, 2026-09-30).

> **Note on `0c74dc3`.** The project owner's commit landed the Engine half of P0.1 (the missing `else` in `mapValue`), functionally the same fix as the plan. So patch 01 now contains only the **test** half: exact-value floor assertions. See `evidence/test-runs/floor-regression-detection.log` for why those still matter.
>
> The plan's line references were taken at `441f4f3`. The only file `0c74dc3` changed is `PulseHaptics/Core/Engine.lua`, where lines from 527 onward shift down by one. `engine-test.lua` kept its line count.

---

## Contents

| Path | What it is | Use it for |
|:--|:--|:--|
| `IMPLEMENTATION_PLAN_PHASE0_1_2.md` | The plan | Start here |
| `verify.sh` | Rebuilds a throwaway copy of the tree in a temp dir, applies the patches in order, runs the full battery after each, lints and compiles the probe, and runs stylua. Exits non-zero on any failure. Never touches the repo. | Re-check that the patches still apply and pass after `main` moves: `bash IMPLEMENTATION_PLAN_PHASE0_1_2/verify.sh` (`--keep` keeps the temp copy) |
| `patches/01-P0.1-engine-floor.patch` | Replaces `engine-test.lua`'s floor block with exact-value assertions | P0.1 |
| `patches/02-P0.2-probe-trace.patch` | `PulseProbe/Core.lua` trace ring and `/probe trace …` commands, new `Probes/Sequencer.lua`, toc line, new `scripts/probe-trace-report.lua`, `.luacheckrc` globals | P0.2 |
| `patches/03-P1-arbitration.patch` | New `Core/Arbiter.lua`; `Init.lua` (`GatesOpen`, `FireIfEnabled` bus + return value); `Registry.lua` (`EPISODES`, `window`/`intake` buses); `Inventory.lua`, `World.lua`, `Interaction.lua`, `AlertWorld.lua`; toc; test loaders; new `arbitration-test.lua`; `test.sh`; `.luacheckrc` | P1.0–P1.5 |
| `patches/04-P2-panel-and-gates.patch` | Page-switch triggers, `PAGE_GATES`/`CUE_GATE`; `Database.lua` seeding, fold state, `simpleView`, migration guards; `Init.lua` `IsCueActive` and `BindFrame`; panel (`Rows`, `Content`, `Spec`, `Sidebar`, `Panel`, `Theme`); new `phase2-test.lua`; harness count fix | P2.1–P2.5 |
| `patches/00-ALL-cumulative.patch` | 01–04 in one | Reading the whole change at once |
| `evidence/test-runs/verify-run.log` | `verify.sh` output: 7 → 7 → 7 → 8 → 9 suites green, probe lint 0/0, stylua clean | Proof the patch stack is green |
| `evidence/test-runs/floor-regression-detection.log` | Owner's test vs the regressed engine: **1** failure (continuous half caught, doubled discrete floor missed). Patch 01's test vs the regressed engine: **6** failures. Patch 01's test vs HEAD: all pass. | Why patch 01 is still worth applying |
| `evidence/test-runs/mutation-checks.log` | Swapping HEAD's `Interaction.lua` back → 5 failures; HEAD's `Inventory.lua` → 2; removing the gate-seeding exemption → 4 | Proof the new tests catch the bugs they target |
| `evidence/test-runs/arbitration-test.log`, `phase2-test.log` | Full outputs (46 and 49 checks) | What each check asserts |
| `evidence/registry-dump.txt` | All 190 triggers at `0c74dc3`: id, category, mode, throttle, default, events, page/section | Reference while editing `Registry.lua`; bus and gate membership |
| `evidence/floor-model.txt` | Regressed vs fixed floor maths on the Xbox presets; Thought 9.4's clamp shown not to be monotonic | P0.1 background |
| `evidence/panel-row-counts.txt` | 787 → 239 rows (−70%) per page | P2.3 sizing |
| `evidence/forever-source-refs.md` | 18 verbatim excerpts from the Forever 1.60.1.69913 UI source, one per client fact the plan relies on (loot payloads, `CHAT_MSG_LOOT` GUID, `GetLootSlotInfo` returns, guild repair, `InRepairMode`, alert slots, Open All Mail delay, precise clocks, …) | Checking an API assumption without hunting through the source tree |
| `evidence/probe-report-example/` | A **synthetic** trace dump and the report it produces | What `/probe trace dump` writes and what the report prints. **No measured numbers.** |
| `tools/registry-dump.lua`, `floor-model.lua`, `panel-row-counts.lua` | Standalone LuaJIT scripts that regenerate the three evidence files above | `luajit IMPLEMENTATION_PLAN_PHASE0_1_2/tools/<name>.lua` from the repo root |

---

## Applying the patches

Only once the owner lifts the read-only rule. From the repository root, in order:

```sh
git apply --check IMPLEMENTATION_PLAN_PHASE0_1_2/patches/01-P0.1-engine-floor.patch   # dry run first
git apply IMPLEMENTATION_PLAN_PHASE0_1_2/patches/01-P0.1-engine-floor.patch
./scripts/test.sh                                                                     # 7/7
git apply IMPLEMENTATION_PLAN_PHASE0_1_2/patches/02-P0.2-probe-trace.patch             # probe, can ship on its own
git apply IMPLEMENTATION_PLAN_PHASE0_1_2/patches/03-P1-arbitration.patch
./scripts/test.sh                                                                     # 8/8
git apply IMPLEMENTATION_PLAN_PHASE0_1_2/patches/04-P2-panel-and-gates.patch
./scripts/test.sh                                                                     # 9/9
```

- Patch 02 touches `.luacheckrc` and the untracked `PulseProbe/`. Apply it before 03, because 03's `.luacheckrc` hunk sits on top of 02's.
- If `main` has moved and a patch no longer applies, `git apply --3way` (for tracked files) or the code blocks in the plan are the fallback. The plan explains every hunk.

## What these patches are and aren't

- They are the **reference implementation the plan was validated against**. Every behaviour claimed in the plan's §3–§4 is exercised by `arbitration-test` or `phase2-test`.
- They are **not measured in game**. The timing constants are defaults until the PulseProbe traces (plan P0.2, scenarios S1–S8) confirm them:
  - `LOOT_TAIL` 0.30 s
  - `DEFAULT_BUS_WINDOW` 0.15 s
  - `REPAIR_WINDOW` 2.0 s
  - `DEBIT_WINDOW` 1.0 s

  Widget geometry (`Theme.CUE_*`) needs the in-game UI checks in plan §4 P2.5.
- Open decisions in plan §6 aren't settled by the patches. The patches implement the plan's stated defaults for each.

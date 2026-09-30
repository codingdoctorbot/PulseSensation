# Evidence for the 2026-09-30 PulseHaptics code review

This folder holds the scripts and recorded outputs behind `PULSEHAPTICS_CODE_REVIEW_2026-09-30.md` (in the repository root). Nothing here is loaded by the game. None of it is part of an addon.

## Layout

| Path | What it is |
|---|---|
| `run.sh` | Re-runs everything: the test suites at the two commits, every probe, and the static checks. |
| `probes/*.lua` | The offline probes. They load the real addon files through the stub WoW API that `PulseChecklist/tests/harness.lua` already provides. |
| `evidence/*.txt` | The outputs recorded on 2026-09-30, one file per topic. |

## Which evidence backs which finding

| Finding | Evidence file | Probe or check |
|---|---|---|
| F-01: soft floor puts default textures under the breakaway floor | `evidence/F-01-softfloor.txt` | `softfloor.lua`, run against `db2ffa5` (hard floor) and `ad0ef89` (soft floor), at master 0.70 and 1.00 |
| F-02: craftTexture off silences castTexture while fishing | `evidence/F-02-F-05-crafting.txt` (a), `static-checks.txt` | `craft.lua` |
| F-03: Option B curation never applies to pre-curation installs | `evidence/F-03-migration.txt`, `static-checks.txt` | `migrate.lua`, `migrate_ab.lua`, `questing.lua` |
| F-04: oscilloscope always reads 0 | `evidence/F-04-oscilloscope.txt`, `static-checks.txt` | `scope.lua` (against `1ca6a24`) |
| F-05: craft preview never plays its strikes | `evidence/F-02-F-05-crafting.txt` (b), `static-checks.txt` | `craft.lua` |
| F-06: selfCastInstant doubled in curated profiles | `static-checks.txt` | grep of the profile tables |
| F-07: dead Coast slider, hidden `floorKnee` | `static-checks.txt` | `git grep` at `1ca6a24` |
| F-08: Raiding and Questing missing from the catalogue page | `evidence/registry-and-pages.txt` | `pages.lua` |
| F-11: off-grid tunable defaults, plus the Registry checks | `evidence/registry-and-pages.txt` | `registry.lua` |
| §2: baseline tests and lint | `evidence/tests.txt` | `scripts/test.sh` inside the `ad0ef89` and `1ca6a24` snapshots |

The other P3 findings (F-09, F-10, F-12 to F-18) rest on reading the code. The report gives file and line for each.

## Re-running

```sh
docs/review-2026-09-30/run.sh                                  # outputs to a fresh temp dir (printed)
docs/review-2026-09-30/run.sh docs/review-2026-09-30/evidence  # refresh the recorded evidence on purpose
```

- **Requirements:** `git`, `luajit` (or set `LUA=`), and `luacheck` for the lint lines.
- **Read-only against the repository.** `run.sh` extracts four commits with `git archive` into a temporary directory, which is deleted afterwards. It exports that directory as `PROBE_SNAPSHOTS`, and the probes load the addon only from there, never from the working tree.

The four commits compared:

| Snapshot | Commit | Why |
|---|---|---|
| `head` | `ad0ef89` | review baseline (soft floor, DB_VERSION 10) |
| `h2` | `1ca6a24` | HEAD when the report was written (oscilloscope) |
| `pre` | `db2ffa5` | last commit before the soft floor |
| `v8` | `dace2ab` | last commit before profile curation (`04b6638`), DB_VERSION 8 |

The probes are pinned to these commits, so they reproduce the review's numbers, not the current HEAD. To test a fix, change the commit in `run.sh`'s `extract` lines, or point a probe at another snapshot name.

## Caveats

- The stub API is the harness's, so anything the harness does not model is not tested here:
  - frame ordering between `C_Timer` and `OnUpdate`
  - real controller hardware
  - real event payloads
- The report's §7 lists what still needs the live client.
- `migrate.lua` writes its two generated SavedVariables files (`v8db.lua`, `headfresh.lua`) into the temporary snapshot directory, not into this folder.

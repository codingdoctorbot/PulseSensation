# Handoff: full code review of PulseSensation (xhigh)

**Written:** 2026-09-28, at the end of the planning/documentation session.
**For:** a fresh Claude Code session in `PulseSensation`.
**Task:** a complete, read-only code review at **xhigh** depth. Findings are documented in the repo, not only in chat.

Read this whole file before doing anything else.

---

## 1. Ground rules (from the user)

1. **Read-only for code.** Do not edit, stage or commit any source, test, TOC or script file. Do not push. Do not touch the uncommitted work in progress (section 3). The only files you write are the review outputs in section 7. Throwaway probes go in *your session's* scratchpad directory.
2. **Every claim needs evidence:** a repository-relative `path:line`, a command output, or a commit hash. Label each statement **[Fact]**, **[Inference]**, **[Rec]** or **[Unverified]**. Anything that needs the live WoW client or controller hardware is [Unverified].
3. **Be honest about coverage.** The user will ask what the review was based on. Keep the coverage ledger (section 7.2) accurate: a file is "fully read" only if every line was read.
4. **Never conclude that something is absent from truncated output.** Three wrong statuses last session came from `grep … | head -N` cutting off real matches. For absence checks, use `grep -c` or read the full output.
5. **Review history with whitespace ignored** (`git show -w --ignore-cr-at-eol`). Several commits are mostly reformatting; for example `2fd5c92` shows 927 changed lines in `Engine.lua` but changes about 3.
6. **Do not rediscover known issues** as new. Check each finding against section 5 and `docs/DOCS_COMPILATION.md` sections 4, 9 and 10. Cite the existing entry and add only what is new, such as a root cause, a wider impact, or a correction.
7. **Do not spawn subagents** unless the user asks. Work inline.
8. **Ask before** anything irreversible or outward-facing: commits, pushes, GitHub issues or PRs, deleting files.
9. **Chat style.** Last session the user had the `/newspeak` skill on for chat. It does not carry over; only use it if the user invokes it again. Deliverables (the review file, doc updates) are always in plain, standard English.

## 2. Orientation: read these first

1. `docs/DOCS_COMPILATION.md`: at least "How to read this", **section 4** (every known finding with current status), **section 9** (commit history reconciliation) and **section 10** (baseline facts, uncommitted-changes review, recommended next phase, acceptance checklist). Sections 1–3 summarise the ~36 project documents; skim them as needed.
2. `README.md`, and `PulseChecklist/tests/README.md` (the stub-harness pitfalls, especially METHOD_PREFIXES).
3. `git status`, `git log --oneline -5`.

## 3. Expected repository state (verify first)

- Branch `main`, HEAD **`ac3d02f`**; remote `origin` → `github.com/codingdoctorbot/PulseSensation`.
- Uncommitted: modified `PulseChecklist/tests/crafting-test.lua`, `PulseChecklist/tests/harness.lua`, `PulseHaptics/Core/CastActivity.lua`, `PulseHaptics/Core/Database.lua`, `PulseHaptics/Core/Engine.lua`.
- Untracked: `PulseProfileReview/`, `ProfileReviewReports/`, `docs/DOCS_COMPILATION.md`, `docs/HANDOFF_CODE_REVIEW.md`.
- **If HEAD or the dirty file list differs, stop and tell the user before reviewing.**

**Baseline commands** (record their results in the review file):
```sh
./scripts/test.sh                      # luacheck + 7 suites
for t in harness:PulseHaptics engine-test:PulseHaptics crafting-test:PulseHaptics locomotion-test:PulseHaptics \
         cue-audit:PulseHaptics checklist-test:PulseChecklist pulsedebug-test:PulseDebug; do
  s=${t%%:*}; d=${t##*:}; printf '%-16s ' $s; luajit PulseChecklist/tests/$s.lua $d 2>&1 | tail -1; done
luacheck PulseProfileReview            # outside the runner
```
Expected: luacheck 0 warnings / 0 errors in 53 files; 6 of 7 suites pass; `crafting-test` fails 3 (a known bug in the test, not the code); the same under LuaJIT; `PulseProfileReview` has 4 luacheck warnings.

**Tools:** `lua` (5.5.1), `luajit` (Lua 5.1 semantics, the WoW runtime), `luacheck`, `gh` (authenticated; do not use it without asking).

## 4. Scope

| Area | Lines | Files | Prior review coverage |
|---|---:|---:|---|
| `PulseHaptics/Core/` | 8,274 | 15 | Engine and CastActivity read closely; Database, Init and Registry only in parts |
| `PulseHaptics/Modules/` | 5,947 | 22 | Targeted greps only; cloud pass 09-22, since changed a lot |
| `PulseHaptics/UI/` | 5,888 | 10 | Cloud pass 09-22 found nothing; UI QA was visual only. **Fresh eyes needed** |
| `PulseDebug/` | 1,312 | 2 | **Never reviewed** |
| `PulseChecklist/Checklist.lua` | 928 | 1 | **Never reviewed** |
| `PulseChecklist/tests/` | 3,261 | 7 | Never reviewed as code; the fakes are known to diverge from the real API |
| `PulseProfileReview/Review.lua` | 347 | 1 | Read once; frame leak and reads that write already known |
| `scripts/` | 221 | 2 | Read; the `set -e` defect is known |
| The 4 `.toc` files and `.luacheckrc` | — | — | TOCs skimmed; `.luacheckrc` unread |

**Out of scope:** `PulseHaptics/Libs/` (third-party libraries), `docs/`, `dist/`, media.
**The uncommitted changes are in scope:** review them as the current code and flag each finding as uncommitted.

Suggested order: Core (Init → Database → Registry → Modes → Waves → Devices → Schemas → Engine → CastActivity → Guide) → Modules (largest and riskiest first: Combat, ControllerUI, Locomotion, Movement, Crafting, Environment, Interaction, Health, Inventory, the Alert* modules, then the rest) → UI (Panel, Spec, Rows, Popup, Gamepad, Content, Sidebar, Theme, Settings, Minimap) → PulseDebug → PulseChecklist → tests → PulseProfileReview → scripts and TOCs.

## 5. Known issues: cite these, do not re-report them as new

Full list and statuses: `docs/DOCS_COMPILATION.md` section 4; history in 9.3–9.4; uncommitted work in 10.2. The most important:

| Issue | Where |
|---|---|
| Pooled role tables overwritten before delayed `PlayMode` steps fire (reproduced: 0.45→0.045) | `Engine.lua:200-212`, `:405-410`; since `f447944` |
| New Hearthstone test uses the wrong key; its last assertion passes vacuously | `crafting-test.lua:368-385` vs `CastActivity.lua:65-70` (uncommitted) |
| Uncommitted engine: onset comment ≠ code; dead spacing guard; `MIN_GAP_DURATION` rhythm change | `Engine.lua:367-396`, `:472-480` |
| Uncommitted sweep: magic 60 ×3, one player-wide casting flag, silent clears, no secret guard | `CastActivity.lua:331-359` |
| `test.sh` exits silently when a suite crashes or luacheck warns (`set -e` with `$(…)`) | `scripts/test.sh:2`, `:82`, `:122` |
| Saturating-sum mixer shipped as the default with no way back to MAX (a decision is pending) | `Engine.lua:537-588`, `ea0368a` |
| PulseDebug "Hold 2s" does nothing; the test fake defines `HoldLayer`/`CancelAll` | `PulseDebug/UI.lua:689`, `:733-737`; `pulsedebug-test.lua:321`, `:343` |
| 30 of 59 checklist baseline IDs never existed in this repo | `PulseChecklist/Checklist.lua:70+` |
| SmartNavigation edge callback: the code's own history calls it forbidden, yet it is reachable | `ControllerUI.lua:97-138`; `d9f590f` vs `4c5991e` |
| Craft-matching fallback may end or complete a craft on an unrelated cast [Inference] | `CastActivity.lua:128-140`, `:190-192`, `:222-224`; `580e69f` |
| `keyFor` uses cast GUID/spellID as a table key without `issecretvalue` | `CastActivity.lua:65-70` |
| `_G.issecretvalue` global stub | `Init.lua:12-16` |
| Raw-hold `SetVibration` calls not wrapped in `pcall` | `Engine.lua:518`, `:529` |
| Missing metadata for Raiding/Questing; version stamp overwritten downward; legacy `GetSpellInfo` | `Database.lua:54-172`, `:899`; `Crafting.lua:266-267` |
| Breath "dub" timer has no token; ocean detector matches English substrings; `clamp01` ×6 | `Environment.lua:153-155`; `Movement.lua:57-61` |
| 14 of 20 Controller UI cues default ON; minimap border anchored `TOPLEFT` | Registry; `Minimap.lua:162-163` |
| PulseProfileReview creates frames on every refresh; reads write SavedVariables | `Review.lua:166-225`, `:27-35` |
| Public docs claim 202 cues / 36 modes (actual 190 / 35) | README, CURSEFORGE (section 4.8) |

## 6. What to look for (WoW 12.x Forever client, Lua 5.1)

- **Secret values.** Any comparison, arithmetic, truth test, string operation or table-key use of a value from an API that can return secrets needs an `issecretvalue` guard first. Offline, the global stub always returns `false`, so the tests never exercise this path; reason about it from the code.
- **Taint.** `hooksecurefunc` sites, callback registration into Blizzard mixins or registries (`SmartNavigation`, `EventRegistry`, `CallbackRegistryMixin`), `SetAttribute`, protected calls, `InCombatLockdown` handling, and frames parented or anchored to protected frames.
- **Events.** Each event exists on the 12.1 client; `RegisterUnitEvent` is used only for unit events; events that may be missing are guarded (`C_EventUtils.IsEventValid`, `pcall`).
- **The `sync()`/`BindFrame` lifecycle** (`Init.lua`). Syncs run on every cue toggle, master toggle and profile switch. Cached state must be re-derived (good examples: `PlayerState.lua`, `Health.lua`, `Encounter.lua`); events unregistered when unwanted; `OnUpdate` attached only while needed.
- **Timers.** `C_Timer.After` closures that capture shared or mutable state (the role-pool class of bug); generation and token guards; timers that outlive their state (the breath "dub" class).
- **Hot paths.** Allocation in `OnUpdate` and tick loops, but correctness beats zero-GC every time.
- **Lua 5.1 compatibility.** No `goto`, `//` or bit operators; `#` on tables with holes; string patterns built from player or zone names (magic characters, UTF-8).
- **SavedVariables.** Type validation before use; migrations (`DB_VERSION` 7); downgrade behaviour; reads must not write.
- **UI.** Frames or scripts created per refresh (leaks), secure templates, combat lockdown, scaling, gamepad-mode behaviour (`DRIVE_BLIZZARD_NAVIGATION = false` is intentional).
- **Consistency.** Comments versus code; Registry `desc`/`caveat` versus module behaviour; cue IDs consistent across Registry, Database overrides, Checklist baseline, Guide and PulseDebug; magic numbers; duplicated logic (two `JumpOrAscendStart` hooks).
- **Tests.** Assertions that can fail (not vacuous); fakes that match the real API; missing coverage for bugs found.

**Verifying findings.** Reproduce with the offline stubs where you can. `PulseChecklist/tests/engine-test.lua` lines 1–118 (stubs plus `loadfile` of Modes, Devices, the Standard schema and Engine) are a ready template for engine probes. Otherwise label the finding [Inference]. The last session's probes may still sit in its scratchpad (`scratchpad/`: `pool-probe3.lua`, `pool-control.lua`, `profiles.lua`); they may have been cleaned up.

## 7. Output

### 7.1 Files

- **`docs/CODE_REVIEW.md`** (new, untracked): the review. **Write it incrementally.** Create the skeleton first, then add findings and update the ledger after each area, so work survives context compaction.
- **`docs/DOCS_COMPILATION.md`**: when done, add a short **section 11** (summary, finding counts, a link to `CODE_REVIEW.md`) and one line under "How to read this". Do not rewrite sections 1–10. Where a finding changes a status in section 4, say so in `CODE_REVIEW.md` and list the proposed status changes in section 11.

### 7.2 `CODE_REVIEW.md` structure

1. Header: date, HEAD, dirty-tree note, level xhigh, method, baseline command results.
2. **Coverage ledger:** every in-scope file with its line count and status (fully read / partly read + which lines / not read). The user checks this.
3. **Findings**, most severe first. Severity: **P0** (crash, stuck vibration, taint blocking a user action, data loss); **P1** (wrong behaviour players will notice); **P2** (robustness or maintainability with plausible impact); **P3** (nit).
   Format for each finding:
   ```
   ### CR-### [P1] <one-line claim>
   - Where: `path:line` (uncommitted? yes/no; introduced in <commit> if known)
   - What: [Fact]/[Inference] …
   - Failure scenario: concrete inputs/state → wrong result
   - Evidence: probe/test output, or reasoning if inference
   - Related: DOCS_COMPILATION §4 row / CR-### / none
   - Fix direction: [Rec] … (describe only; do not edit code)
   ```
4. Cross-cutting themes (patterns seen in several files).
5. Known issues re-confirmed or corrected (short list referencing section 4 rows).
6. Test-coverage gaps: tests that should exist.
7. [Unverified] items that need the client or hardware (feed into DOCS_COMPILATION section 7).

### 7.3 Final chat reply

In this order: counts by severity, the top 10 findings (one line each with `path:line`), what changed versus known issues, the coverage summary, and anything not reviewed and why. Keep it short; the detail lives in the file.

## 8. Useful facts

- 190 cues = 175 discrete + 13 continuous + 2 `silent` (`padDisconnected`, `controllerUIMaster`); 35 modes; 16 Registry categories; 21 panel pages; harness: 1,413 rows / 1,010 controls.
- Target client: WoW "Forever" `_classic_beta_`, interface 120100 (12.x engine, secret values, `C_GamePad`). TOCs also list 110200/110100 (untested).
- `C_GamePad.SetVibration` channel strings: `Low`, `High`, `LTrigger`, `RTrigger` (trigger actuation unconfirmed).
- `Engine.lua` is the only file allowed to call `C_GamePad`; modules go through `Pulse:FireIfEnabled` / `HoldIfEnabled` / `HoldRolesIfEnabled` (`Init.lua`).
- 79 commits, 2026-09-22 → 09-24. Planning docs are gitignored and local-only.

# PulseSensation — Documentation Compilation

**Compiled:** 2026-09-28
**Code baseline for status checks:** HEAD `ac3d02f` plus the uncommitted working tree (Engine, CastActivity, Database, two test files).
**Scope:** every project-authored document of the current era (2026-09-22 → 2026-09-26). Vendored reference material (`docs/DevelopmentplusReference/`, `docs/WoWAddonAPIAgents-main/`, `docs/wow-addon-dev-main/`, `docs/Archive.zip`) is out of scope.

## How to read this

- **Section 1** lists every document, where it lives and whether Git tracks it.
- **Section 2** explains how the documents relate: most are reviews of earlier reviews.
- **Section 3** summarises each document.
- **Section 4** is the working part: every finding and recommendation from all documents, merged, with its **current status in the code**.
- **Sections 5–8** cover conflicts between documents, open decisions, the in-game verification backlog, and stale statements inside the documents themselves.
- **Section 9** reconciles the documents against the full commit history (79 commits) and the current code.
- **Section 10** holds the 2026-09-28 planning review: baseline facts, a review of the uncommitted work, the recommended next phase, and a code-review checklist.
- **Section 11** summarises the full xhigh code review (`docs/CODE_REVIEW.md`, 2026-09-28): finding counts, the root causes of the in-game QA reports, and the status changes it proposes for section 4.
- **Section 12** records the locomotion motor trace (2026-09-29): an interactive Low/High simulation of `Modules/Locomotion.lua`, where its files live, how it was checked against the real Lua, and what it measured. **12.1** breaks down why running feels muddy on the user's saved settings, and **12.2** summarises what is problematic, ranked.
- **Section 13** measures the engine's smoothing on continuous cues (2026-09-29): what it does to slow textures and to rhythmic ones, per controller preset. **13.1** checks the slow textures at their real levels, where the floor rather than the smoothing decides what is felt.
- **Section 14** explains why the DualShock 4 feels best, comparing what each controller preset sends, with an A/B test to confirm. **14.1** explains why jump and landing feel good on it: impacts borrow their decay from the preset's release. **14.2** separates what is fixable in software (timing and shape) from what is motor physics (weight and character).
- **Section 15** looks at whether the trigger channels matter on the user's setup, and what removing them would change.
- **Appendix A** is the first planning review as delivered in chat, and **Appendix B** records what that review was based on. Both are kept for the record; the sections above supersede them where they differ.

**Status tags (section 4):**

| Tag | Meaning |
|---|---|
| FIXED | The code now does what the document asked. Checked against the file and line given. |
| PARTIAL | Some of the request is in the code, some is not. |
| OPEN | Still as the document described. |
| DECIDED | The author recorded a deliberate decision not to act, or to act differently. |
| NOT STARTED | A planned feature with no code yet. |
| UNVERIFIED | Needs the live WoW client or controller hardware; cannot be settled from the repository. |
| NOT CHECKED | Not re-checked for this compilation. |

"Reported" means the status comes from a commit message and was not re-read in code.

**Important caveat.** No document in this set records a result from the live WoW client, except the error log in `Luaerrorissues.rtf` and the `/dump` build check cited in `Beta_Review_Assessment.md`. Every reviewer states they worked offline (stub harness, Lua 5.3, Python re-implementations). Claims about how cues *feel*, taint, and secret-value behaviour are hypotheses until tested in game.

---

## 1. Inventory

**Tracked by Git:** only `README.md`, `CURSEFORGE.md`, `LICENSE`, `PulseChecklist/tests/README.md`, `docs/dev-notes/QA_TEST_PLAN.md` (force-added despite the ignore rule) and `docs/ui-review/*`. Everything else below is **gitignored or untracked** (`.gitignore:19-24`) and exists only on this machine.

| # | Document | Date | Kind | Git |
|---|---|---|---|---|
| 1 | `README.md` | 09-24 | Public readme | tracked |
| 2 | `CURSEFORGE.md` | 09-24 | Public store page | tracked |
| 3 | `PulseChecklist/tests/README.md` | ~09-22 | Test harness guide | tracked |
| 4 | `docs/dev-notes/QA_TEST_PLAN.md` | 09-23 | In-game test plan | tracked (forced) |
| 5 | `docs/dev-notes/cloudreviewultra.md` | 09-22 | Two cloud code-review passes plus verdicts | ignored |
| 6 | `docs/dev-notes/outstanding.md` | 09-22 → 09-24 | Running issue ledger | ignored |
| 7 | `docs/dev-notes/Luaerrorissues.rtf` | 09-22 | Live-client error log and user issue list | ignored |
| 8 | `docs/dev-notes/Pulse-Combat-Casting-Regression-Investigation.md` | 09-22 | Regression hypotheses | ignored |
| 9 | `docs/dev-notes/Pulse-Updated-Crafting-Casting-Assessment.md` | 09-23 | Regression hypotheses (follow-up) | ignored |
| 10 | `docs/dev-notes/Pulse Minimap Button — Forbidden Action and Rendering Investigation.md` | 09-23 | Investigation | ignored |
| 11 | `docs/dev-notes/Pulse-Code-Review-Report.md` | 09-23 | Code review against Blizzard source | ignored |
| 12 | `docs/dev-notes/Pulse-Code-Review-Verification-Report.md` | 09-23 | Verification of #11 | ignored |
| 13 | `docs/dev-notes/Pulse-Code-Review-Comprehensive-Audit-Report.md` | 09-23 | Full audit | ignored |
| 14 | `docs/dev-notes/Pulse-Iterative-Code-Review-QA-Report.md` | 09-23 | QA sweep | ignored |
| 15 | `docs/dev-notes/Pulse-QA-Tooling-and-QoL-Recommendations.md` | 09-23 | Tooling proposal | ignored |
| 16 | `docs/dev-notes/Beta_Review_Assessment.md` | 09-23 | Triage of #17 plus action checklist | ignored |
| 17 | `docs/ReviewsofReviews/PulseHaptics-0.2.0-beta-review.md` | 09-23 | External beta review | ignored |
| 18 | `docs/ReviewsofReviews/PulseHaptics-0.2.0-beta-RC-review.md` | 09-23 | Release-candidate review | ignored |
| 19 | `docs/ReviewsofReviews/PulseHaptics-0.2.0-beta-code-review.md` | 09-24 | Code-level logic review | ignored |
| 20 | `docs/ReviewsofReviews/PulseHaptics_Haptics_Engine_Improvement_Report.md` | 09-24 | Engine and feel proposal | ignored |
| 21 | `docs/ReviewsofReviews/PulseHaptics-Engine-Improvement-Plan-review.md` | 09-24 | Review of #20 | ignored |
| 22 | `docs/ReviewsofReviews/PulseHaptics_Proposal_Review.md` | 09-24 | Review of #20 in light of #19 | ignored |
| 23 | `docs/ReviewsofReviews/PulseHaptics_Additional_Improvement_Review.md` | 09-24 | Design-language proposal | ignored |
| 24 | `docs/ReviewsofReviews/PulseHaptics-Additional-Improvement-Review-review.md` | 09-24 | Review of #23 | ignored |
| 25 | `docs/ReviewsofReviews/*.png` (3) | 09-24 | Diagrams: data flow, boot/sync lifecycle, engine frame pipeline | ignored |
| 26 | `docs/ui-review/Final Iterative UI QA.md` | 09-23 | Prompt for #27 | tracked |
| 27 | `docs/ui-review/Pulse_UI_QA_Final_Report.md` (+11 screenshots) | 09-23 | UI QA sign-off | tracked |
| 28 | `docs/PulseHaptics_PreRelease_Code_Review.md` | 09-24 | Pre-release review, "RELEASE BLOCKED" | ignored |
| 29 | `docs/PulseHaptics_Critical_Haptics_Engine_Review.md` | 09-24 | Engine signal-processing critique (H1–H19) | ignored |
| 30 | `docs/PulseHaptics_Haptics_Engine_Architecture_Explanation.md` | 09-24 | Target architecture explainer | ignored |
| 31 | `docs/PulseHaptics_Haptics_Engine_Implementation_Plan_and_Prompt.md` | 09-24 | 19-phase coding prompt | ignored |
| 32 | `docs/PulseHaptics_Engine_Architecture_Implementation_Readiness_Audit.md` | 09-24 | Code-grounded migration plan | ignored |
| 33 | `docs/PulseHaptics_Haptics_Rewrite_Analysis.md` | 09-24 | Where a rewrite pays off | ignored |
| 34 | `docs/PulseHaptics-drowning-detection-review.md` | 09-24 | Bug review plus patch | ignored |
| 35 | `PulseProfileReview/README.md` | 09-26 | Prototype addon readme | untracked |
| 36 | `ProfileReviewReports/Immersion-Ranged-Cue-Review.md` | 09-26 | Profile review output | untracked |

`docs/Archive/` is empty. The 11 UI screenshots and the 3 PNG diagrams were not transcribed. The data-flow PNG shows: WoW client → custom modules / event watchers (reading Registry: "190 cues") → cue gate (Fire/HoldIfEnabled, reading Database) → PlayMode / Hold → engine layers (reading Devices/schemas) → `C_GamePad.SetVibration`.

---

## 2. How the documents relate

```text
09-22  cloudreviewultra (#5) ──► outstanding (#6)       Luaerrorissues (#7) ──► Combat-Casting regression (#8)
09-23  Code-Review-Report (#11) ──► Verification (#12)                         └► Crafting-Casting assessment (#9)
       Comprehensive audit (#13) · Iterative QA (#14) · QA tooling (#15) · Minimap investigation (#10)
       UI QA prompt (#26) ──► UI QA final (#27)
       beta-review (#17) ──► Beta_Review_Assessment (#16) ──► RC-review (#18)
09-24  code-review (#19) ──► Engine Improvement Report (#20) ──► Plan-review (#21) and Proposal_Review (#22)
       Additional Improvement Review (#23) ──► its review (#24)
       PreRelease review (#28) · Critical engine review (#29) ──► Architecture explanation (#30)
       ──► Implementation plan (#31) ──► Readiness audit (#32) ──► Rewrite analysis (#33)
       Drowning review (#34)
       commits 990a765 (applies most beta/pre-release fixes) · ea0368a (saturating mixer, dual-lane attack, watchdog)
       f447944 (synchronous first step, role pool) · 239619c (PulseDebug hooks) · ac3d02f (StopAll on OnUpdate error)
09-26  PulseProfileReview prototype (#35) ──► Immersion: Ranged review (#36)
```

The pattern is: a review arrives, a second review checks it against the code, and then a fix commit lands. The 09-24 engine documents (#20–#33) propose several **different orders** for the same engine work (see section 5).

---

## 3. Per-document summaries

### Public and tracked documents

**#1 `README.md`.** Marketing readme. It claims:
- "202 distinct triggers and 21 categories", "over 1,000 interactive controls", "22 module watchers", 6 schemas
- "Zero-GC Engine Discipline (0 FPS Drops)", "100% Taint-Immune Gamepad UI … rather than dangerous Blizzard UI hooks"

It lists the commands `/pulse`, `/pulse test|profile|minimap|debug`, `/pdebug`, `/pcheck [export|import]` and the package matrix. It does not mention `/pulse stop|off|mute`.

**#2 `CURSEFORGE.md`.** Store page. It claims "202 distinct triggers" and "36 Haptic Modes", and describes the project as "Public Beta (v0.2.0-beta)" with credits and a disclaimer. `/pulse stop` is not mentioned.

**#3 `PulseChecklist/tests/README.md`.** Describes the offline suites: "Six Lua suites … Roughly seventy assertions, all green as of commit `cddf553`"; harness figures of "1,408 rows, 1,006 controls, 190 index entries"; and the METHOD_PREFIXES stub pitfall. It notes that `engine-test` was checked against the broken code.

**#4 `QA_TEST_PLAN.md`.** An in-game test plan covering:
- crafting and gathering cadence
- minimap rendering, dragging, and the combat-lockdown toggle
- Controller UI navigation, plus an optional `uiNavigateEdge` taint trial
- `taint.log` cleanliness
- the offline suite command

It has never been executed, or no results were recorded.

### dev-notes

**#5 `cloudreviewultra.md`.** Two cloud review passes: Core (4,598 lines) and Modules+UI (7,874 lines). It returned 10 findings:
1. CastActivity `SetActive` had no refcount (found twice, once from each side)
2. `LowOnly` schema did not mirror `HighOnly`; the reviewer's suggested fix named the wrong role
3. `driveChannel` closure allocated per frame (a nit)
4. `Encounter.lua` `sync()` wipes live encounter state
5. = #1
6. `World.lua` emote filter contradicts its comment (substring match on the player's name)
7. `questDetail` mapped to the broader `QuestGiver` interaction type (plausible)
8. `Flight.lua` never reseeds mount state
9. `clamp01` duplicated 7×
10. enum-with-literal-fallback duplicated 4×

Its meta-finding: `sync()` functions re-register events without reconciling cached state; `PlayerState.lua` and `Health.lua` show the right pattern. `PulseChecklist` and `PulseDebug` were not reviewed.

**#6 `outstanding.md`.** Running ledger, 14 items:
- Items #1, #3–#6, #8, #9, #11–#14 are marked FIXED or COMPLETED.
- #2 records 15 design documents cited from code comments that are missing from the repo (7 of them not on disk anywhere). **Decision: leave the citations as they are.**
- #7: `PulseChecklist` and `PulseDebug` have never been reviewed.
- #10: `LTrigger`/`RTrigger` channels are unconfirmed on the live client.

**#7 `Luaerrorissues.rtf`.** Live-client evidence from 2026-09-22:
- `Frame:RegisterUnitEvent(): Attempt to register unknown event "TRADE_SKILL_CRAFT_BEGIN"`, raised from `CastActivity.lua:250` on every built-in profile switch
- "Pulse has been blocked from action only available to blizzard UI"
- damage, block, dodge, parry and crit cues stopped firing (though they work from the test buttons)
- dropdown menu quality
- missing minimap button
- "Look at ChatGPT casting file. Don't change on whims."

**#8 Combat-Casting regression investigation.** Hypotheses:
- (a) damage/parry/block detection is stale: it should use `C_CombatText.GetCurrentEventInfo()`.
- (b) `castTexture` can fail silently because of secret `UnitCastingInfo` timing values, a duplicate cast-detection path in `Combat.lua`, and the `Pulse.IsCrafting()` suppression.

Recommended order: targeted diagnostic bypasses before any rewrite; do not use `COMBAT_LOG_EVENT_UNFILTERED`.

**#9 Crafting-Casting assessment.** Crafting is a specialised cast. The regression is most likely the interaction between two casting systems (CastActivity versus Combat's `castTexture`), where a stale `IsCrafting()` suppresses normal casts. Recommendation: bypass-test first, move ownership to CastActivity over time, no engine rewrite.

**#10 Minimap investigation.**
- The rendering defect: a 53×53 tracking border is anchored `TOPLEFT` on a 32×32 button.
- The `ADDON_ACTION_FORBIDDEN` suspect is the synchronous fan-out of the master toggle (`Database:Set("masterEnabled")` → every `BindFrame` `sync()` → Unregister/Register events). This is unproven; a `taintLog` capture is required.

**#11 Code-Review-Report.** Verified against `wow-ui-source-forever` 1.60.1.69913, it establishes that Forever is the 12.x engine (interface 120100) with `Clamp`/`Lerp` globals, and that `COMBAT_TEXT_UPDATE` carries only the type, with data via `GetCurrentEventInfo` (secret returns). Findings:
- `UnitCastingInfo` return 6 is `isTradeskill` (NeverSecret)
- allocation per call in `Engine:Set`
- idle OnUpdate handlers
- cross-realm emote matching (use `Ambiguate`)
- `activeProfile()` nil fallback

**#12 Verification of #11.** Most claims confirmed. The idle-OnUpdate finding is overstated for Crafting and Locomotion. `activeProfile()` nil is a narrow risk because `ruleFor` and the "Default" fallback already cover it. `UnitChannelInfo` also has `isTradeskill`. Two line citations were off by 10.

**#13 Comprehensive audit.** Findings:
- **C-01:** profile resolution is uncached when spec rules exist, costing many `pcall`s per frame
- **N-01:** `cooldownReady` passes cooldownIDs, not spellIDs
- **N-02:** Crafting idle detach and mid-craft reseed
- **N-03:** stealth polling instead of `UPDATE_STEALTH`
- nits: melee-range secret guard, StaticPopup string concatenation, sweep closure, tests README path

**#14 Iterative QA.** "Ready after minor fixes":
- I-01: `cooldownReady` locks to an empty set at login
- I-02: a stale `fallStartTime` causes false `landingHard`
- I-03: `threatLost` is suppressed when threat becomes nil
- minors: glide polling, untokened breath "dub" timer, UTF-8 frontier pattern, `targetCastStopped` wording, `HoldRolesIfEnabled` missing the category-master gate

It also says: **"STOP touching the Engine"**, the Database, and the ControllerUI poller.

**#15 QA tooling.** Proposes:
- P1: `scripts/test.sh`; a Play button in `/pcheck`
- P2: status filter tabs; right-click reverse cycling
- P3: a PulseDebug sticky last-fired HUD plus a Silence button; `/pcheck export`

**#16 Beta_Review_Assessment.** Triage of #17 with a 7-item checklist:
- secret guards in AlertUnitWatch and Combat `arg4`
- `pcall` around OnUpdate
- `PLAYER_LEAVING_WORLD` → `StopAll`
- refresh the device on `PLAYER_ENTERING_WORLD`
- `/pulse stop|mute`
- a local `issecretvalue`

It dismisses interface 160001 (a `/dump` showed 120100) and calls the `LowHealthFrame` dependency intentional.

### ReviewsofReviews

**#17 beta review.** Recommends:
- stuck-vibration safety: leaving-world stop, device refresh, OnUpdate `pcall`, emergency stop
- secret-value gaps
- **14 of 20 Controller UI cues default ON**, contradicting the Registry's own comment; ship them off
- TOC interface numbers
- packaging (`__MACOSX`, bundled companion addons, missing LICENSE)
- `_G.issecretvalue`
- stale docs

**#18 RC review.** Findings:
- PulseDebug hooks target methods that do not exist, and the "Hold 2s" button does nothing
- **30 of 59 checklist baseline IDs are orphaned**
- README/TOC claims do not match the code ("100% taint-immune", `/pulsedebug`, "loads every module", "~1,395 controls", "Non-commercial" versus MIT)

Hardening:
- malformed SavedVariables crash `Init`
- the version stamp can be overwritten downward
- `C_GamePad` `pcall`s are inconsistent
- the `hookRadial` guard
- the tab-mixin hook timing
- `tests/` ships to players
- `cue-audit` depends on the working directory
- untested interface numbers

**#19 code-level review.**
- 1.1: swim-stroke phase scrambles when the rate changes (absolute-time phase)
- 1.2: gait cadence units are off by 2×, cadence is uncapped, and the result is frame-rate dependent
- 1.3: `jumped` fires on the input, not the jump; two hooks
- 1.4: CastActivity swallows listener errors
- smaller notes: floating combat text dependency, `SetActiveUnit`, dedupe window, swing drift, stale caveats
- optimisations: synchronous first step, gate the idle gait tick, shared motion state

**#20 Engine Improvement Report.** Proposes priority, arbitration and gentle ducking first; then the PulseDebug inspector, state-based continuous haptics, blend policies (MAX / ADD_CLAMPED / DUCK / OVERRIDE), semantic primitives, a soft haptic budget, envelopes, variation, and a capability model. Rule: "abstract the engine, not the personality of the cues."

**#21 Review of #20.**
- Much of #20 already exists.
- The example levels are wrong: `damageTaken` is 0.06, not 0.76.
- Merge ducking, budget and priority into one mechanism.
- **Drop ADD_CLAMPED and OVERRIDE; keep MAX plus duck.**
- Demote `SetState`, because `Hold` fails safe.
- Shrink the semantic layer to `priority`.
- Add Phase 0 (the correctness bugs from #19).
- **Never ship a mix change without a legacy-mix switch and an offline test.**

**#22 Proposal review.** Same verdict: stabilise → instrument → measure → arbitrate → generalise. Milestone A is the #19 fixes plus the synchronous first step. Its blend list includes ADD_CLAMP and RMS as internal policies. "Do not add abstraction faster than you can validate the sensation it produces."

**#23 Additional Improvement Review.** Design ideas: a haptic vocabulary, an attention context, communicating cause, temporal storytelling, hysteresis, state/transition/event separation, confidence in inferred state, physical continuity, anticipation, impact energy, direction, perceptual calibration, a Haptic Laboratory, scenario replay, perceptual regression tests, frame-rate-aware representation, and silence as contrast.

**#24 Review of #23.** Maps the proposals against the code:
- **Already largely exists:** the vocabulary (35 modes), anticipation, stride continuity, calibration, single-cue testing.
- **Blocked:** impact energy (secret amounts), direction (motors differ by size, not position; combat events carry no direction), hysteresis (mostly boolean state).
- **New findings:** TAP and DOUBLE_TAP cover 47% of discrete cues, so the problem is collisions, not inconsistency; **the ocean detector uses English substring matching** (false positives such as "Searing Gorge", and it fails on localised clients).
- **Recommended order:** cue-call recorder → perceptual assertions in `engine-test` → shared motion state → category signature audit plus ocean fix → context factor plus stress lab.

### ui-review

**#26/#27 UI QA.** Verdict: "stop iterating; release-ready." Findings:
- Important: category masters (`ccMaster`, `controllerUIMaster`) appear only on the root page; the settings window needs the mouse in gamepad mode (`DRIVE_BLIZZARD_NAVIGATION = false`, keep it that way)
- Minor: truncated "Gamepad Controller Int…" label; duplicate "Default profiles" header; "Play" versus "Play it"; Activate button enabled on the already-active profile
- Optional: reorder the root page; wording of sentence-style cue labels

### Top-level 09-24 engine and pre-release documents

**#28 PreRelease review ("RELEASE BLOCKED").**

| ID | Finding |
|---|---|
| P0-01 | TOC should declare 16001 |
| P0-02 | Minimap table is not persisted |
| P1-01 | Master OFF does not stop playback |
| P1-02 | `PING_PIN_ADDED` is dead; use `UNIT_PING_PIN_ADDED` |
| P1-03 | SmartNavigation callbacks conflict with the taint strategy |
| P1-04 | CastActivity secret-key boundary |
| P1-05 | Phantom cue IDs in profiles |
| P1-06 | Metadata missing for Raiding and Questing |
| P2-01 | Trigger-hardware claims too strong |
| P2-02 | Legacy `GetSpellInfo` fallback |
| P2-03 | Dev-only files ship |

It also contains a regression suite and a taint test matrix.

**#29 Critical engine review (H1–H19).**
- Max blending destroys information; use saturating sum plus priority ducking, with MAX as an option.
- One smoothing filter for everything softens transients (a 75 ms attack reaches 37% at 35 ms); use per-class lanes.
- MicroFlutter is the wrong layer; use an output watchdog.
- Epsilon couples two concepts.
- The breakaway floor compresses the low end; use a dead-zone curve.
- Gamma semantics.
- Device defaults are hypotheses.
- No loudness model.
- No priority.
- Same-name cancellation is too aggressive for repeated transients.
- Add concurrency policies, declarative envelopes, channel capability states, a profiler and visualiser, and a calibration workflow.
- Do not globally lower `attackTau`; do not use unbounded addition.

**#30 Architecture explanation.** Explains the target pipeline in #29: intent → signal generator → arbitration → perceptual mixer → calibration → output driver. It keeps roles and schemas.

**#31 Implementation plan / prompt.**
- 19 phases.
- Migration order: watchdog → signal representation → response classes → mixer abstraction → saturating sum → priority → concurrency → envelopes → calibration → visualiser → module migration.
- 14 acceptance criteria and a "do not" list.

**#32 Readiness audit (code-grounded; the most conservative).**
- No full rewrite.
- First change: a behaviour-preserving `Core/Output.lua` boundary, with the watchdog disabled or gated.
- Then: watchdog on (with MicroFlutter kept) → extract the MAX mixer → arbitration metadata (REPLACE default) → **SATURATING_SUM and PRIORITY_DUCK opt-in, "default remains MAX"** → intent records → migrate direct callers → retire MicroFlutter only after hardware validation.
- It also has a risk register, a validation strategy and a "Do Not Implement Yet" list.

**#33 Rewrite analysis.** Rewrite only the signal lifetime, arbitration, mixer and envelope internals. **"Do not make SATURATING_SUM the universal mixer"; MAX stays the default until validated.**

**#34 Drowning review.** Two bugs:
1. `IsSwimming` overrides `IsSubmerged`.
2. Any timer stop while submerged counts as drowning (Water Breathing).

It includes a patch, 3 in-game assumptions, 7 unpatched findings (the thud is timer-based rather than damage-based, a throttle overrides the interval, heartbeat quantisation, no recovery model, an unguarded API call, a possible double cue, no verified baseline), and 5 suggested tests.

### Profile review (09-26)

**#35 PulseProfileReview README.** A prototype addon (`/pulsereview`) that records Yes/No per cue per profile in its own SavedVariables, and exports Markdown. It never writes to `PulseDB`.

**#36 Immersion: Ranged review.** 112 Yes, 77 No; it lists 189 of the 190 cues (`bankOpened` is absent). Notes:
- water textures are "No" pending refinement
- keep `breathTexture` and `drowningDamage`, drop `breathWarning`
- `jumped` Yes, `glideThrust` No

Compared with the seeded defaults: 20 cues are seeded ON but reviewed No, and 53 are seeded OFF but reviewed Yes. The report explicitly does not apply defaults.

---

## 4. Consolidated finding tracker (status as of 2026-09-28)

### 4.1 Engine and output

| Finding | Source | Status | Evidence |
|---|---|---|---|
| `StopAll` on `PLAYER_LEAVING_WORLD` | #16, #17 | FIXED | `Engine.lua:816-820` |
| Device refresh on `PLAYER_ENTERING_WORLD` | #16, #17 | FIXED | `Engine.lua:815`, `:822` |
| `pcall` around OnUpdate, with recovery | #16, #17 | FIXED | `Engine.lua:651-667` (`StopAll` added in `ac3d02f`) |
| Master OFF stops playback and voids timers | #28 P1-01 | FIXED (already present before the review) | `Engine.lua:824-832`, generation guards `:406`. The master-OFF → `StopAll` hook has existed since the initial commit `110cebc`, so P1-01 was inaccurate when written. |
| Emergency `/pulse stop\|off\|mute` | #16, #17 | PARTIAL | `Panel.lua:539-545` exists, but only calls `StopAll`. Continuous `Hold` cues re-arm on the next tick by design (`Engine.lua:48-50`), so this is a momentary stop, not a mute. Not documented in the command tables (`README.md:78-91`, `CURSEFORGE.md:113-122`). |
| Synchronous first `PlayMode` step | #19, #21, #22 | FIXED | `Engine.lua:398-402` |
| `scratchRoles` in `Set`/`Hold` | #11, #12 | FIXED | `Engine.lua:198`, `:214-218` |
| `driveChannel` hoisted | #5 | FIXED | `Engine.lua:424` |
| Consistent `pcall` around `C_GamePad` | #18 | PARTIAL | Raw-hold path still calls bare `SetVibration` (`Engine.lua:518`, `:529`) |
| Output watchdog (250 ms) | #29, #31, #32 | FIXED | `Engine.lua:58`, `:477-486` (`ea0368a`) |
| Separate transient/continuous attack | #29, #31 | FIXED | `Engine.lua:446-453` |
| Mixer beyond MAX | #29, #31 vs #21, #32, #33 | IMPLEMENTED, contrary to #21/#32/#33 | Saturating sum for continuous layers, transients layered on top (`Engine.lua:537-588`). No switch back to the old mix exists (grep found none). Two harness assertions cover it: saturating sum > 0.40 for 0.30 + 0.20, and a transient riding on top (added in `ea0368a`). |
| Remove MicroFlutter | #29, #31, #32 | OPEN (by design until hardware check) | 10 call sites remain, e.g. `Movement.lua:221`, `Environment.lua:245-263`. #32 says to keep it until the watchdog is validated on hardware. |
| Priority / ducking / concurrency policies / envelopes / capability states | #20, #29, #31, #32 | NOT STARTED | No matching code |
| `Core/Output.lua` / `Mixer.lua` extraction | #32 | NOT STARTED | Files do not exist |
| Floor linear lift → dead-zone curve | #29 H7, #31 | OPEN | `Engine.lua:435-438` |
| Same-name cancellation for repeated transients | #29 H12, #32 | OPEN | `Engine.lua:296-297`, `:406` |
| **Pooled role tables overwritten before delayed steps fire** | this session (new) | OPEN (bug) | 16-table ring `Engine.lua:200-212`, captured at `:405-410`. Probe: a full-strength BURST played at 0.045–0.065 instead of 0.45–0.65 when 20 weak cues followed. Introduced in `f447944`, which acted on #29's advice about allocation per step. |
| Uncommitted: onset force-send, minimum step/gap duration | work in progress | uncommitted | `Engine.lua:367-396`, `:472-480`. The comment says transients force a send; the code forces only onsets. |

### 4.2 CastActivity, casting and crafting

| Finding | Source | Status | Evidence |
|---|---|---|---|
| `SetActive` refcount | #5 #1/#5 | FIXED | `CastActivity.lua:372`, `:396-429` |
| `TRADE_SKILL_CRAFT_BEGIN` registered as a unit event | #7 | FIXED | `CastActivity.lua:420-422` |
| Listener errors swallowed | #19 1.4, #22 | FIXED | `CastActivity.lua:50-61` (xpcall) |
| Sweep closure hoisted | #13 T-03 | FIXED | `CastActivity.lua:385-391` |
| Secret-value boundary on keys | #28 P1-04 | OPEN | `keyFor` does `tostring(castGUID)` with no `issecretvalue` check (`CastActivity.lua:65-70`) |
| Fold AlertGeneric into CastActivity | `CastActivity.lua:18-24` | OPEN | `AlertGeneric.lua:28`, `:51-73` |
| `castTexture` duplicate detection / `IsCrafting` suppression / timing secrecy | #8, #9, #11 | PARTIAL | Start/stop now comes from CastActivity (`Combat.lua:525+`), but `IsCrafting()` suppression (`:444`) and `UnitCastingInfo` timing (`:453`) remain. `isTradeskill` was added to the cast tick in `2fd5c92` and deliberately removed in `d44badf` ("fix tradeskill dead-zone"); `Crafting.lua`'s `sync` uses it for reseeding (`974d49f`). |
| Crafting idle detach and mid-craft reseed | #13 N-02 | PARTIAL / NOT CHECKED | 0.5 s failsafe in `IsCrafting` (`Crafting.lua:310-335`); reseed not checked |
| Uncommitted: 30 s stale timeout plus active-cast protection | work in progress | uncommitted, test ungood | `CastActivity.lua:35`, `:331-359`. New test uses the wrong key (`crafting-test.lua:369-385`), so 3 assertions fail and 1 passes vacuously. |

### 4.3 Database and profiles

| Finding | Source | Status | Evidence |
|---|---|---|---|
| Minimap table persistence | #28 P0-02 | FIXED | `Database.lua:1572-1583` |
| Phantom cue IDs in overrides | #28 P1-05 | FIXED | Probe: 0 unknown IDs across 11 override tables (`990a765`) |
| Metadata for Raiding and Questing | #28 P1-06 | OPEN | 12 names (`Database.lua:54-67`), 10 metadata entries (`:69-172`) |
| `activeProfile()` fallback | #11, #12 | FIXED | `Database.lua:1533-1540` |
| Uncached spec resolution | #13 C-01, #19 2.1 | PARTIAL | `cachedSpecID` cache (`Database.lua:1145-1170`); correctness on Forever is UNVERIFIED (#14 regression risk 3) |
| Version stamp overwritten downward | #17, #18 | OPEN | `Database.lua:899` stamps unconditionally |
| Malformed SavedVariables crash `Init` | #18 | NOT CHECKED | — |
| Rename of the active profile notifies listeners | work in progress | uncommitted | `Database.lua:1449-1453`; harness asserts it and passes |
| Apply the profile review to seeded defaults | #36 | DECISION NEEDED | 20 ON-but-No, 53 OFF-but-Yes; seeding only fills gaps (`Database.lua:832-844`), so existing users need a migration (`DB_VERSION = 7`, `:27`) |
| Revisit water textures (`swimTexture`, `waterTexture`, `oceanTexture`) after refinement | #36 (`Immersion-Ranged-Cue-Review.md:15-16`) | OPEN | No refinement commit since the review (09-26). Feel is UNVERIFIED. Related: the ocean detector's substring matching (4.4). |

### 4.4 Modules

| Finding | Source | Status | Evidence |
|---|---|---|---|
| Encounter `sync` wipes live state | #5 #4 | FIXED | Reseeds via `IsEncounterInProgress` (`Encounter.lua:75-82`) |
| Flight mount reseed | #5 #8 | FIXED | `Flight.lua:28-38` |
| Cross-realm emote | #11, #12 | FIXED | `Ambiguate` (`World.lua:52`) |
| Emote frontier pattern and UTF-8 names | #14 M-03 | OPEN | `World.lua:57` |
| LowOnly schema mirror | #5 #2 | FIXED | `Schemas/LowOnly.lua:18-21` (high 0.6) |
| `clamp01` duplicates | #5 #9 | OPEN | 6 files still define it |
| `cooldownReady` IDs and login race | #13 N-01, #14 I-01 | PARTIAL | `COOLDOWN_VIEWER_DATA_LOADED` registered (`Combat.lua:188`), resolved only when count > 0 (`:114-116`), `GetCooldownViewerCooldownInfo` used (`:97`). Works in game? UNVERIFIED |
| `threatLost` on nil threat | #14 I-03 | FIXED | `status = raw or 0` (`AlertThreat.lua:58`) |
| Stale `fallStartTime` | #14 I-02 | FIXED | `Movement.lua:141-146` |
| `jumped` fires on input; two hooks | #19 1.3 | PARTIAL | Guards reported added (`990a765`); still two hooks (`Movement.lua:114`, `Locomotion.lua:401`); no shared timestamp |
| Swim-stroke phase integration | #19 1.1 | FIXED (reported) | `990a765` "per-frame swimPhase accumulator" |
| Gait cadence cap | #19 1.2 | FIXED | `Locomotion.lua:339-340` (8.0) |
| Gait cadence units | #19 1.2 | OPEN / UNVERIFIED | Label still "Run cadence (steps/s)" (`Registry.lua:2660`); whether the maths was changed was not checked |
| Breath "dub" timer untokened | #14 M-02 | OPEN | `Environment.lua:153-155` |
| Drowning bugs 1 and 2 | #34 | FIXED | `Environment.lua:24-39`, `:107-110`, `:217-219` |
| Drowning tests and the 7 unpatched items | #34 §7–8 | OPEN | No environment suite in `scripts/test.sh:20-28` |
| Melee-range secret guard | #13 T-01 | FIXED | `Combat.lua:943` |
| Stealth event-driven | #13 N-03 | FIXED | `974d49f`: `UPDATE_STEALTH` drives the state (`PlayerState.lua:107`); the 0.1 s tick is attached only while stealthed and detaches itself |
| StaticPopup string concatenation | #13 T-02 | PARTIAL | Cached array plus fallback concatenation (`PlayerState.lua:136`, `:145`) |
| Glide polling | #14 M-01 | OPEN | No `PLAYER_CAN_GLIDE_CHANGED` in `Flight.lua` |
| `HoldRolesIfEnabled` category-master gate | #14 M-05 | FIXED | `Init.lua:151-152` |
| `targetCastStopped` wording | #14 M-04 | FIXED | `974d49f` rewrote the caveat to "interrupted by a kick, stun, or counter-spell"; the one-line desc stays generic (`Registry.lua:1398`) |
| `questDetail` mapping | #5 #7 | UNVERIFIED | Needs an in-game `/pulse debug` session |
| Ocean detector: English substrings | #24 | OPEN | `Movement.lua:57-61` |
| Legacy `GetSpellInfo` fallback | #28 P2-02 | OPEN | `Crafting.lua:266-267` |
| Floating-combat-text dependency | #19 1.5 | UNVERIFIED | — |
| Category signature audit (TAP/DOUBLE_TAP = 47%) | #24 | NOT STARTED | — |
| Shared motion state | #19, #22, #24 | NOT STARTED | — |

### 4.5 Controller UI and taint

| Finding | Source | Status | Evidence |
|---|---|---|---|
| Controller UI cues default ON (14 of 20) | #17, #16 §3.1 | OPEN (decision) | Probe count against the Registry |
| SmartNavigation edge callbacks | #28 P1-03, #4 §3.2 | OPEN (default off, live test pending) | `ControllerUI.lua:97-138` |
| `hookRadial` guard; tab-mixin hook timing | #18 | NOT CHECKED | — |
| Minimap master-toggle forbidden action | #7, #10 | UNVERIFIED | Combat-lockdown guard exists; the protected function has never been captured in `taintLog` |
| Minimap border anchored `TOPLEFT` | #10 | OPEN (disputed) | `Minimap.lua:162-163`. **Unverified:** common minimap-button code anchors the tracking border the same way, so this may be intended. |

### 4.6 Companion tools, tests and packaging

| Finding | Source | Status | Evidence |
|---|---|---|---|
| PulseDebug hooks target methods that don't exist | #18 | FIXED | `PulseDebug/UI.lua:337-378`, `239619c` |
| PulseDebug "Hold 2s" button | #18 | OPEN (inference) | Calls `Pulse:Hold("debug_hold", …)` → `HoldIfEnabled`, which returns unless `debug_hold` is a registered, enabled cue (`Init.lua:97-107`), so it still does nothing. `Engine.CancelAll` still referenced (`UI.lua:689`). The offline test hides this: its fake engine still defines `HoldLayer` and `CancelAll` (`pulsedebug-test.lua:321`, `:343`). |
| Checklist baseline orphans | #18 | OPEN | Probe: still **30 of 59** `BASELINE_ENTRIES` IDs not in the Registry |
| Test asserting baseline IDs exist in the Registry | #18 | OPEN | Would have failed |
| Harness loads the full TOC | #18 | OPEN | Only 3 modules in `harness.lua:562-564` |
| Unified test runner | #15 | FIXED, with a defect | `scripts/test.sh`. Under `set -e`, a crashing suite or luacheck warning exits with no output (`:2`, `:82`, `:122`). The pattern was copied from the blueprint in #15 (`set -euo pipefail` + `OUTPUT=$(lua …)`). |
| `cue-audit` path from repo root | #17, #18 | FIXED | `990a765` |
| Checklist: right-click reverse cycling | #15 | FIXED | `Checklist.lua:376` |
| Checklist: export/import | #15 | FIXED | `Checklist.lua:250-254`; README |
| Checklist: Play button, status filters | #15 | FIXED | `b22e6bd`: ▶ button (`Checklist.lua:378-393`), filter tabs (`:278-345`). An earlier draft of this file marked it OPEN; that was a truncated grep. |
| PulseDebug sticky HUD and silence | #15 | FIXED (reported) | `b22e6bd` |
| Packaging: clean zips, standalone, LICENSE, tests excluded | #17, #18, #28 P2-03 | FIXED | `scripts/package.sh` |
| `_G.issecretvalue` stub | #16, #17, #18 | OPEN | `Init.lua:12-16` |
| PulseChecklist and PulseDebug never code-reviewed | #5, #6 #7 | OPEN / UNVERIFIED | No review document covers them |
| PulseProfileReview prototype quality | this session | OPEN | Not linted, tested or packaged. `refresh()` creates frames for every row on each click (`Review.lua:166-225`); reads write SavedVariables (`:27-35`). |

### 4.7 UI polish (#27)

| Finding | Status | Evidence |
|---|---|---|
| "Gamepad Controller Int…" truncation | FIXED | `Registry.lua:81`, `:3160` |
| Duplicate "Default profiles" header | FIXED | Only the page label remains (`Spec.lua:1823`) |
| "Play" vs "Play it" | FIXED | No "Play it" left in `Spec.lua` |
| Activate on the active profile | FIXED | Button reads "Active" (`Spec.lua:1097-1099`) |
| Category masters missing from category pages | FIXED | `25ebf1a`: "governed by the master switch" notices (`Spec.lua:620`, `:626`). An earlier draft marked it OPEN; that was a truncated grep. |
| Settings window needs the mouse in gamepad mode | DECIDED | Keep `DRIVE_BLIZZARD_NAVIGATION = false` |

### 4.8 Documentation and claims

| Claim | Source | Status | Evidence |
|---|---|---|---|
| "202 cues" in README and CURSEFORGE | this session | OPEN | `README.md:72`, `:86`, `:100`, `:102`; `CURSEFORGE.md:15`, `:77`, `:120`. `cue-audit`: 190 cues. 202 counts 12 sidebar page IDs (`Registry.lua:2825`). Introduced by `790ce76` (section 9.3). |
| Trigger-hardware claims too strong | #28 P2-01, #6 #10 | OPEN | `README.md:40` ("Impulse trigger motor mappings"); `Devices.lua:250` ("the one listed controller where trigger vibration genuinely exists"), `:263`. `CURSEFORGE.md:54` is softer ("with rumble fallback where supported"). Whether `LTrigger`/`RTrigger` actuate on the live client is UNVERIFIED; no capability probing exists (see channel capability states, 4.1). |
| "36 Haptic Modes" in CURSEFORGE | this session | OPEN | `cue-audit`: 35 |
| "100% Taint-Immune … rather than dangerous Blizzard UI hooks" | #18 | OPEN | `README.md:32`; `hooksecurefunc` is used in ControllerUI, Interaction, Movement, Locomotion |
| "Zero-GC (0 FPS Drops)" | #18 | OPEN (overclaim) | Measured for the engine tick only; module ticks unmeasured |
| TOC "Non-commercial" vs MIT LICENSE | #18 | OPEN | `PulseHaptics.toc:10` |
| Interface 16001 vs 120100 | #17, #28 P0-01, #16 | DECIDED (120100 by `/dump`); 11.x numbers untested | TOCs line 1; `d293bb0` |
| Tests README counts and path | #13 T-04, #17 | PARTIAL | Path fixed; still "six suites", `cddf553`, 1,408 / 1,006 (actual: 7 suites, 1,413 / 1,010) |
| QA_TEST_PLAN stale | this session | OPEN | `/pulsedebug`, old icon, `Pulse` directory, "112 tests" |
| `Settings.lua` comment points at the old `Pulse\Media\welcome` path | #17 | OPEN | `UI/Settings.lua:34` |
| Registry header "21 Core/Modes.lua shapes" | this session | OPEN | `Registry.lua:8` |
| Cited design docs missing from the repo | #6 #2 | DECIDED (leave) | — |
| Stale "untested" caveats vs checklist baseline | #19 1.5 | NOT CHECKED | — |

---

## 5. Where the documents disagree

1. **Touch the engine or not.** #14 (09-23): "STOP touching the Engine … optimal and rock-solid." The 09-24 set (#20–#33) proposes staged engine work. The code followed 09-24 (`ea0368a`, `f447944`).
2. **Default mixer.**
   - #29, #30 and #31 recommend saturating sum for continuous textures.
   - #32 says "default remains MAX"; SUM is opt-in.
   - #33 says "Do not make SATURATING_SUM the universal mixer."
   - #21 says "Drop ADD_CLAMPED" and "Do not ship a mix change without a legacy-mix switch and an offline test."
   - **The code shipped saturating sum as the default with no switch back to the old mix.** Two harness assertions cover the new mix (`ea0368a`).
3. **First engine step.**
   - #31: watchdog first.
   - #32: a behaviour-preserving `Output.lua` extraction first, watchdog gated.
   - #21 and #22: Phase 0 correctness fixes, then the inspector.
   - #24: a cue-call recorder first.
   - The code added the watchdog inline, without extraction.
4. **Blend vocabulary.** #20: MAX / ADD_CLAMPED / DUCK / OVERRIDE. #21: MAX plus DUCK only. #22: six policies including RMS and MULTIPLY. #29: MAX / SATURATING_SUM / PRIORITY_DUCK.
5. **State ownership.** #20 wants `SetState`; #21 says `Hold` fails safe, so demote it; #22 and #23 favour state-based continuous haptics.
6. **Release readiness.**
   - #14: "Ready after minor fixes."
   - #18: "No blockers in the core addon."
   - #27: "Release-ready. Stop iterating."
   - #28: "RELEASE BLOCKED."
   - Most of #28's blockers are now FIXED (section 4); P1-04, P1-06 and P2-02 remain.
7. **Minimap border.** #10 calls the `TOPLEFT` anchor "an objective layout error"; this may be the conventional pattern (unverified). The 09-23 icon rework (`outstanding.md` #13) changed the icon but kept the anchor.
8. **Allocation in `PlayMode`.** #32 calls it bursty and low priority; #19 lists "precompute mode schedules" as low priority. The fix that was applied (a role-table ring pool, `f447944`) introduced the aliasing bug in 4.1.

---

## 6. Open decisions collected from the documents

1. Mixer policy: keep saturating sum, revert to MAX by default, or add a legacy switch (#21, #32, #33 versus current code).
2. Engine roadmap: which of #31, #32 or #22 is the plan of record? There is no tracked roadmap.
3. Controller UI cues: ship 14 of 20 ON or all OFF until seen in game (#17, #16 §3.1)?
4. Should `uiNavigateEdge` (SmartNavigation callback) stay available at all (#28 P1-03)? The profile review marks it Yes.
5. Checklist baseline: remap the 13 renamed IDs and decide on the 17 merged or removed ones (#18).
6. `_G.issecretvalue`: keep the global stub or scope it locally (#16, #17, #18)?
7. Interface numbers: keep `110200, 110100` untested or drop them (#17, #18)?
8. Emote cue: fire on emotes aimed at the player, or only on the player's own (#5 #6)? The code currently fires on both.
9. Apply the Immersion: Ranged review to shipped defaults, with a migration, or keep it as a record (#36)?
10. PulseProfileReview: track and ship, or keep as a local tool (#35)?
11. `/pulse stop` semantics: momentary stop versus session mute (#16, #17).
12. Cited-but-missing design documents: `outstanding.md` #2 decided to leave them. Revisit if the repo goes public?

---

## 7. In-game verification backlog (merged from #4, #14, #28, #32, #34 and others)

- **Hardware:** does `LTrigger`/`RTrigger` actuate? Does the 250 ms watchdog keep continuous textures alive without MicroFlutter? How long does `SetVibration` persist? Test on ERM, LRA and trigger-capable pads.
- **Taint:** run with `/console taintLog 1|2`; test master toggle ON/OFF (minimap, LDB, slash), SmartNavigation edge, radial, tabs, combat entry/exit, gamepad enable/disable, settings open/close; check `taint.log` is clean.
- **Casting/crafting:** normal cast, craft, a cast right after a craft, channel, interrupt; confirm `castTexture` is not suppressed; gathering path (CAST vs CRAFT); 10 s+ casts (Hearthstone) with the new sweep.
- **Combat text:** damage, crit, block, parry and dodge fire in raids; check dependence on the floating-combat-text setting.
- **cooldownReady:** `/dump C_CooldownViewer.IsCooldownViewerAvailable()` and category-set contents.
- **Drowning:** the 3 assumptions in #34 §6; scenarios A, B and C.
- **Movement:** stairs/slopes `IsFalling` flicker; mounted gait at 30 / 60 / 144 fps; ocean detection in "Searing Gorge" and "Deeprun Tram".
- **Low health:** `STOP_GRACE` stability near 35% HP with HoTs.
- **Minimap:** position and visibility survive `/reload`; forbidden-action capture.
- **Profiles:** spec-change cache invalidation on Forever (`PLAYER_SPECIALIZATION_CHANGED` at trainers).
- **`questDetail`:** does the QuestGiver interaction fire on hand-ins?

---

## 8. Stale statements inside the documents

- #3 (tests README): "six suites", "~seventy assertions", `cddf553`, 1,408 / 1,006. Actual: 7 suites, 1,413 rows, 1,010 controls.
- #4 (QA plan): `/pulsedebug` (actual `/pdebug`), `Spell_Nature_WispSplode` icon (replaced by `Media/icon.tga`), `Pulse` directory (actual `PulseHaptics`), "5 suites (112 tests)".
- #1 and #2: 202 cues (actual 190), 36 modes (actual 35), no `/pulse stop`.
- #13 says `Registry.lua` has "190 Cues"; #11 and #12 cite pre-rename `Pulse/…` paths and line numbers that have since moved.
- #32 describes the engine as MAX-mixed with no watchdog; that was true of the 0.2.0-beta zip it audited, but no longer (`ea0368a`).
- #29 and #30 describe MicroFlutter as the keepalive; the watchdog now exists alongside it.
- #6 lists "110 entries" for PulseChecklist; the cue count is 190.
- #36 says "0 not reviewed" but omits `bankOpened`.

---

## 9. Commit history reconciliation (added 2026-09-28)

### 9.1 Method

- Read the full message of all 79 commits (78 plus 1 merge, `110cebc` 2026-09-22 14:49 → `ac3d02f` 2026-09-24 23:09) and every per-file stat.
- Measured the real code change of each commit with whitespace ignored (`git show -w --ignore-cr-at-eol`, `.lua`/`.toc`/`.sh` only).
- **Read the diffs in full** for the fix and engine commits: `8e7bb57`, `2fd5c92`, `43db5af`, `d9f590f`, `b6601d6`, `4c5991e`, the minimap series (`3f6bdd3`, `dffdb83`, `3da1c5f`, `6410283`, `ee38be8`), `974d49f`, `25ebf1a` (Spec part), `990a765`, `ea0368a`, `a97acb7`, `790ce76`, `f447944`, `239619c`, `580e69f`, `ac3d02f`, and the relevant hunks of `b22e6bd`, `d44badf`, `6cfe986`.
- **Not read line by line:** large feature commits (`3fb5a0f`, `ef8d118`, `85d639e`, `b39e6a6`, `c137c07`, `68f96d0`, `d68ceaa`, `1142c11`, `6b2d126`, `6d0b323`, `a88fcc0`, `fc21210`, `3f3d7ec`, `da734ca`, `6cfe986` body). Only their messages, stats and targeted `git log -S/-G` searches were used.
- Every claim below was then checked against the current file.

**Corrections to earlier drafts of this file**, found during this pass: checklist play buttons and filter tabs exist; master-switch notices exist; stealth polling is fixed; the `targetCastStopped` caveat is fixed; a harness mixer test exists; PreRelease P1-01 was already satisfied. All six are corrected in section 4. Three of them came from truncated grep output (`head -N`).

### 9.2 Timeline: document → commit that acted on it

| Document (time written) | Acting commit(s) | Result |
|---|---|---|
| #5 cloud review (09-22) | `8e7bb57` 09-22 17:08 | All four "confirmed" bugs fixed in one commit: refcount, Encounter reseed, LowOnly 0.6, Flight reseed. Verified in diff and current code. |
| #7 error log (09-22 20:35) | `b39e6a6` 09-22 23:48 | Trade-skill events moved to plain `RegisterEvent`. The same commit added the `.rtf` to Git; `e3838db` removed it. |
| #8/#9 casting regression (09-22/23) | `11622b7`, `2fd5c92`, `d44badf`, later `580e69f` | Combat text moved to `GetCurrentEventInfo`. `castTexture` start/stop moved onto CastActivity. `isTradeskill` suppression was added (`2fd5c92`) and then **deliberately removed** (`d44badf`, "tradeskill dead-zone"). `IsCrafting()` suppression remains. |
| #10 minimap (09-23 ~09:37) | `3f6bdd3`, `dffdb83`, `3da1c5f`, `6410283`, `ee38be8` | Seven minimap commits in ~5 h (`6d0b323` → `ee38be8`). The circular mask was added, removed, re-added (`3da1c5f`) and removed again (`6410283`, "black button"). **The 53×53 `TOPLEFT` border the doc called an objective error was never changed** (`Minimap.lua:162-163`). Combat guard and 0.3 s debounce added (`3f6bdd3`). |
| #11/#12 code review (09-23 ~09:20–09:37) | `2fd5c92` 09-23 12:28 | `scratchRoles`, `activeProfile` fallback, `Ambiguate`, idle cast-tick detach. Despite its title, this commit changes only ~3 lines of `Engine.lua`; the 927-line Engine diff is reformatting. It also committed five dev docs, which `fd41c1b` removed 14 minutes later. |
| #13 audit (09-23 14:21), #14 QA (18:04) | `974d49f` 09-23 19:40 | Spec cache, `HoldRolesIfEnabled` gate, label, `targetCastStopped` caveat, `threatLost`, `cooldownReady`, melee-range guard, Crafting detach/reseed, `fallStartTime` expiry, stealth events, sweep hoist. All verified. |
| #27 UI QA (09-23 18:15) | `25ebf1a` 09-23 19:40 | All four minor items plus master notices. Verified (`Spec.lua:620`, `:626`, `:1097-1099`). |
| #15 tooling (09-23 18:31) | `b22e6bd` 09-23 19:40 | `test.sh`, ▶ buttons, filter tabs, right-click cycling, export, sticky HUD, Stop All. Verified. **`test.sh` inherited the blueprint's `set -e` defect.** |
| #17 beta review (09-23 21:31), #16 assessment (22:52), #19 code review (09-24 08:27), #28 pre-release (18:01), #34 drowning (18:41) | `990a765` 09-24 20:28, `96c5c87` 20:34 | Leaving-world stop, device refresh, OnUpdate `pcall`, `/pulse stop`, secret guards, minimap `Set`, phantom IDs, `UNIT_PING_PIN_ADDED`, `xpcall`, swim phase (`Movement.lua:327`, `TWO_PI` at `:33`), jump guards (`Movement.lua:114-126`, `Locomotion.lua:401-412`), cadence cap 8.0, drowning patch. **All verified in current code.** Not done from the same docs: `_G.issecretvalue`, profile metadata, `GetSpellInfo`, version stamp, Controller UI defaults. |
| #29–#33 engine docs (09-24 18:10–18:40) | `ea0368a` 20:51, `a97acb7` 21:05 | Watchdog, separate transient attack (`transientAttackTau` per device class) and saturating sum shipped ~2 h after the audit that said "default remains MAX". Output/Mixer extraction, priority and concurrency: none. |
| #18 RC review (09-23 23:21) | `239619c` 09-24 22:50 | PulseDebug hooks fixed, plus `Pulse.Fire/Hold` aliases added. **Baseline orphans, README taint/GC claims, TOC "Non-commercial", full-TOC harness: not addressed.** "Hold 2s" still does nothing, and the test's fake engine still defines `HoldLayer`/`CancelAll`, so the test cannot catch it. |
| #19 1.5 floating combat text | `2fd5c92` | `/pdebug why` now reports the `enableFloatingCombatText` CVar (`PulseDebug/Debug.lua:265-266`). The cue itself does not check it. |

### 9.3 Changes no document asked for, and what they did

| Commit | Change | Assessment |
|---|---|---|
| `f447944` | 16-entry role-table ring pool for `PlayMode` steps | **Introduced a bug.** Before it, every delayed step captured its own new `roles = {}`. After it, pooled tables are wiped and rewritten before earlier timers fire (reproduced; section 4.1). #32 and #19 had both rated this allocation low priority. |
| `ea0368a` | Saturating-sum default mixer | Asked for by #29/#31; explicitly advised against as a default by #21, #32 and #33. There is no switch back to the old mix. |
| `43db5af` → `d9f590f` → `b6601d6` → `4c5991e` (09-23 00:48 → 09:10) | SmartNavigation edge callbacks: enabled, removed, commented out, re-enabled with the cue off by default | `d9f590f`'s own comment says `RegisterCallback` "invokes AttributeDelegate:SetAttribute on a SecureFrame … triggers ADDON_ACTION_FORBIDDEN". `4c5991e` re-enabled the same call 17 minutes later. Turning the cue on therefore calls a function the codebase itself calls forbidden. `4c5991e` also removed `uiNavigateEdge`/`pingPinAdded` from five profiles. |
| `d68ceaa` (09-23 00:05) | 11 Controller UI cues default ON | Predates the beta review that asked for them OFF. Never reverted: 14 of 20 are ON now. |
| `790ce76` (09-24 21:31, "reconcile README") | README cue count 190 → **202**, "21 pages" → "21 categories" | **Introduced a wrong claim.** 190 was correct and had been confirmed by the RC review. `1bb065f` copied 202 into CURSEFORGE a minute later. The Registry defines 16 categories. |
| `790ce76` → `d293bb0` (5 min apart) | TOC interface list cut to `120100`, then restored to `120100, 110200, 110100` | A reversal with no recorded reason. `790ce76`'s comment calls the 11.x builds "unvalidated". |
| `580e69f` | Craft-completion matching by castGUID / pendingKey / castSpellID, and "any finished cast while crafting" as a last resort | Fixes craft completion. **Inference, unverified:** when `crafting.castGUID` is unset, `_OnFailed`/`_OnInterrupted` end the craft on *any* failed cast, and `_OnSucceeded` treats *any* instant cast as `CRAFT_COMPLETE` if nothing else is pending (`CastActivity.lua:128-140`, `:190-192`, `:222-224`). This depends on the in-game order of `TRADE_SKILL_CRAFT_BEGIN` and `UNIT_SPELLCAST_START`. |
| `6cfe986` (09-23 20:37) | Checklist "pre-verified" baseline, 59 entries | **30 of the IDs never existed in this repository's Registry**, not even in `110cebc` (`git log -S` finds nothing). The "verified" statuses were imported from a different build. `27841d9` tests only `locomotion`. |
| Whitespace reformat commits | e.g. `f6d03a2` (1,258/1,257 lines, 8/7 real), `b39e6a6` (9,677 raw, 2,352 real), `2fd5c92` (3,232 raw, 76 real code) | Hides the real changes from `git log --stat` and `git blame`. Use `-w` when reviewing. |
| Working tree (uncommitted) | 30 s sweep with active-cast protection, onset force-send, minimum step/gap duration, rename notify | Not in any doc. The new test is broken (wrong key). |

### 9.4 Documents that called something FIXED before it was

| Document | Claim | Reality |
|---|---|---|
| #6 `outstanding.md` #5 | "PulseDebug gaps — FIXED" (event log, Hold button) | The hooks targeted methods that did not exist until `239619c` (09-24 22:50). "Hold 2s" still does nothing. |
| #6 #12 | `pingPinAdded` fixed in `0322450` with `PING_PIN_ADDED` | #28 called that event dead; `990a765` added `UNIT_PING_PIN_ADDED`. |
| #11, #12, #13, #14 | "Pulse registers no callbacks on SmartNavigation"; "do not re-introduce callbacks" | `4c5991e` (09-23 09:10) had already re-introduced them, before #11/#12 were written (~09:20–09:37). The code exists; it runs only when the cue is on. |
| #28 P1-01 | "Master OFF does not stop existing haptic playback" | The master → `StopAll` hook and generation guards date from `110cebc`. |
| #27 | "Leave the 190-cue data model … fully verified" | Accurate then; the public docs later drifted to 202 (`790ce76`). |

### 9.5 Net effect on section 3's open list

Unchanged by the history pass: the role-pool bug, `_G.issecretvalue`, metadata, `GetSpellInfo`, version stamp, baseline orphans, the Hold button, the border anchor, the ocean detector, the breath "dub" timer, `clamp01` duplicates, Controller UI defaults, the README/CURSEFORGE 202/36 claims, the mixer policy decision, and the working-tree test failure.

Added by the history pass:
- the PulseDebug test fake masks the Hold-button bug
- the baseline IDs came from another build
- the SmartNavigation callback is self-described as forbidden but reachable
- `580e69f`'s fallback matching is a possible misclassification risk

---

## 10. Planning review and next phase (2026-09-28 session)

This section records the rest of the 2026-09-28 session: the first planning review, and what came from running and probing the code. Labels: **[Fact]** means verified from files, command output or Git. **[Inference]** means reasoned from facts, not proven. **[Rec]** is a recommendation. **[Unverified]** needs the client or hardware.

### 10.1 Baseline facts at review time

- **[Fact] Repository.** Remote `origin` → `github.com/codingdoctorbot/PulseSensation`, branch `main`, HEAD `ac3d02f`. No `AGENTS.md`, `CLAUDE.md`, `CHANGELOG` or `TODO` exists in the project; the only matches are inside vendored reference folders. Planning history is local-only (section 1).
- **[Fact] Lint.** `luacheck` reports 0 warnings / 0 errors in 53 files for `PulseHaptics/`, `PulseDebug/` and `PulseChecklist/`. `PulseProfileReview/` is outside the runner; linted alone it gives 4 warnings, including the undefined global `PulseProfileReviewDB`.
- **[Fact] Tests.** `./scripts/test.sh` passes 6 of 7 suites: `harness`, `locomotion-test`, `engine-test`, `cue-audit`, `pulsedebug-test` and `checklist-test` pass; `crafting-test` fails 3 assertions (section 10.2). The results are the same under Lua 5.5.1 and LuaJIT (Lua 5.1 semantics, as in WoW).
- **[Fact] Harness figures.** 1,413 rows, 1,010 controls, 190 cue-index entries.
- **[Fact] Cue classification.** 190 cues = 175 discrete + 13 continuous + 2 flagged `silent` (`padDisconnected`, `controllerUIMaster`). `cue-audit` skips `silent` cues, which is why its discrete and continuous counts sum to 188. 35 modes.
- **[Fact] Release zips.** `dist/PulseHaptics-v0.2.0-beta.zip` and `dist/PulseSensation-Suite-v0.2.0-beta.zip` are gitignored and were built 2026-09-24 23:09, the same minute as HEAD. They cannot contain the uncommitted changes. **[Unverified]** their contents.
- **[Fact] Probe scripts** for the role-pool reproduction and the profile comparisons were kept in the session scratchpad, not in the repo.

### 10.2 Review of the uncommitted working tree

| File | Change | Findings |
|---|---|---|
| `Core/Engine.lua:367-396` | `MIN_STEP_DURATION` 0.020, `MIN_GAP_DURATION` 0.025, step-spacing guard | **[Inference]** The spacing guard (`:391-396`) is effectively dead: `offset` already grows by at least `MIN_STEP_DURATION` per step (`:412`), so the guard only fires on exact equality and assigns the same value. **[Fact]** `MIN_GAP_DURATION` changes authored rhythm only when `durMult < 1`; the smallest authored gap is 0.025. **[Unverified]** the range of `durMult`. |
| `Core/Engine.lua:56`, `:472-480` | `lastWantedByChannel` onset force-send | **[Fact]** The comment says "Transients and new onsets always force immediate dispatch", but `forceSend = isOnset` only. Cleared correctly in `StopAll` (`:173`) and in the idle stop (`:646`). |
| `Core/CastActivity.lua:31-35`, `:331-359` | `STALE_TIMEOUT` 10 → 30 s; sweep protects entries while the player is casting; hard ceiling 60 s | **[Fact]** The 60 is a bare number repeated three times (`:343`, `:349`, `:355`). **[Fact]** `isPlayerCasting` is one flag for the whole player, not per entry, so any active cast protects every stale entry. **[Fact]** The sweep clears `crafting` and `activeChannel` silently, with no `CRAFT_STOPPED`/`CHANNEL_STOP` emitted; Crafting's own 0.5 s failsafe (`Crafting.lua:310-335`) limits the effect. **[Unverified]** whether `UnitCastingInfo`/`UnitChannelInfo` returns can be secret on 12.x; the new truthiness test (`:334-339`) has no `issecretvalue` guard. |
| `PulseChecklist/tests/crafting-test.lua:368-385` | 4 Hearthstone assertions | **[Fact]** They look up `pending["player:guid-hearth-1"]`, but `keyFor` builds `"g:guid-hearth-1"` (`CastActivity.lua:65-70`). 3 fail; the last ("cleaned up past hard ceiling") passes only because the key never existed, so the 60 s ceiling is untested. |
| `Core/Database.lua:1449-1453` | `RenameProfile` notifies listeners when the active profile is renamed | **[Fact]** `harness.lua` now asserts it and passes. |

### 10.3 Recommended next phase (updated with sections 4 and 9)

All items are **[Rec]**. The order puts correctness and tooling first, because in-game tuning is unreliable until those are fixed.

0. **Full code review (proposed, not started; handoff: `docs/HANDOFF_CODE_REVIEW.md`).** Level xhigh. Scope: `PulseHaptics/` (Core, Modules, UI), `PulseDebug/`, `PulseChecklist/` including tests, `PulseProfileReview/`, `scripts/`. Excluded: `PulseHaptics/Libs/`. Issues already listed here are referenced, not rediscovered.
1. **Get a green baseline and settle the uncommitted work** (10.2). Fix the test key (`"g:guid-hearth-1"`), make the ceiling assertion non-vacuous (keep `UnitCastingInfo` returning a cast past 60 s and assert removal), name the 60 s constant, align the onset comment with the code, and decide on `MIN_GAP_DURATION`. Commit as separate, reviewable commits, or drop.
2. **Fix the role-pool aliasing** (`Engine.lua:200-212`, `:405-410`): copy step roles into per-step storage owned by the closure, or read from a table the pool never recycles. Then turn the scratchpad probe into an `engine-test` case. *Why:* a committed correctness bug that distorts every judgment of how multi-step cues feel.
3. **Harden `scripts/test.sh`** so a crashing suite or a luacheck warning prints its output (`:82`, `:122`), e.g. `TEST_OUT=$(…) || TEST_STATUS=$?` instead of reading `$?` after an assignment that `set -e` aborts on.
4. **Decide the mixer policy** (section 6 #1). At minimum, add a switch back to the old MAX mix before any in-game tuning, as #21 asked.
5. **Repair the tools the in-game pass depends on:**
   - PulseDebug "Hold 2s" (`UI.lua:733-737`); remove `CancelAll`/`HoldLayer` from the test fake (`pulsedebug-test.lua:321`, `:343`) so the test matches the real API.
   - Checklist baseline: remap the 13 renamed IDs, decide the 17 merged or removed ones, and add a "baseline ID exists in the Registry" assertion.
6. **Reconcile the public docs:** 190 cues, 35 modes, 16 categories / 21 pages; document `/pulse stop` and that it is momentary; README taint and GC claims; TOC "Non-commercial" versus MIT; tests README; `QA_TEST_PLAN.md`; the `Settings.lua:34` comment.
7. **Close the small planned items:** `_G.issecretvalue` (decision first), metadata for Raiding and Questing, the `GetSpellInfo` fallback, the downward version stamp (`Database.lua:899`), the breath "dub" timer token (`Environment.lua:153-155`), and the `keyFor` secret boundary (`CastActivity.lua:65-70`).
8. **Take the pending decisions** (section 6): Controller UI defaults (14 of 20 ON); the SmartNavigation edge cue, which its own code calls forbidden (recommend keeping it off and hidden until a taint test); the profile review and its migration; the future of PulseProfileReview (if kept, fix the frame leak and the reads that write, and add it to lint).
9. **Run the in-game verification pass** (section 7) and record the results in a tracked file. *Depends on* 1–5.
10. **Engine architecture phases** (priority, concurrency, Output/Mixer extraction, MicroFlutter retirement): only after 9, starting with #32's behaviour-preserving extraction.

### 10.4 Code-review checklist (acceptance criteria for the next phase)

| Area | Acceptance criteria |
|---|---|
| Baseline | `./scripts/test.sh` exits 0: luacheck clean and all suites pass, under both `lua` and `luajit`. No assertion passes against a key or table that never existed. |
| Test runner | A deliberately crashing suite prints its error and counts as FAIL. |
| `PlayMode` steps | New `engine-test` case: a strong cue followed by 20+ weak cues within its duration; the strong cue's delayed steps keep their own magnitude and role. Allocation discipline is kept only where it does not break correctness. |
| Engine output | Comments match behaviour (`Engine.lua:475-480`). Raw-hold `SetVibration` calls (`:518`, `:529`) are wrapped like the rest, or documented as deliberately bare. `StopAll` clears all per-channel state. |
| Mixer | A switch back to the old mix exists; the harness asserts both the MAX and saturating-sum paths. |
| Mode timing | A table test shows each authored mode's schedule is unchanged at `durMult = 1`; changes at other values are intended and documented. |
| CastActivity | No magic numbers. Sweep behaviour covered for: an active player cast, an orphaned cast, an orphaned channel, an orphaned craft. Consumers get a defined outcome, or a documented reason why not. `issecretvalue` guards wherever a returned value is tested for truth. `580e69f`'s fallback matching is covered by tests for "unrelated cast while crafting". |
| Profiles | Every built-in profile has metadata. A load-time test fails on unknown override IDs. A migration exists if defaults change. |
| Rename / notify | Renaming the active profile notifies listeners once; renaming an inactive one does not notify. |
| Companion tools | PulseDebug buttons call methods that exist in the real addon, and the test fake matches the real API. The checklist baseline holds only IDs that exist in the Registry. |
| Docs | README, CURSEFORGE, the tests README and the `Registry.lua` header match `cue-audit` output. `QA_TEST_PLAN.md` commands and paths match the addon. |
| Beta checklist | Items 1.1–1.6 of `Beta_Review_Assessment.md` are each ticked with a commit, or explicitly deferred. |
| PulseProfileReview (if kept) | Linted; reuses row frames; reading never writes SavedVariables; exports count 190 cues, `bankOpened` included. |
| In-game | Section 7 executed and recorded in a tracked file; taint log clean; the drowning assumptions confirmed; the trigger-channel result recorded. |

---

## 11. Full code review (2026-09-28, xhigh)

**File:** [`docs/CODE_REVIEW.md`](CODE_REVIEW.md). The user asked for that file in Newspeak; code, paths and probe output in it are exact. This section is in plain English, like the rest of this document.

**Basis.** HEAD `ac3d02f` plus the uncommitted working tree, both matching the handoff. All 68 in-scope files (26,573 lines) were read in full; `PulseHaptics/Libs/` was excluded. Every event name and `C_*` call in the addon was checked against the Forever API documentation in `docs/DevelopmentplusReference/Developer Documents/WOW SOURCECODE/wow-ui-source-forever/`. Five offline probes ran against the real addon files under LuaJIT. The baseline matched the handoff: luacheck is clean and 6 of 7 suites pass; `crafting-test` has the 3 known failures.

**Counts.** P0 0, P1 6, P2 14, P3 11: 31 findings. 20 are wholly new (CR-029, added 2026-09-29: a motor's Strength at 0 still vibrates at the breakaway floor; CR-030 and CR-031 from the third pass, below), 9 extend a finding from an earlier document, and 2 were already known: the role-table pool (re-confirmed and wider than recorded) and the malformed-SavedVariables crash from the RC review (now checked). These figures were corrected in the addendum after sections 1–3 of this document were read.

**Root causes of the in-game QA reports:**
- **Channeling and fishing:** `CastActivity` treats the `UNIT_SPELLCAST_SUCCEEDED` event at the start of a channel as the channel completing or as an instant cast (CR-001). Combat's casting texture is also stopped by events belonging to other casts (CR-002). The fishing texture is about 0.05, too faint to feel (CR-003).
- **Intensity sliders:** every slider saves and reads correctly. What the value does is inconsistent:
  - the top of the slider does nothing on strong modes, and on the Generic preset the bottom is too weak to feel;
  - device presets compress the usable range, and the felt strength depends on what else is playing;
  - overall intensity is stored per profile;
  - multi-step cues sometimes collapse because of the known pool bug (CR-008, CR-013).
  
  Previews ignore the slider (CR-006, CR-014, CR-018). The DualSense and Steam Controller 2 presets are unmeasured, and under Steam Input the Steam Controller 2 is probably detected as the wrong device (CR-019).
- **Footsteps:** the actual footfall rate is twice the labelled steps per second, and mounted gaits produce four bumps per stride. Each step is smoothed as a continuous texture rather than played as a sharp impulse, and it lands on the slow motor on LRA controllers (CR-005, CR-012).
- **Continuous-texture replay:** the ▶ button plays a flat 0.45 hold on both motors for 3.5 s, whichever texture it is (CR-004).
- **Broken features:**
  - `bossAbilityWarning` calls API that does not exist on Forever (CR-007).
  - `weatherTexture` cannot be felt and has no tunables (CR-026).
  - The PulseChecklist import assigns the wrong statuses (CR-015).
  - Controller UI cues also fire when using mouse and keyboard (CR-009).
  - PulseDebug's log is flooded by continuous textures (CR-016).

**Proposed status changes for section 4:**
- §4.4 "Gait cadence units": OPEN / UNVERIFIED → **OPEN (bug confirmed, CR-005)**.
- §4.3 "Malformed SavedVariables crash Init": NOT CHECKED → **OPEN (CR-022)**.
- §4.5 "`hookRadial` guard; tab-mixin hook timing": NOT CHECKED → **CHECKED, no new defect**.
- §4.6 "PulseChecklist and PulseDebug never code-reviewed": OPEN → **REVIEWED** (CR-015, CR-016, CR-017, CR-024).
- §4.1 "Pooled role tables": still OPEN, **impact widened** (CR-013).
- §4.2 and §4.4: add rows for the new findings (see CODE_REVIEW §6).

**Addendum (CODE_REVIEW §10, seven further reviews).** None of them produced a new finding. They did establish the following:
- A secret-value stress probe confirmed the emote-handler error (CR-011) by running it.
- The release zips in `dist/` are byte-identical to HEAD.
- Every continuous texture allocates nothing per frame. PulseDebug's hooks allocate about 135 KB/s while a texture is running.
- The channel-hum regression dates to commit `b39e6a6`, which moved `castTexture` onto CastActivity.
- The reference addon `GamepadVibration` has the same channel bug.
- The 20/53 mismatch between the profile review and the defaults was re-confirmed. Several cues the review accepts are currently defective.
- `QA_TEST_PLAN.md` covers none of the reported in-game problems.

The addendum adds three proposed status changes:
- §4.1 "Separate transient/continuous attack": FIXED → **PARTIAL** (only `PlayMode` got the transient lane).
- §4.8 "Zero-GC": → **PARTIAL** (textures verified allocation-free).
- §10.1 release-zip contents: → **verified equal to HEAD**.

It also adds a new in-game check, V11: how long one `SetVibration` call lasts.

**Next phase.** CODE_REVIEW §9 replaces the order of §10.3 items 1–9 with seven phases:
0. Green baseline and instrumentation, including an in-game capture of the channel event order.
1. Channels and fishing.
2. Engine correctness and intensity coherence, including measuring the DualSense and Steam Controller 2.
3. Crisp footsteps.
4. Faithful continuous-texture previews.
5. Dead features and secret-value safety.
6. P3 fixes and documentation.
7. The in-game verification pass.

§10.3 item 10 (engine architecture) stays last. New in-game checks V1–V10 (CODE_REVIEW §8) extend section 7.

**Third pass (CODE_REVIEW §12.2 and §13, 2026-09-29).** All read-only, including files outside the repository in the game folder.
- **Live settings.** The game loads `PulseHaptics`, `PulseDebug` and `PulseChecklist` through symlinks to this repository, which have existed since 2026-09-23 12:40.
  - The saved settings, as last written on 2026-09-28 22:41, have the **Xbox** preset applied rather than DualSense or Steam Controller 2. That preset's floors are three to four times higher and its Low-motor response is six times slower.
  - Both Immersion profiles in use save footsteps at intensity 0.15. With the DualSense preset, that leaves footfalls moving between 0.030 and 0.040.
  - The saved database is healthy: current version, no unknown or missing cues.
  - Which preset was live during each test is still to be confirmed (new check V12).
- **CR-030 (P3).** Footsteps are split across the rumble pair whenever the preset declares trigger motors, even on the default Standard schema, which has no trigger routing. With an Xbox preset, left feet land on Low and right feet on High. This is the "limp" the code's own comment warns about.
- **CR-031 (P3).** The "Ping placed" cue can never fire on Forever. Its only real event, `UNIT_PING_PIN_ADDED`, is documented with `HasRestrictions` in the secure ping-manager API. `taint.log` (2026-09-23) shows its registration being blocked. That explains the old "blocked action when switching haptics on from the minimap" report. The cue is off in every profile, so it has no effect today.
- **Logs and crashes.** None of the six crash or error dumps involves Pulse: three were written before any addon had loaded, and one is the launcher. One dump shows Steam started WoW on 2026-09-27, and another shows a start-up freeze inside macOS's virtual game-controller driver.
- **Old notes.** All of `docs/dev-notes/` and two Cooking files were read in full. There is no new defect. Every claim checked is either fixed or already tracked here. The stale-crafting-flag theory for the channel silence does not fit the symptom.
- **QA addons.** Both sit one folder too deep to load and contain no vibration measurements, so V11 (how long a single vibration call lasts) remains open.
- **`Ongoing Bugs/` folder (CODE_REVIEW §14).** Twelve bug reports from 2026-09-24 to 09-26, containing 22 distinct claims. Checked against the current code:
  - 7 are fixed (one of them in the uncommitted work), and 1 more is mostly fixed there;
  - 2 are partly fixed;
  - 4 are open and already tracked, including the role-pool bug (CR-013);
  - 3 are confirmed and now recorded as extensions of existing findings: a stale engine header, the 8BitDo name-match order, and one impact switching a whole motor to the fast attack;
  - 1 is confirmed as a deliberate design choice;
  - 2 are not bugs;
  - 1 repeats known documentation and unverified items, and 1 is a set of ideas.
  
  The ENG-01 fix draft is correct and should be taken with a regression test. It adds no new finding.
- **Channel test available now.** With `/pulse debug` on, a "Your cast succeeded fired" or "Instant ability used fired" line at the moment the hum stops would confirm the leading theory (CODE_REVIEW §11.7).

## 12. Locomotion motor trace (2026-09-29)

**Page:** https://claude.ai/artifact/3KKjjCNjcPapxp1cbBb7WE. It is private until shared from the page's Share menu. It charts what the Low and High motors are sent over 10 seconds of movement, with controls for race, mount or form, speed, riding skill, boots, controller preset, schema, every locomotion setting, master intensity and frame rate. Version 3 adds the user's two running profiles as examples and three "What if" switches (no smoothing, impact attack, no floor). The switches are experiments, not addon behaviour.

**Report:** [`docs/LOCOMOTION_REPORT.md`](LOCOMOTION_REPORT.md), with a shareable copy as a [Claude Doc](https://claude.ai/code/artifact/4ecacca3-cf9f-4e68-b0a9-36733377c980) (private until shared). It covers this section, 12.1 and 12.2 in report form.

**Files:** `PulseChecklist/tests/locomotion-sim/`. See its `README.md` for how to run, rebuild and republish. The folder is excluded from the release zip (`scripts/package.sh:37`).

**Method ([Fact]).** `locosim.lua` loads the real `Core/Init`, `Devices`, `Schemas/*`, `Registry`, `Engine` and `Modules/Locomotion` under stubbed WoW APIs and records every `C_GamePad.SetVibration` value. The page runs `sim.js`, a line-by-line JavaScript port of the same path. `compare.py` ran both over 26 configurations: every race path, all three gait modes, on-foot, mounted and form gaits, 9 presets, all 6 schemas, 30–240 fps, the user's saved settings and the what-if overrides. Every frame matched to 6 decimals. The page was not viewed in a browser before publishing, because none was available in the session.

**Assumptions:** fixed frame time; speed reads 0 on the first frame of movement; the Locomotion frame updates before the Engine frame; flat ground with no jumps or combat. They are listed in the README.

**Findings.** Values are from the real-Lua runs, with Overall 0.7 and stock settings unless stated.

| # | Finding | Evidence | Relation to CODE_REVIEW |
|---|---|---|---|
| 1 | [Fact] On the Generic preset the High motor never moves: both feet go to Low. Human on a 60% mount: Low peak 0.327, High 0 | `Locomotion.lua:373-381, :535`; `Devices.lua:219-222` | Already CR-005 |
| 2 | [Fact] With stock settings nothing plays on foot (`mountedOnly` defaults on) | `Registry.lua:2636`; `Locomotion.lua:507-509` | Already CR-005 |
| 3 | [Fact] Xbox preset + Standard schema splits the feet onto Low and High. Running in plate, 2–9 s: left 0.222 on Low, right 0.270 on High, so the right foot is about 22% stronger. With "Rumble + Triggers" both trigger motors peak at 0.367 | `Locomotion.lua:365-381`; `Engine.lua:127-141`; `Schemas/Standard.lua:27-30` | Already CR-030 (19% there, with a different boot weight) |
| 4 | [Fact] Footfall rate is 2× the "steps/s" label: at 2.8 there are 23 left and 22 right peaks between 1 and 9 s | `Locomotion.lua:249-251, :511-513, :532`; `Registry.lua:2660` | Already CR-005 |
| 5 | [Fact] **New.** With Apprentice riding detected, a Human on a 60% mount already hits the 8.0 cadence ceiling (2.8 × 1.8 × 1.6 = 8.06). A 100% mount with Journeyman gives an identical trace, so mount speed and riding skill make no difference. Low stays between 0.095 and 0.185. If the riding spell IDs, marked unconfirmed at `Locomotion.lua:139-146`, are not detected, the tier is 0 and cadence is 7.26 | `Locomotion.lua:146-147, :321-322, :339-343` | Cap noted in CR-005 and §4.4; the consequence is new |
| 6 | [Fact] **New.** The mechanostrider (Gnome) barely registers: the target peaks at 0.29, but Low reaches only 0.056 (mean 0.021). Its sawtooth `(2·norm)^5` is a narrow spike that the 75 ms continuous attack never catches | `Locomotion.lua:239-245`; `Devices.lua:74-81` | New; a specific case of CR-005's smoothing loss |
| 7 | [Fact] **New.** After `PLAYER_STOPPED_MOVING` the last footfall value is held for 0.2 s (the Hold duration), then released. Stock mounted setup: Low stays on until 0.28 s after the stop | `Locomotion.lua:522, :535, :569-573`; `Engine.lua:225-244` | New |
| 8 | [Inference] The mounted gait feels like a rippling hum rather than hoofbeats. Not felt on hardware | Findings 5 and 1 | Agrees with CR-005 |
| 9 | [Recommendation] Split only when the active schema routes `ltrigger`/`rtrigger` to trigger channels | Finding 3 | Same as CR-030's fix direction |

### 12.1 Why running feels muddy on the user's settings (2026-09-29)

**Question from the user:** does the smoothing explain why the running locomotion cue feels muddy?

**Settings ([Fact]).** Read-only from `WTF/Account/<account>/SavedVariables/PulseHaptics.lua`, written 2026-09-29 08:38 and unchanged from the CODE_REVIEW §12.2/§13.1 snapshot:
- calibration: Xbox tuning applied (Low floor 0.12, attack 0.090, release 0.060; High floor 0.10, attack 0.050, release 0.035); `standard` schema;
- locomotion profile: Skyborne, riding tier 0, barefoot;
- characters: one each on `Default` (locomotion off), "Immersion: Caster" (Overall 1.0; locomotion intensity 0.15, gaitIntensity 1.0, mountedOnly 0) and "Immersion: Ranged actual" (Overall 0.65; intensity 0.15, gaitIntensity 0.2, mountIntensity 0.45, mountedOnly 0).

Running at 7.0 gives cadence 2.66, so each foot's half-stride lasts 188 ms. The feet split: left to Low, right to High (CR-030).

**Method.** `analyse.py` measures every footfall between 2 and 9 s. It was run as saved, then with one part of the motor path switched off at a time. All runs go through `sim.js`, which `compare.py` shows is identical to the real Lua, including these overrides.

**Answer: partly, but the floor matters more than the smoothing.**

| # | Finding | Evidence | Relation to CODE_REVIEW |
|---|---|---|---|
| 10 | [Fact] **New.** The floor turns each footfall into a block lasting the whole half-stride. `sin⁴` is above zero across the half-cycle, and the engine lifts every value above zero to the floor, so the target jumps to 0.12 or 0.10 at the zero crossing and holds for 188 ms. With split feet the two blocks meet end to end. On Caster, both motors are under 0.02 for **0%** of running time, and the stronger one never drops below 0.042. With no floor it is 50%; with no smoothing (floor kept) it is still 0%. Sharpness cannot shorten the block: any power of `sin` stays above zero across the half-cycle | `Locomotion.lua:249-251`; `Engine.lua:435-437`; `Devices.lua:186-187` | New. Extends CR-008 b (floor lift) to the split case |
| 11 | [Fact] **New.** At cue intensity 0.15 most of each footfall is the floor. Caster target peak 0.186, of which 0.120 is floor; Ranged actual 0.129, so the step adds 0.009 | `Engine.lua:435-437` | New |
| 12 | [Fact] Smoothing removes most of what is left. Caster: Low keeps 10% of the step's rise above its floor, High 52%. Ranged actual: neither motor reaches its own floor during a footfall (Low 0.108 against 0.120, High 0.099 against 0.100). Low's 90 ms attack needs about 200 ms to reach 90%, longer than the 188 ms footfall | `Engine.lua:97-107, :449-453`; `Devices.lua:186-187` | Extends CR-005 with the user's numbers |
| 13 | [Fact] **New.** The slower Low attack bends the rhythm. Peak lag after the step: Caster Low 41 ms, High 24 ms; Ranged actual 86 and 35 ms. Felt peaks come 170/206 ms apart (Caster) and 137/239 ms apart (Ranged actual) instead of 188/188. This is a limp in timing on top of CR-030's limp in strength | `Devices.lua:186-187` | New |
| 14 | [Fact] **New.** Switching footfalls to the impact attack (CR-012's fix) is not enough by itself. It restores most of the step (Caster Low 81%, High 95%) and most of the timing (180/196 ms), but quiet time stays at 0%, because the floor block remains | `analyse.py` what-if | Qualifies CR-012's fix direction |
| 15 | [Inference] On Ranged actual the Low motor may barely spin during footfalls: the floor is meant to be the breakaway level, and Low never reaches it. The floors are unmeasured starting points (`Devices.lua:160-162`), and the motor's own spin-up adds to the software smoothing. Not measured on hardware | Finding 12 | New |
| 16 | [Recommendation] Make footfalls short discrete taps (30–60 ms) at step times, as CR-005 proposes, rather than only switching the attack. Combined with a dead-zone curve instead of the linear floor lift (CR-008 b), small values are no longer raised to breakaway strength for a whole half-stride | Findings 10, 14 | Supports CR-005 fix 1 and CR-008 b |

**Correction to CODE_REVIEW §13.1 ([Fact]).** §13.1 says that with the Xbox preset "each motor drops to 0 between its own steps. That is more on/off than the DualSense preset". Each motor on its own does drop to near 0 (measured on Caster: Low 0.006, High 0.000). The hands still never feel a gap, because the other motor is at its floor block during that time (finding 10). The split gives a continuous vibration that switches between motors each step, rather than separate steps.

**Coverage.** Measured: running on foot at 7.0 for the two Immersion profiles. Not measured: walking, mounted, the `Default` profile (its locomotion cue is off), and any hardware feel. Only the Xbox tuning was analysed, because it is the saved one.

### 12.2 Summary: what is problematic (2026-09-29)

The user asked, in plain terms, what is wrong with the locomotion cue. This is the answer given in chat, with one correction made while writing it up.

**In one sentence:** a footfall is never a tap. It is a block of vibration half a stride long, and the two motors hand it back and forth, so while running the vibration never stops.

**Causes of the muddy running cue, biggest first** (user's settings: Xbox tuning, Standard schema, Skyborne running at 7.0):
1. **The floor stretches every footfall to the whole half-stride** (finding 10, new). With the feet split, the blocks meet end to end, and running has no quiet moment.
2. **At cue intensity 0.15 each footfall is almost all floor** (finding 11, new). On Ranged actual the step adds 0.009 above the floor. The setting contributes, but the linear floor lift also makes the low end of the slider mostly meaningless (CR-008).
3. **Continuous smoothing blurs the rest** (finding 12; CR-005 and CR-012 known, numbers new). Low keeps 10% of the step's rise above its floor on Caster; on Ranged actual neither motor reaches its floor.
4. **The feet are uneven.**
   - [Fact] Timing (finding 13, new): the felt steps are 137 then 239 ms apart on Ranged actual, and 170 then 206 on Caster, instead of an even 188.
   - [Fact] Strength (CR-030): about 19–22% with stock settings. **Correction:** in chat this was stated as about 20% on the user's settings. On their profiles the gap is small and points in opposite directions: on Caster the right foot (High) is about 7% stronger (0.136 against 0.127); on Ranged actual the left foot (Low) is about 9% stronger (0.108 against 0.099). On these settings the timing gap is the larger problem.
5. **The steps come twice as fast as labelled** (CR-005, known): about 5.3 a second at cadence 2.8, against about 2.7 for a real run.
   - [Fact] Block length is always half a cycle, `1 / (2 × cadence)`.
   - [Inference] So fixing only the rate would make each block longer (about 376 ms) rather than crisper. The rate fix has to come with the tap fix below.

**Other locomotion problems, not about muddiness:**
- Mounted cadence hits the 8.0 ceiling, which gives a hum rather than hoofbeats, and makes mount speed and riding skill irrelevant (finding 5).
- The mechanostrider barely registers (finding 6).
- On the Generic preset High never moves (finding 1).
- On stock settings nothing plays on foot (finding 2).
- The last footfall holds for 0.2 s after stopping (finding 7).

**What does not fix it alone:** switching footfalls to the impact attack (finding 14). It restores strength and most of the timing, but the gaps stay closed.

**What does:** short 30–60 ms taps at real step times (CR-005 fix 1), a dead-zone curve instead of the linear floor lift (CR-008 b), and splitting only when the schema routes trigger roles to trigger motors (CR-030).

**Status:** simulated only; nothing has been felt on hardware. The page's "What if" switches reproduce each effect.

## 13. Engine smoothing on continuous cues (2026-09-29)

**Question from the user:** is the smoothing doing its job for continuous cues, or does it need looking over?

**Answer.** The filter works as built and suits slow textures. It is the wrong tool for the fast and rhythmic signals that also use the continuous path. That part needs looking over, by routing rather than by retuning.

**Method ([Fact]).** `PulseChecklist/tests/locomotion-sim/smoothing-probe.lua` loads the real `Core/Devices.lua`, `Core/Schemas/Standard.lua` and `Core/Engine.lua` and drives one `Engine:Hold` layer with test signals. It records every `SetVibration` value. Master intensity is 1.0 and cue scaling is bypassed, so the numbers describe the engine alone. The signal rates come from the modules:
- `waterTexture` 0.15 Hz (`Movement.lua:191`); `oceanTexture` 1/9 s (`:245`); `swimTexture` 0.45–0.95 Hz plus a 2× asymmetry harmonic (`:308-322`);
- `taxiRide` 0.57 Hz (`:397-398`); `stealthTexture` 0.3 Hz (`PlayerState.lua:72`);
- weather: snow 0.1 Hz, sandstorm 0.25 Hz, wind 0.2 Hz, rain 8 Hz (`Environment.lua:244, :250, :256, :262`);
- MicroFlutter 7 Hz ±0.01 (`Core/Waves.lua:156-157`);
- 50 ms knocks for `breathTexture` and the two low-health cues (`Environment.lua:152-154`, `Health.lua:43-44`);
- `castTexture`, `craftTexture`'s bed and `glideThrust` follow slow game state.

**Share of the swing that reaches the motor, and the lag, for a sine of 0.10–0.50 at 60 fps:**

| Preset / channel | 0.25 Hz | 0.5 Hz | 1 Hz | 2 Hz | 3 Hz | 5 Hz | 8 Hz | Lag |
|---|---|---|---|---|---|---|---|---|
| Generic / Low | 100% | 98% | 94% | 83% | 72% | 54% | 38% | 16–46 ms |
| Xbox / Low | 99% | 97% | 90% | 73% | 58% | 39% | 27% | 18–70 ms |
| Xbox / High | 99% | 99% | 96% | 88% | 78% | 60% | 44% | 15–37 ms |
| DualSense / Low | 100% | 100% | 100% | 99% | 96% | 91% | 84% | 5–8 ms |

**Findings:**

| # | Finding | Evidence | Relation to earlier docs |
|---|---|---|---|
| 17 | [Fact] The filter is frame-rate independent: the kept share at 144 fps is within 1 point of 60 fps at every rate | Probe at 60 and 144 fps; `Engine.lua:97-107` | Confirms CODE_REVIEW §10 (the smoothing row of the Tremor comparison) |
| 18 | [Fact] Slow textures pass almost untouched: at 1 Hz and below every preset keeps 90–100% of the swing, lagging 70 ms or less. Onset is a 0.1–0.2 s fade-in (90% after 183 ms Generic, 217 ms Xbox Low, 50 ms DualSense). For water, ocean, swim, taxi, stealth, snow, sandstorm, wind, cast, craft bed and glide, the smoothing does its job | Probe sections 1 and 4 | New measurement |
| 19 | [Fact] Fast and rhythmic signals lose most of their shape on the Generic and ERM presets. From 2 Hz up, Xbox Low keeps 27–73% of the swing. A 50 ms knock of 0.70 reaches 0.341 on Generic, 0.314 on Xbox Low and 0.461 on Xbox High. That covers footfalls, the heartbeat and breath knocks, and rain patter at 8 Hz | Probe sections 1 and 5 | Extends CR-005, CR-012 and CR-026 with preset numbers; the Generic knock matches CR-012's 0.34 |
| 20 | [Fact] **New.** Attack is slower than release on every preset (Generic 75/28 ms, Xbox Low 90/60, Xbox High 50/35, DualSense 15/12). This pulls the average of a modulated texture down: Generic −10.5% at 2 Hz and −18.7% at 8 Hz; Xbox −4% to −6%. So a rhythmic texture feels weaker as its rate rises, whatever the slider says | Probe section 2; `Devices.lua:74-81, :186-188` | New; adds to CR-008's slider incoherence |
| 21 | [Fact] **New.** On ERM presets the attack ramps up from 0 through the floor. The motor only reaches its breakaway floor 50–133 ms after a texture starts on Xbox Low (the lower the level, the longer), and 17–67 ms on Xbox High. [Inference] If the floor is the real breakaway, that part of the fade-in is silent. Minor for long textures; for per-step onsets it adds to CR-005 | Probe section 4; `Engine.lua:435-437` before `:449-453` | New |
| 22 | [Fact] MicroFlutter's ±0.01 nudge reaches the motor as a swing of 0.0049 on Xbox Low, 0.0082 on Generic and 0.0196 on DualSense. It is still above the 0.0015 change threshold, but too small to feel | Probe section 3 | Adds numbers to §4 "Remove MicroFlutter" (OPEN until the hardware check) |
| 23 | [Recommendation] Look over the routing, not the time constants. Rhythmic cues need the fast lane per layer: CR-012's `isTransient` on `Hold`, without switching the whole motor (CR-012 §14). Footfalls become taps (CR-005) and rain becomes transient patter (CR-026). Separately, decide whether a slower attack than release is wanted for textures (finding 20). Review #29's advice not to lower `attackTau` globally still stands: finding 18 shows slow textures need no change | Findings 18–20 | Supports CR-005, CR-012, CR-026 |

**Not covered:** hardware feel, the Steam Deck and 8BitDo presets, trigger channels, and two layers mixed on one channel.

### 13.1 Are slow textures fine? (2026-09-29)

**Answer.** The smoothing is fine for them, but the textures themselves are not all fine. Finding 18 only tested a large test signal (0.10–0.50) at Overall 1.0. The real textures run at 0.02–0.14 before Overall, and at those levels the floor decides what is felt. Finding 18 is correct about the smoothing, but should not be read as "slow textures are fine".

**Method ([Fact]).** `PulseChecklist/tests/locomotion-sim/slow-textures-probe.lua` loads the real `Devices`, `Standard`, `Waves` and `Engine`. It evaluates each texture's own formula every frame, including MicroFlutter where the module applies it, applies cue intensity as `Init.lua` does, and records what is sent over 18 s. Two setups:
- stock defaults on the Generic preset, Overall 0.7;
- the user's Caster profile on their Xbox tuning, Overall 1.0 (cast intensity 0.55, castPresence 0.07, castSwellPeak 0.9, craft bedGain 0.45; SavedVariables 2026-09-29).

The user's Caster profile has water, ocean, swim, taxi, glide, cast, craft and weather on; stealth is off in every profile.

| Texture (formula) | Designed movement | Stock, Generic: sent | Yours, Xbox: sent |
|---|---|---|---|
| water (`Movement.lua:183-198`) | flat (`waveDepth` 0) | Low 0.023–0.029 | Low 0.152–0.157, ±2% |
| ocean (`:244-282`) | swell ±75% | Low 0.029–0.163, ±69% | Low 0.160–0.325, ±34% |
| swim (`:306-349`) | strokes ±55% | High 0.033–0.091, ±47% | High 0.143–0.218, ±21% |
| taxi (`:397-403`) | wind ±33% | 0.032–0.070, ±38% | Low 0.161–0.207, ±12% |
| stealth (`PlayerState.lua:71-77`) | breath ±35% | Low 0.023–0.058, ±43% | Low 0.151–0.193, ±12% |
| sandstorm (`Environment.lua:256`) | gusts ±50% | Low 0.017–0.063, ±58% | Low 0.144–0.200, ±16% |
| wind (`:262`) | ±30% | Low 0.010–0.028, ±48% | Low 0.135–0.156, ±7% |
| snow (`:250`) | ±20% | High 0.006–0.018, ±47% | High 0.109–0.125, ±7% |
| craft bed (`Crafting.lua:452-457`) | flat | Low 0.056 | Low 0.152 |
| cast (`Combat.lua:466-471`) | presence + swell | Low 0.070, High 0.023–0.474 | Low 0.154, High 0.124–0.535 |
| glide (`Flight.lua:104-112`, half speed) | steady | Low 0.194, High 0.122 | Low 0.364, High 0.258 |

**Findings:**

| # | Finding | Evidence | Relation to earlier docs |
|---|---|---|---|
| 24 | [Fact] **New numbers.** On stock settings with the Generic preset, most slow textures send 0.01–0.07. The ERM presets put the level where a motor starts turning at 0.10–0.14 (`Devices.lua:186-187`). [Inference] On an ERM pad left on Generic, water, stealth, wind, snow, sandstorm, taxi, swim and the craft bed may be barely felt or silent. The floors are unmeasured (`Devices.lua:160-162`) | Table, stock column | Same mechanism as CR-008 item 2 (dead bottom on Generic); extends CR-026 beyond weather |
| 25 | [Fact] **New.** On the user's Xbox tuning the floor lift keeps these textures above the floor, but squeezes out their movement: stealth ±35% → ±12%, taxi ±33% → ±12–16%, swim ±55% → ±21%, sandstorm ±50% → ±16%, wind and snow → ±7%. The lift `floor + (1 − floor) × v` scales the swing by `1 − floor` and raises the level by the floor. The smoothing costs little at these rates (finding 18) | Table, your column; `Engine.lua:435-437` | Same mechanism as CR-008 item 3 (slider range compression), applied to a texture's own movement |
| 26 | [Inference] Those textures then feel like near-flat hums just above breakaway. The addon's own design note says sustained constant vibration fades from perception within a second or two (`Movement.lua:391-392`). Water (`waveDepth` 0 by default) and the craft bed are flat by design, so they are exposed to the same fading. Not checked on hardware | Findings 25; `Registry.lua` water tunables | New |
| 27 | [Fact] **New.** On Generic, MicroFlutter's ±0.01 nudge is as large as the tiniest textures: snow's designed ±20% measures ±47%, wind's ±30% measures ±48%, and flat water measures ±11%. What little moves is mostly the 7 Hz nudge | Table, stock column; `Waves.lua:156-157` | Adds to §4 "Remove MicroFlutter" |
| 28 | [Fact] Healthy at these levels: ocean (the Low swell keeps ±34% on Xbox and ±69% on Generic), the cast swell on High (0.12–0.54 on Xbox) and glide (clear, steady levels) | Table | — |
| 29 | [Recommendation] Treat slow-texture strength and depth as calibration work, not smoothing work. A dead-zone curve instead of the linear floor lift (CR-008 b) would keep more of the movement above breakaway. Baselines of 0.02–0.06 need checking against a measured breakaway (CR-026's "raise defaults to perceptible after hardware Ramp"). Water's default `waveDepth` of 0 contradicts the design note at `Movement.lua:391-392` | Findings 24–27 | Supports CR-008 b and CR-026 |

**Not covered:** swim at part speed, submerged water (baseline ×1.5), rain (covered in finding 19), and hardware feel.

## 14. Why the DualShock 4 feels best (2026-09-29)

**Question from the user:** why does the DualShock 4 feel the best and most satisfying?

**Short answer.** The addon is built around a heavy and a light rumble motor, and the DualShock 4 is that hardware. The tuning in force is also the one made for it. It receives the strongest, steadiest signal of the four controllers compared, and its big motor turns that into a deep, full rumble. [Inference] What feels satisfying is weight and continuity. The designed rhythms and swings are mostly flattened on it. Feel cannot be measured here, and which preset was applied during each test is not recorded.

**Method ([Fact]).** The user's two running profiles (`locosim.lua`) and the Caster profile's slow textures (`slow-textures-probe.lua compare`) were run on the `ds4`, `xbox`, `dualsense` and `steamcontroller2` presets, through the real Lua.

| Signal (your Caster profile) | DS4 preset | Xbox preset | DualSense preset | SC2 preset |
|---|---|---|---|---|
| Running footfalls | Low 0.130–0.155, High 0 | Low 0.006–0.129, High 0–0.137 (split) | Low 0.031–0.108 | Low 0.036–0.106 |
| Running, Ranged actual | Low 0.121–0.125 | Low 0–0.110, High 0–0.100 | Low 0.030–0.040 | Low 0.035–0.044 |
| Stealth breath (±35% designed) | 0.151–0.193, ±12% | same as DS4 | 0.064–0.130, ±34% | 0.068–0.129, ±31% |
| Taxi wind (±33%) | 0.161–0.207, ±12% | same as DS4 | 0.077–0.151, ±33% | 0.080–0.149, ±30% |
| Swim strokes (±55%) | 0.143–0.218, ±21% | same as DS4 | 0.076–0.166, ±37% | 0.081–0.171, ±35% |
| 50 ms knock of 0.70 (§13, Overall 1.0) | Low 0.314, High 0.461 | same as DS4 | Low 0.782 | not run |

**Findings:**

| # | Finding | Evidence |
|---|---|---|
| 30 | [Fact] The addon's roles are the heavy/light rumble-motor pair: Low is the large, slow mass and High the small, fast one. The DS4 and Xbox presets carry the same ERM values for those two motors | `Devices.lua:164-168, :186-187, :227-233, :246-253` |
| 31 | [Fact] On its own preset the DS4 gets about twice the level of the voice-coil pads, with most movement flattened (±12–21% against ±30–37%). Footfalls become a steady rumble with a small pulse (0.130–0.155), because the split is vetoed (`triggers = false`) and both feet share the big motor | Table; `Locomotion.lua:373-381` |
| 32 | [Fact] The DualSense and SC2 presets keep the designed movement and sharper knocks (0.78 against 0.31), but at half the level. Ranged actual's footfalls there are 0.030–0.040, a faint buzz | Table |
| 33 | [Fact] The saved calibration is the Xbox preset, and detection never applies a preset by itself (CODE_REVIEW §12.2). [Unverified] If the DualSense and SC2 were tested on it, they received the DS4's numbers exactly: floors 3–4× their preset's and a 6× slower attack | CODE_REVIEW §12.2 |
| 34 | [Unverified, hardware background] An ERM's vibration strength and frequency rise together with drive, and its own spin-up and coast-down round off steps, so a steady 0.15 drive reads as a deep rumble through both grips. On voice-coil pads, rumble commands are rendered as a buzz near the actuator's working frequency. The DS4's two motors differ in character (heavy left, light right); on the DualSense, Low and High are reported to differ only in side (CR-005 fix 3) | General hardware knowledge; not measured |
| 35 | [Inference] If what satisfies on the DS4 is weight and continuity, the fix plan in §12.2 (crisp taps, a dead-zone curve) will change that feel. Keep a steady weight layer as an option (CR-005 fix 1 already proposes "an optional low weight bed") | Findings 31, 34 |

**How to confirm (A/B on hardware):**
- [ ] Note which preset was applied for each controller test.
- [ ] DualSense: compare the DualShock 4 preset with the DualSense preset. If the DS4 preset also feels better there, the tuning explains most of it. If not, the hardware does.
- [ ] DS4: compare its own preset with the DualSense preset, to see how much of its feel comes from the ERM tuning.
- [ ] Say which controller the 2026-09-15 "confirmed in-game" feel checks were made on (heartbeat constants, `Health.lua:34-45`).

### 14.1 Why jump and landing feel so good on the DS4 (2026-09-29)

**Question from the user:** why do bounce, jump and land feel so good on the DS4 compared with the other controllers? There is no "bounce" cue. The jump and landing cues are `jumped` (TAP: Low, 0.6 for 120 ms), `landingSoft` (TICK: Low, 0.2 for 50 ms) and `landingHard` (THUD: High, 0.85 for 160 ms) (`Registry.lua:96-128`, `Modes.lua:22-25, :91-109`). All three are on in both Immersion profiles at cue intensity 1.0. **Correction (same day):** this first said no mode overrides were saved; that check read the wrong key. Overrides live in `triggerSettings[cue].__mode` (`Database.lua:1828-1831`). Both Immersion profiles play `landingSoft` as **TAP**, and Ranged actual plays `jumped` as **TICK**. The table below is by mode, so its numbers stand. On the user's profiles, the soft landing is the TAP row (130 ms tail on the DS4 preset), and Ranged actual's jump is the TICK row.

**Answer.** Every one of these modes is a plain rectangle: one step, one level, no designed decay. The only decay an impact gets comes from the channel's release smoothing and the motor's own coast-down. The DS4 preset has the slowest release (Low 60 ms, High 35 ms), so its impacts ring down like a real hit. On the DualSense and SC2 presets (release 10–15 ms) they stop dead.

**Method ([Fact]).** `PulseChecklist/tests/locomotion-sim/impact-probe.lua` plays each cue through the real `Modes.lua` and `Engine:PlayMode`, the transient path, on each preset. Overall 1.0 (Caster); Overall 0.65 (Ranged actual) was also run.

| Cue (Overall 1.0) | Preset | Peak | Tail after the step | Energy |
|---|---|---|---|---|
| jump (TAP, Low) | DS4 / Xbox | 0.642 | 130 ms | 0.0975 |
| | DualSense | 0.699 | 13 ms | 0.0846 |
| | SC2 | 0.672 | 30 ms | 0.0831 |
| soft landing (TICK, Low) | DS4 / Xbox | 0.218 | 117 ms | 0.0172 |
| | DualSense | 0.252 | 0 ms | 0.0095 |
| | SC2 | 0.246 | 17 ms | 0.0099 |
| hard landing (THUD, High) | DS4 / Xbox | 0.864 | 57 ms | 0.1484 |
| | DualSense | 0.896 | 7 ms | 0.1368 |
| | SC2 | 0.896 | 7 ms | 0.1383 |

Tail = time above 10% of the peak after the step ends. Energy = sum of the sent value over time.

**Findings:**

| # | Finding | Evidence |
|---|---|---|
| 36 | [Fact] Discrete modes are rectangles, so an impact's decay comes only from `releaseTau` (and, on hardware, coast-down) | `Modes.lua:22-25, :91-109`; `Engine.lua:97-107` |
| 37 | [Fact] **New.** On the DS4 preset impacts have a decaying tail of 57–130 ms and carry 8–81% more energy, with nearly the same peak. The soft landing carries about twice the DualSense energy (0.0172 against 0.0095 at Overall 1.0; 0.0135 against 0.0065 at 0.65). On the DualSense and SC2 presets the same cues are blocks with 0–30 ms tails | Table; probe at Overall 0.65 |
| 38 | [Fact] Impacts use the transient attack (Low 25 ms, High 12 ms on the DS4 preset), not the 90 ms texture attack, so they still arrive quickly. The DS4 jump reaches 90% of its peak in 67 ms, the hard landing in 33 ms | Probe; `Engine.lua:449-450`; `Devices.lua:186-187` |
| 39 | [Inference] Fast attack plus exponential decay is the envelope of a real impact. The DS4 preset approximates it, and a big eccentric mass coasting down adds to it [Unverified hardware background]. The slow release that muddies rhythmic textures (§12.1, §13) is exactly what makes single impacts feel weighty | Findings 36–38 |
| 40 | [Recommendation] Give impact modes their own decay instead of borrowing it from the channel's release. For example a decay step or envelope per mode, so they land the same way on every controller. Review #29 proposed "declarative envelopes" (§3) | Findings 36–39 |

**Not covered:** multi-step modes, the Steam Deck and 8BitDo presets, and hardware feel.

### 14.2 Fix or motor physics? (2026-09-29)

**Question from the user:** is there a fix, or is it up to motor physics?

**Answer.** Both, split cleanly. Everything about timing is software: the rise, the fade, the gaps between steps, how long a footfall lasts. Those can be fixed so every controller gets the good shape. The character of the vibration is physics plus the API: a deep, heavy rumble from a big spinning mass against a lighter buzz from a voice coil. Pulse cannot change that, because WoW only lets it send an intensity per channel.

| # | Finding | Evidence |
|---|---|---|
| 41 | [Fact] WoW's gamepad API offers `C_GamePad.SetVibration(vibrationType, intensity)` and `StopVibration()`, and nothing else for vibration: no frequency, waveform or haptics call. So Pulse controls only how strong each channel is, frame by frame | `Blizzard_APIDocumentationGenerated/GamePadDocumentation.lua:243-251, :269` (retail source in `docs/DevelopmentplusReference/`) |
| 42 | [Fact] The DS4's impact tail in §14.1 is software: it comes from the preset's `releaseTau` and appears identically on the Xbox preset. The probe runs no hardware | §14.1 table; `impact-probe.lua` |
| 43 | [Fact] **What-if, not addon behaviour.** Each impact carries its own fade (60 ms on Low, 35 ms on High, emulated by re-arming the layer each frame on the transient lane). DualSense and SC2 impacts then get 90–183 ms tails and at least the DS4's current energy: jump 0.128 against 0.0975, hard landing 0.173 against 0.148 | `impact-probe.lua PulseHaptics 1.0 envelope` |
| 44 | [Fact] **What-if.** On the DS4 the same fade stacks with its slow release: the jump tail grows from 130 to 297 ms. The floor also turns the end of the fade into a flat shelf at 0.12, because every value above zero is lifted to the floor. So a per-mode fade needs the ERM presets' release shortened for impacts, and a dead-zone curve (CR-008 b) so fades reach silence smoothly | Same run; `Engine.lua:435-437` |
| 45 | [Inference / Unverified hardware background] Physics that no software change reaches: an ERM's strength and frequency rise together and it moves a large mass, so it thumps. A voice coil driven through rumble emulation buzzes. The DualSense's wider haptics are reached through audio haptics, which WoW does not expose (finding 41). So the voice-coil pads can get the DS4's timing but not its weight | Findings 41–44 |
| 46 | [Recommendation] Fix order: (1) per-mode envelopes for impacts (attack, hold, decay), with the release not adding a second tail; (2) dead-zone curve in place of the floor lift; (3) the per-layer transient lane and footfall taps from §12.2 and §13; (4) measured calibration (Ramp) per pad instead of preset guesses. Then accept that the DS4 will still thump harder: that is its motor | Findings 41–45 |

## 15. Trigger channels: do they matter, and would removing them change anything? (2026-09-29)

**Answer.** On the user's setup (Xbox preset, Standard schema) the trigger channels themselves are never driven. The trigger roles fall back to Low and High. They matter in one place, running footfalls, and there they currently make things worse. Whether they could ever do something useful depends on an unverified fact: does WoW drive `"LTrigger"`/`"RTrigger"` at all?

**What uses trigger roles ([Fact]):**

| Where | What it does | On the user's setup |
|---|---|---|
| Locomotion split (`Locomotion.lua:373-381, :517-522`) | Left foot to `ltrigger`, right foot to `rtrigger`, whenever the preset declares `triggers = true` | Active (Xbox preset). The feet fall back to Low and High: the uneven split of CR-030 and finding 13 |
| 7 trigger modes (`Modes.lua:230-286`) | Steps on `ltrigger`/`rtrigger` | Only `autoShotFired` uses one by default (TRIGGER_RECOIL). It is on in Ranged actual, and its trigger step falls back to High. None of the 37 saved mode overrides picks a trigger mode |
| Schemas `rumbleAndTriggers`, `triggerEmphasis` | Route roles to the `LTrigger`/`RTrigger` channels | Not selected (the schema is `standard`) |
| Presets `xbox`, `xbox_elite` (`Devices.lua:246-270`) | `triggers = true` plus trigger-channel calibration | `triggers = true` is what turns the split on |
| Engine (`Engine.lua:59, :127-141, :386-387`) | Four-role blend and the fallback | Two extra roles in the loop; negligible cost |

**Does WoW drive trigger motors? ([Fact] / [Unverified])** `SetVibration` takes a bare string and names no accepted values (`GamePadDocumentation.lua:243-251`). Blizzard's own UI never calls `SetVibration`. The only `LTrigger`/`RTrigger` strings in its source are button-art names (`BlizzardInterfaceResources-live/Resources/AtlasInfo.lua:5860` and nearby). The addon's own comment calls the strings unconfirmed (`Schemas/RumbleAndTriggers.lua`). So does the reference comparison (CODE_REVIEW §10: "neither reference drives triggers"). This is still open in the hardware backlog (§7).

**If they were removed ([Fact] unless marked):**
- **Running footfalls stop splitting.** Both feet go to the Low role, which is what the DS4 preset already does with the same ERM values: Low 0.130–0.155 on Caster and 0.121–0.125 on Ranged actual (§14), instead of the Low/High handover. The timing limp (finding 13) and the strength difference (CR-030) disappear. [Inference] Running feels like the DS4's steady rumble, which the user rated best, though still without separate steps (§12).
- **Auto Shot recoil is unchanged** under Standard if its trigger step becomes a High step: same channel, and `triggerMult` and `highMult` both default to 1.0 (`Engine.lua:382-387`). One small difference: a trigger-role step and another cue's High layer combine by max today, but would combine by saturating sum as two High layers (`Engine.lua` blend).
- **Gone with them:** the "Rumble + Triggers" and "Triggers Only" schemas, the trigger rows and Test button on the calibration page, the trigger calibration in the Xbox presets, and findings CR-020 and CR-030. So is a trap: if the strings do nothing, "Triggers Only" is total silence.
- **What would be lost:** [Unverified] if WoW does drive the Xbox trigger motors, they are the one way to get a real left/right gait. The two trigger motors match each other, unlike the heavy Low and light High pair. Trigger "click" modes would also have a real home.

| # | Finding | Evidence |
|---|---|---|
| 47 | [Fact] On Standard, trigger roles never reach a trigger motor. Their only effects on the user's setup are the running-footfall split and Auto Shot's recoil step on High | Table above; SavedVariables 2026-09-29 |
| 48 | [Fact] Nothing in Blizzard's source shows that `"LTrigger"`/`"RTrigger"` are accepted vibration types | `GamePadDocumentation.lua:243-251`; no `SetVibration` call in Blizzard's UI |
| 49 | [Recommendation] Settle it with one hardware test before removing anything. Use an Xbox controller, select "Rumble + Triggers", and press the LTrigger/RTrigger Test on the calibration page. If nothing is felt, remove or hide trigger channels, and keep `ltrigger`/`rtrigger` as aliases of low/high so modes still load. If they work, keep them and fix CR-030, so the split happens only on a schema that routes to real trigger motors. Either way, the user's running footfalls stop splitting onto Low/High | Findings 47–48; §7 backlog |

---

## Appendix A. First planning review, as delivered in chat (2026-09-28)

Kept for the record. The wording is as delivered; headings are renumbered A.0–A.5 and a few nested bullet lists are flattened. **Superseded where it differs from the sections above:**
- 1.5 left the 175 + 13 = 188 question open; section 10.1 resolves it (2 `silent` cues).
- Section 2 of the review was written after only partial reading of the docs (Appendix B); section 4 is the complete tracker.
- Section 3's order is replaced by 10.3, which adds the mixer switch, the tooling repairs and the commit-history findings.
- Section 5's checklist is replaced by 10.4.

> **PulseSensation — Pre-Development Planning Review**
>
> **Reviewed:** 2026-09-28 · HEAD `ac3d02f` (2026-09-24) · branch `main`
> **Labels:** **[Fact]** means verified from files, command output or Git. **[Inference]** means reasoned from facts but not proven. **[Rec]** is my recommendation. **[Unverified]** means it can't be confirmed from the repo, usually because it needs the live client.

### A.0 Method and ground truth

- [Fact] There is no `AGENTS.md`, `CLAUDE.md`, `CHANGELOG` or `TODO` file anywhere in the project itself. The only matches are inside vendored reference folders under `docs/DevelopmentplusReference/`.
- [Fact] Most planning documents are gitignored and exist only on this machine: `docs/PulseHaptics*.md`, `docs/dev-notes/`, `docs/ReviewsofReviews/` (`.gitignore:19-24`). The one tracked planning doc is `docs/dev-notes/QA_TEST_PLAN.md`, which was force-added. Anyone cloning the repo sees no plan at all.
- [Fact] `./scripts/test.sh` (luacheck plus 7 offline suites) gives: luacheck 0 warnings / 0 errors in 53 files, 6 of 7 suites pass, and `crafting-test` fails 3 assertions. LuaJIT (Lua 5.1 semantics, which WoW uses) gives the same result.
- [Fact] Nothing in the repo shows a result from the live WoW client. Every claim about how haptics feel, about taint, or about client behaviour is [Unverified] unless a doc records an in-game observation.

### A.1 Current state

**A.1.1 Working tree (uncommitted)**

| Item | State |
|---|---|
| `PulseHaptics/Core/Engine.lua` | [Fact] Uncommitted work in progress: onset force-send (`:56`, `:472-480`), minimum step/gap durations and step spacing in `PlayMode` (`:367-396`). |
| `PulseHaptics/Core/CastActivity.lua` | [Fact] Uncommitted: `STALE_TIMEOUT` raised from 10 to 30 (`:35`), and a sweep that is aware of an active cast, with a hard-coded 60 s ceiling (`:331-359`). |
| `PulseHaptics/Core/Database.lua` | [Fact] Uncommitted: `RenameProfile` now notifies listeners when the active profile is renamed (`:1449-1453`). The harness assertion for this passes. |
| `PulseChecklist/tests/crafting-test.lua:368-385` | [Fact] 4 new Hearthstone assertions, 3 of which fail. |
| `PulseProfileReview/` | [Fact] Untracked prototype addon (`0.1.0-prototype`). |
| `ProfileReviewReports/Immersion-Ranged-Cue-Review.md` | [Fact] Untracked review output for one profile. |

**A.1.2 Broken**

1. **Pooled role tables get overwritten before delayed `PlayMode` steps fire. This is committed code (`f447944`).**
   - [Fact] `getRoleTable()` hands out one of 16 recycled tables in a ring (`Engine.lua:200-212`). Delayed steps capture that table in a `C_Timer.After` closure (`:379`, `:405-410`) and read it only when the timer fires. Any later `PlayMode` calls that wrap the ring wipe and rewrite it first.
   - [Fact, reproduced] I ran the real `Engine.lua` in the `engine-test` stub setup. I played a full-strength `BURST` cue, then 20 weak cues (scale 0.1). The strong cue's delayed steps went out at **0.045–0.065 instead of 0.45–0.65**. A control run without the extra cues gave the correct 0.45–0.65.
   - [Inference] In busy combat, cues can play at the wrong strength or on the wrong motor. `engine-test` does not catch this.
2. **`crafting-test` fails because of a bug in the test, not the code.**
   - [Fact] The new assertions look up `pending["player:guid-hearth-1"]` (`crafting-test.lua:371-385`). `keyFor` builds keys as `"g:" .. castGUID` (`CastActivity.lua:65-70`), so the lookup can never match.
   - [Fact] The last assertion ("cleaned up past hard ceiling", `:385`) passes only because that key never existed. So the 60 s ceiling is not actually tested.
3. **`scripts/test.sh` loses the diagnostics when a suite crashes.**
   - [Fact] The script uses `set -euo pipefail` (`:2`) together with `TEST_OUT=$(lua …)` (`:122`) and `LINT_OUT=$(luacheck …)` (`:82`). I confirmed that under these settings a failing command substitution exits the script immediately, before the `FAIL` branch prints anything.
   - [Inference] A Lua runtime error, or any luacheck warning, makes the script exit 1 with no output. Assertion failures still report, because the suites exit 0.

**A.1.3 Partially implemented**

- **Engine rewrite.**
  - [Fact] Three parts of the local plan landed in `ea0368a`: a saturating-sum mixer for continuous layers, with transients on top (`Engine.lua:537-588`); separate attack smoothing for transients and continuous layers (`:446-453`); a 250 ms output watchdog (`:58`, `:477-486`).
  - [Fact] No code exists for these plan phases: signal classes, envelopes, concurrency policies (REPLACE/STACK/COALESCE), explicit priority, or channel capability states (`docs/PulseHaptics_Haptics_Engine_Implementation_Plan_and_Prompt.md` §4–§17). I found no matching identifiers in `Core/` or `Modules/`.
  - [Fact] `MicroFlutter` is still used at 10 call sites (for example `Movement.lua:221`, `Environment.lua:245-263`, `Combat.lua:493`) alongside the new engine watchdog. The plan's Phase 10 ("Replace MicroFlutter") is therefore only half done.
  - [Inference] The readiness audit said to extract the mixer first and not to "change default mixer behavior from MAX" at the start (`…Readiness_Audit.md` §3). The mixer was changed without that extraction.
- **CastActivity consolidation.**
  - [Fact] `CastActivity.lua:18-24` records a planned step: fold `AlertGeneric` into CastActivity, keeping the `IGNORED_SPELL_IDS` filter.
  - [Fact] `AlertGeneric.lua:28`, `:51-73` still registers its own spell-cast events.
- **Emergency stop.**
  - [Fact] `/pulse stop|off|mute` only calls `Engine:StopAll()` (`Panel.lua:539-545`).
  - [Fact] The engine's own header says a module re-arming a continuous cue on its next tick is intentionally *not* blocked (`Engine.lua:48-50`).
  - [Inference] A misbehaving continuous texture comes back within one tick. The command stops everything for a moment; it does not mute.
- **PulseProfileReview prototype.**
  - [Fact] It is untracked, and it is not included in lint (`test.sh:82`), the test suites (`:20-28`) or packaging (`package.sh`). luacheck on it alone reports 4 warnings, including the undefined global `PulseProfileReviewDB`.
  - [Fact] Every Yes/No click calls `refresh()`, which creates a new row frame plus 2 buttons for each of the 190 cues and only hides the old ones (`Review.lua:166-225`).
  - [Inference] WoW frames are never garbage-collected, so frames pile up with every click.
  - [Fact] `reviewEntry` writes a saved-variable entry just by being read (`:27-35`, called from `:141`). This is the same pattern that `docs/dev-notes/outstanding.md` #4 fixed in PulseChecklist.

**A.1.4 Implemented and statically verified**

- [Fact] The pre-release and beta review items below are fixed in code, mostly in `990a765`:
  - `Database:Set` stores tables, which fixes minimap persistence (`Database.lua:1572-1583`)
  - all profile-override cue IDs exist in the registry (checked with a Lua probe: no unknown IDs in any of the 11 override tables)
  - `pingPinAdded` listens to `UNIT_PING_PIN_ADDED` (`Registry.lua:1737`)
  - secret-value guards in `AlertUnitWatch.lua:235-245` and `Combat.lua:321`
  - `OnUpdate` wrapped in `pcall` with `StopAll` recovery (`Engine.lua:651-667`)
  - `PLAYER_LEAVING_WORLD` triggers `StopAll` (`Engine.lua:816-820`)
  - the drowning-detection patch (`Environment.lua:24-39`, `:107-110`, `:217-219`)
- [Fact] The harness builds all panel pages: 1,413 rows, 1,010 controls, 190 cue-index entries.

**A.1.5 Documentation drift**

- [Fact] `cue-audit` reports **190 cues** and **35 modes**. The public docs disagree:
  - `README.md:72`, `:86`, `:100`, `:102` and `CURSEFORGE.md:15`, `:77`, `:120` say **202** cues
  - `CURSEFORGE.md:28` says **36** modes
  - `Registry.lua:8` says **21** modes
  - The registry file contains 202 `id =` lines, but 12 of them are sidebar page IDs such as `"CASTING"` (`Registry.lua:2825`). [Inference] That is where 202 came from.
- [Fact] `cue-audit` reports "Discrete: 175, Continuous: 13", which adds up to 188, not 190. [Unverified] what the remaining 2 are. *(Resolved later: section 10.1.)*
- [Fact] `PulseChecklist/tests/README.md:3-4` still says "six suites" and "commit `cddf553`", and `:38` says "1,408 rows, 1,006 controls". `test.sh` runs 7 suites.
- [Fact] `docs/dev-notes/QA_TEST_PLAN.md` is stale: `/pulsedebug` (`:21`; the actual command is `/pdebug`); the icon is described as `Spell_Nature_WispSplode` (`:48`; a custom `icon.tga` replaced it); addon directory `Pulse` (`:124-128`; it is now `PulseHaptics`); "112 tests passing" (`:130`).
- [Fact] `/pulse stop` is missing from the command tables in `README.md:78-91` and `CURSEFORGE.md:113-122`.

### A.2 Planned work recorded in the repository

This section is the repository's own record. My recommendations are in A.3.

| # | Planned item | Source | Status |
|---|---|---|---|
| P1 | Move the `issecretvalue` fallback off `_G` | `docs/dev-notes/Beta_Review_Assessment.md:57-65`, checklist `:105` (local only) | [Fact] Open. `Init.lua:12-16` still writes `_G.issecretvalue`. |
| P2 | Add metadata for built-in profiles `Raiding` and `Questing` | `docs/PulseHaptics_PreRelease_Code_Review.md` P1-06 (local only) | [Fact] Open. 12 profile names (`Database.lua:54-67`), 10 metadata entries (`:69-172`). |
| P3 | Remove the legacy `GetSpellInfo` fallback | same doc, P2-02 | [Fact] Open. `Crafting.lua:266-267`. |
| P4 | Reword claims that trigger actuators are supported; probe hardware capability instead | same doc, P2-01; `outstanding.md` #10 | [Fact] Open. `LTrigger`/`RTrigger` are unconfirmed on the live client. |
| P5 | Decide the SmartNavigation edge-callback taint question with a live test | PreRelease P1-03; `QA_TEST_PLAN.md:94-104` | [Fact] Open. `ControllerUI.lua:97-138` still calls `SmartNavigation.RegisterCallback` when the (default-off) edge cue is enabled. |
| P6 | Fold `AlertGeneric` into CastActivity, keeping `IGNORED_SPELL_IDS` | `CastActivity.lua:18-24` (tracked) | [Fact] Open. |
| P7 | Drowning: add tests (§8) and confirm 3 client assumptions (§6); optionally move to wound-event-driven thuds and fix heartbeat scheduling (§7) | `docs/PulseHaptics-drowning-detection-review.md` (local only) | [Fact] Patch applied. No `environment-test` suite exists (`test.sh:20-28`). §6 [Unverified]. |
| P8 | Engine architecture phases 1–19 (signal classes, envelopes, concurrency, priority, capability states, debug, regression tests) | `docs/PulseHaptics_Haptics_Engine_Implementation_Plan_and_Prompt.md`; `…Rewrite_Analysis.md` "Recommended implementation direction" (local only) | [Fact] Partly done (see A.1.3). |
| P9 | Revisit the water textures (`swimTexture`, `waterTexture`, `oceanTexture`) after refinement | `ProfileReviewReports/Immersion-Ranged-Cue-Review.md:15-16` (untracked) | Open |
| P10 | Run the in-game QA matrix: crafting/gathering, minimap, controller UI, taint log | `docs/dev-notes/QA_TEST_PLAN.md` (tracked) | [Unverified] No results recorded. |
| P11 | Cited design docs missing from the repo (≈48 comment sites) | `outstanding.md` #2 | [Fact] Decided: leave as is. |
| P12 | Review PulseChecklist, PulseDebug and their tests | `outstanding.md` #7 | [Unverified] whether this was ever done. |

[Fact] The profile review produced decisions without a stated plan to act on them. The report says it "does not infer or apply new profile defaults" (`Immersion-Ranged-Cue-Review.md:5`, `:97`). A probe compared it with the seeded `Immersion: Ranged` defaults:
- **20 cues are seeded ON but were reviewed No.** Examples: `glideThrust`, `swimTexture`, `waterTexture`, `oceanTexture`, `weatherTexture`, `procGlow`, `threatAggro`.
- **53 cues are seeded OFF but were reviewed Yes.** Examples: `castTexture`, `damageTaken`, `uiNavigateEdge`, `whisper`.
- The report says "0 not reviewed", but it lists 189 of 190 cues. **`bankOpened` is missing.**

### A.3 Imminent next phase (recommendations, in priority order)

1. **Get the baseline green and settle the uncommitted work.**
   - [Rec] Fix the test key (`"g:guid-hearth-1"`).
   - [Rec] Make the ceiling assertion non-vacuous: keep `UnitCastingInfo` active past 60 s and assert removal.
   - [Rec] Commit the Engine, CastActivity and Database changes as separate, reviewable commits, or drop them.
   - *Why:* every later step needs a passing suite, and three unrelated changes currently share one dirty tree. *Depends on:* nothing.
2. **Fix the `rolePool` overwrite and add a regression test.**
   - [Rec] Copy step roles into per-step storage owned by the closure, or have the step read from a table the pool doesn't recycle. Turn the probe from A.1.2 into an `engine-test` case.
   - *Why:* it is a committed correctness bug, and it corrupts any in-game judgment of how cues feel. *Depends on:* 1.
3. **Review the uncommitted engine changes before tuning anything in-game.**
   - [Rec] The comment at `Engine.lua:479` says transients also force a send, but `forceSend = isOnset` (`:475`). Make the comment and code agree.
   - [Rec] The spacing guard at `:392-395` looks dead: `offset` already grows by at least `MIN_STEP_DURATION` per step (`:412`). [Inference]
   - [Rec] `MIN_GAP_DURATION` changes the rhythm of authored modes whenever `durMult < 1`. [Unverified] what range `durMult` can take.
   - *Why:* these change how every cue feels. *Depends on:* 2.
4. **Settle the CastActivity sweep policy.**
   - [Rec] Name the `60` constant (`CastActivity.lua:343`, `:349`, `:355`).
   - [Rec] Decide whether a sweep should emit `CRAFT_STOPPED`/`CAST_STOPPED`. It currently clears state silently. Crafting has its own 0.5 s failsafe (`Crafting.lua:310-335`).
   - [Rec] Check whether `UnitCastingInfo` values can be secret under 12.x. The new truthiness test (`:334-339`) has no `issecretvalue` guard. [Unverified]
   - *Depends on:* 1.
5. **Harden `scripts/test.sh`.**
   - [Rec] Capture exit codes without tripping `set -e`, for example `TEST_OUT=$(…) || TEST_STATUS=$?`.
   - *Why:* a crashing suite currently fails with no output.
6. **Reconcile the docs with the code.**
   - [Rec] Use 190 cues and 35 modes, and fix the category count in README/CURSEFORGE.
   - [Rec] Update the tests README and `QA_TEST_PLAN.md`.
   - [Rec] Document `/pulse stop`, including that it is momentary.
   - *Why:* the public beta page makes numeric claims the code doesn't back. *Depends on:* the decision on open question D5.
7. **Close the remaining planned beta items P1–P3.** *Why:* they are small and already specified. *Depends on:* decision D3 for P1.
8. **Follow through on the profile review.** Only after decisions D1 and D2.
   - [Rec] If the review should change defaults, remember that seeding only fills missing values (`Database.lua:832-844`). Existing users would need a `DB_VERSION` migration (currently `7`, `Database.lua:27`).
   - [Rec] Fix the frame leak and the write-on-read behaviour in `Review.lua` before anyone else uses the tool.
9. **In-game verification pass (P10, P7 §6, P5, P4).** [Rec] Record the results in a tracked file. *Why:* nothing has been verified in the live client yet. *Depends on:* 2–4, so the engine being tested is the final one.
10. **Engine architecture phases (P8). Not imminent.** [Rec] Revisit only after step 9 gives real hardware data. Start with the readiness audit's façade and mixer extraction.

### A.4 Risks and open decisions

- **D1 — Should the review decisions become the shipped defaults for `Immersion: Ranged`?** The report explicitly says it doesn't apply them. Applying them for existing users means writing a migration that overwrites their choices.
- **D2 — Should PulseProfileReview be tracked, and shipped in the Suite zip?** It currently sits outside lint, tests and packaging.
- **D3 — Should the `_G.issecretvalue` stub stay?** The beta assessment asked for it to be moved, but the harness and other code may rely on the global. Needs checking.
- **D4 — Which interface number?** The TOCs declare `120100, 110200, 110100`, restored in `d293bb0`. The pre-release review (P0-01) wanted `16001`. The beta assessment §3.2 dismissed that after a `/dump` showed `120100`. [Unverified] for any other client, such as the live Forever build.
- **D5 — Mixer semantics.** The saturating sum can let several quiet continuous textures add up to a strong one. Whether that is intended is a design question the readiness audit raised.
- **D6 — What `/pulse stop` should mean.** A momentary stop, or a real mute that sets `masterEnabled` or adds a session-mute flag. The beta assessment says the master toggle is locked in combat to avoid taint (`Beta_Review_Assessment.md:52-55`).
- **D7 — `uiNavigateEdge`.** The review marks it Yes, but it relies on the `SmartNavigation.RegisterCallback` path, which has a known taint history (`outstanding.md` #11). Don't enable it by default before the live test.
- **Risk:** the planning history is local-only (gitignored), so it can't be recovered from a clone. Consider tracking at least a short roadmap.
- **Risk:** the offline suites run against stubs. Taint, SDL trigger channels and secret-value behaviour can't be tested offline.
- **Risk:** `dist/` zips (gitignored, built 2026-09-24 23:09) match HEAD, not the working tree. [Unverified] contents.

### A.5 Code review checklist

| Area | Acceptance criteria |
|---|---|
| Test baseline | `./scripts/test.sh` exits 0, with luacheck clean and all 7 suites (or more) passing, under both `lua` and `luajit`. No assertion passes against a key or table that never existed. |
| Test runner | A deliberately crashing suite prints its error output and is counted as FAIL (check `scripts/test.sh:82`, `:122`). |
| `PlayMode` steps | A new engine-test case: a strong cue followed by 20 or more weak cues within its duration. The strong cue's delayed steps keep their own magnitude and role. Keep the per-frame zero-allocation goal where it doesn't conflict with correctness. |
| Engine output path | Code comments match behaviour (`Engine.lua:475-480`). Raw-hold `SetVibration` calls (`:518`, `:529`) are either wrapped in `pcall` like the rest, or documented as deliberately unwrapped. `StopAll` clears all per-channel state, including `lastWantedByChannel`. |
| Mode timing | A table test showing each authored mode's step schedule is unchanged at `durMult = 1`. Any change at other `durMult` values is intentional and written down. |
| CastActivity | No magic numbers. Sweep behaviour is covered for: a player cast that is still active, an orphaned cast, an orphaned channel, and an orphaned craft. Consumers get a defined outcome, or a documented reason why they don't. Secret-value guards appear wherever a returned value is tested for truth. |
| Profiles | Every built-in profile has metadata, so `GetDefaultProfileMeta` never returns nil for a built-in. A load-time test fails if an override references an unknown cue ID. A migration exists if defaults change. |
| Rename/notify | Renaming the active profile notifies listeners exactly once. Renaming an inactive profile does not notify. |
| Docs | Cue, mode and category counts in README, CURSEFORGE, the tests README and the `Registry.lua` header match `cue-audit` output. `QA_TEST_PLAN.md` commands and paths match the current addon. |
| Beta checklist | Items 1.1–1.6 in `Beta_Review_Assessment.md` are each ticked with a commit reference, or explicitly deferred. |
| PulseProfileReview (if kept) | Linted with a `.luacheckrc` entry. No frame is created per refresh (reuse a row pool). Reading never writes saved variables. The report counts line up with the registry: 190 cues, `bankOpened` included. |
| In-game | QA plan sections 1–4 executed and the results recorded in a tracked file. The taint log is clean after toggling the gamepad and using controller UI. The drowning assumptions in §6 of the drowning review are confirmed. The trigger-channel result is recorded. |

---

## Appendix B. What the first planning review was based on

Recorded because the review above was written before the full document and history passes (sections 1–9). Its coverage was uneven:

- **Repo root, fully read:** `README.md`, `CURSEFORGE.md`, `.gitignore`, `ProfileReviewReports/Immersion-Ranged-Cue-Review.md`, `PulseProfileReview/README.md`, `.toc`, `Review.lua`. Unread: `LICENSE`, `.luacheckrc`.
- **`docs/`, fully read:** `dev-notes/QA_TEST_PLAN.md`, `dev-notes/outstanding.md`, `dev-notes/Beta_Review_Assessment.md`, `PulseChecklist/tests/README.md`.
- **`docs/`, partly read:** the PreRelease review (summary, P0-02, P1-05/06, P2), the drowning review (§1–4, §6–9), the implementation plan (objective, constraints, headings), the readiness audit (§3 plus headings), the rewrite analysis (last section plus headings), the critical engine review (headings only).
- **`docs/`, unread at that time:** the architecture explanation, all of `ReviewsofReviews/`, most of `dev-notes/`, `ui-review/`, `Archive.zip`, and the vendored reference folders. *(All project docs were read afterwards for sections 1–8.)*
- **Source:** fully read `Core/Engine.lua`, `Core/CastActivity.lua`, the working-tree diff, `scripts/test.sh`, `scripts/package.sh`. Partly read (greps or excerpts): `Database.lua`, `Init.lua`, `Panel.lua`, `Environment.lua`, `Crafting.lua`, `Registry.lua`, `ControllerUI.lua`, `AlertGeneric.lua`, `engine-test.lua`. Unread: most of `Modules/`, all of `UI/Panel/`, `Devices.lua`, `Modes.lua`, `Waves.lua`, `PulseDebug/`, `Checklist.lua`, `harness.lua`.
- **Executed:** `./scripts/test.sh`, the suites under `luajit`, `cue-audit`, and scratch probes (role-pool overwrite, profile override IDs, review versus defaults).
- **Consequence:** the runtime findings held (role pool, test key, `test.sh`, count drift, profile diffs). The planned-work section and the engine-plan claims were incomplete until sections 4 and 9 replaced them.

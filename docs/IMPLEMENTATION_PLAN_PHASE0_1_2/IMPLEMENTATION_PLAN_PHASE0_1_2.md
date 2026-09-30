# Implementation Plan — Phase 0, Phase 1, Phase 2

> **Scope:** Phase 0 (preconditions and engine repair), Phase 1 (event arbitration), Phase 2 (settings panel ergonomics and page switches). **Phase 3 (Blueprint C: dynamic mixer and presets) is on temporary hold and is not planned here.**
> **Source:** `brainstormingcuepolish_review.md` §10, as accepted by the project owner on 2026-09-30.
> **Target client:** World of Warcraft Forever — `_classic_beta_`, build `1.60.1.69913`, Interface `120100`. Reference UI source: `docs/DevelopmentplusReference/Developer Documents/WOW SOURCECODE/wow-ui-source-forever/` (`version.txt` = `1.60.1.69913`), written below as `<forever-src>/`.
> **Code baseline:** `441f4f3` (`main`). The only local change is the uncommitted `.luacheckrc`, which this plan extends. All `path:line` references are to that baseline.
> **Status of the repository:** read-only. No `.lua`, `.toc` or `.xml` file in the addon folders was modified. This plan lives in the `IMPLEMENTATION_PLAN_PHASE0_1_2/` folder with its implementation package (see `README.md` there).
> **Update (same day):** `main` moved to `0c74dc3`, the owner's fix for the Engine half of P0.1. Every line reference below is still valid, except in `PulseHaptics/Core/Engine.lua`, where lines from 527 onward are one lower. The patches in `patches/` are generated against `0c74dc3`.
> **Date:** 2026-09-30

**Evidence labels:**
- **[Fact]** — read in code or source, or observed in a command's output.
- **[Inference]** — follows from facts, not observed in game.
- **[Unverified]** — needs the in-game probe (P0.2).
- **[Decision]** — a choice this plan makes, with the reason given.

---

## 0. How this plan was checked, and what it covers

**Checked offline.** Every code block below was applied to a disposable copy of the tree (built with `git archive HEAD`, outside the repository) and run through the project's own test battery. The exact changes are in `patches/`. `bash IMPLEMENTATION_PLAN_PHASE0_1_2/verify.sh` reproduces this table without touching the repo; its latest output is in `evidence/test-runs/verify-run.log`. The results:

| Step | Applied to the copy | Result |
|:--|:--|:--|
| Phase 0.1 alone | Engine fix + new exact-value assertions | Fixed code: **7/7 suites, luacheck 0/0, stylua clean**. The same assertions against the regressed `Engine.lua` (`441f4f3`): **6 failures**, as intended. |
| Phase 0 + 1 | + `Core/Arbiter.lua` and the module changes | **8/8 suites** (new `arbitration-test`: 43 checks at this stage). |
| Phase 0 + 1 + 2 (final) | + page switches, panel changes, and the intake-bus refinement | **9/9 suites**, luacheck 0/0. `arbitration-test`: 46 checks; new `phase2-test`: 49 checks. |
| Mutation check (final state) | HEAD's `Interaction.lua` swapped back in; separately, HEAD's `Inventory.lua` | 5 failures with `Interaction.lua` (R2, R3, R4 ×2, B1); 2 with `Inventory.lua` (V2, L2). The tests bite. |

**What that proves and what it doesn't.** [Fact] The logic, the data wiring, and the UI page building (harness builds every page, zero dropped rows) are proven offline. [Unverified] Event order on the live client, felt timing, and widget geometry need the game. Phase 0.2 exists to measure them, and each phase ends with an in-game acceptance list.

**Work packages and order:**

| ID | Work package | Main files | Depends on |
|:--|:--|:--|:--|
| **P0.1** | Restore the `mapValue` floor branch; exact-value tests | `Core/Engine.lua`, `PulseChecklist/tests/engine-test.lua` | — |
| **P0.2** | Event-order trace in PulseProbe; offline report | `PulseProbe/Core.lua`, new `PulseProbe/Probes/Sequencer.lua`, new `scripts/probe-trace-report.lua` | — (run in parallel with P1) |
| **P0.3** | The owner rule, written as policy and as Registry data | `Core/Registry.lua` (data), this document | — |
| **P1.0** | Arbitration core: liveness, episodes, buses | new `Core/Arbiter.lua`, `Core/Init.lua`, `PulseHaptics.toc` | P0.3 |
| **P1.1** | Vendor purchase guard that respects the owner | `Modules/Inventory.lua` | P1.0 |
| **P1.2** | Loot episode with a leading-edge claim | `Modules/World.lua`, `Modules/AlertWorld.lua`, `Core/Arbiter.lua` | P1.0 |
| **P1.3** | Repair recognition; durability fires on worsening only | `Modules/Interaction.lua`, `Modules/World.lua` | P1.0 |
| **P1.4** | Window priority bus; deferred close | `Core/Registry.lua`, `Core/Init.lua`, `Modules/Interaction.lua` | P1.0 |
| **P1.5** | Tests and tooling | new `PulseChecklist/tests/arbitration-test.lua`, `harness.lua`, `cue-audit.lua`, `scripts/test.sh`, `.luacheckrc` | P1.1–P1.4 |
| **P2.1** | Page switches (non-destructive group gates) | `Core/Registry.lua`, `Core/Init.lua`, `Core/Database.lua` | P1.0 (`GatesOpen`) |
| **P2.2** | Collapsible sections, fold state saved account-wide | `UI/Panel/Content.lua`, `UI/Panel/Rows.lua`, `UI/Panel/Spec.lua`, `Core/Database.lua` | — |
| **P2.3** | One-line cue rows | `UI/Panel/Rows.lua`, `UI/Panel/Spec.lua`, `UI/Panel/Theme.lua` | P2.2 |
| **P2.4** | Simple view | `UI/Panel/Spec.lua`, `UI/Panel/Sidebar.lua`, `UI/Panel/Panel.lua`, `Core/Database.lua` | P2.1 |
| **P2.5** | Tests | new `PulseChecklist/tests/phase2-test.lua`, `harness.lua` | P2.1–P2.4 |

**Release gate [Decision].** Phase 1 code can merge with its default constants. The release that ships it waits for the P0.2 trace report, which confirms or replaces the constants in the P0.2 decision table.

---

## 1. Ground rules and how each is met

| Rule | How it's met in this plan |
|:--|:--|
| **Lua 5.1** | No `goto`, no integer division, no bitwise operators, no `table.unpack`. Every new file compiles under `luajit -bl` and lints under the repo's `.luacheckrc`. |
| **Rule 4: no garbage in hot paths** | The event path allocates nothing: flat scalar state, arrays wiped and reused, bus tables pre-seeded at load, `C_Timer.After(0, STATIC_FN)` with a named function (no closure per event). Allocation is confined to load time, `BindFrame` time (one `seen` table per bind), panel build, and player-initiated dumps. |
| **Rule 5: no taint** | No protected API is called. The only hook is `hooksecurefunc("RepairAllItems", fn)`, a post-hook, the same mechanism the code already uses on `JumpOrAscendStart` (`Modules/Movement.lua:119-120`) and `PanelTemplates_SetTab` (`Modules/ControllerUI.lua:281`). No Blizzard frame, attribute or binding is written. The panel stays mouse-driven (`UI/Panel/Gamepad.lua:40-69`); nothing here touches SmartNavigation. |
| **Secret values** | Every value from the client passes through `issecretvalue()` before use: money, repair cost, loot slot fields, alert status, the loot-chat GUID, interaction state. A secret value always takes the safe branch, which is "don't fire" or "don't suppress", depending on which is harmless. |
| **Non-destructive** | Nothing in Phases 1 and 2 writes to a cue's own setting. Gates and fold state are read-only overlays. |

---

## 2. Phase 0 — Preconditions and engine repair

### P0.1 Restore the missing `else` in `Engine.lua` `mapValue`

**Status after `0c74dc3` [Fact].** The owner's commit restored the `else`. That is functionally the fix below, so the Engine half is done. Its test change (continuous input 0.02 with bound `> 0 and < 0.08`) catches the continuous half of the regression: an unfloored 0.02 decays to 0. It does **not** catch the doubled discrete floor, because 0.2727 still passes `>= 0.125`.

The remaining P0.1 work is the exact-value test block below. That's `patches/01-P0.1-engine-floor.patch`, which touches only `engine-test.lua`. Evidence: `evidence/test-runs/floor-regression-detection.log`.

**Defect.** [Fact] Commit `f623a8a` deleted the `else` that separated the discrete-cue hard floor from the continuous soft floor (`git diff 1ca6a24 HEAD -- PulseHaptics/Core/Engine.lua`). At HEAD (`PulseHaptics/Core/Engine.lua:524-538`):
- Discrete cues get the floor applied twice. On an Xbox high motor the effective floor is 0.181 instead of 0.095.
- Continuous textures get no floor at all. An input of 0.08 on a Low motor with floor 0.125 comes out as 0.108, below breakaway.

**Fix (exact diff, verified):**

```diff
--- PulseHaptics/Core/Engine.lua (441f4f3)
+++ PulseHaptics/Core/Engine.lua
@@ -524,9 +524,11 @@
 	local floor = channelConfig(channel, "floor")
 	if floor and floor > 0 then
 		if isTransient then
+			-- Hard breakaway floor: a discrete cue has to kick the mass over static friction on
+			-- its first frame, so every non-zero value is lifted into (floor, 1].
 			v = floor + (1.0 - floor) * v
+		else
 			-- Soft floor for continuous immersion textures (CR-008 b / F-01):
-			-- Transients need the hard breakaway floor immediately to kick over static friction.
 			-- Continuous textures scale the knee with the floor (default floor * 0.5) so that
 			-- authored defaults (~0.06-0.10) stay comfortably above breakaway, while low user
 			-- slider settings (<0.04) fade smoothly to whisper-quiet or dead silence.
```

The knee formula `math.max(0.02, floor * 0.5)` that `f623a8a` introduced for F-01 is kept unchanged.

**Test.** Replace `PulseChecklist/tests/engine-test.lua:552-574` in full. The old bounds (`< 0.08`, `>= 0.125`) pass both the correct code and the regression.

```lua
-- ── CR-008 b / F-01: breakaway floor, exact values ─────────────────────────
-- Exact outputs, not bounds. With gamma 1.0 and gain 1.0 (the mock's defaults), mapValue is:
--   discrete:   floor + (1 - floor) * v
--   continuous: floor * smoothstep(clamp(v / knee)) + (1 - floor) * v,  knee = max(0.02, floor * 0.5)
-- 120 frames at 16 ms settle both smoothing lanes to within 1e-6 of their target, so the
-- smoothed channel value IS the mapped value. The old bounds (< 0.08, >= 0.125) passed both
-- the correct code and f623a8a's missing-else regression; these do not.
local function settledLow(name, low, isTransient)
	Engine:StopAll()
	Engine:Hold(name, low, 0, 5.0, isTransient)
	for _ = 1, 120 do
		frameScripts.OnUpdate(nil, 0.016)
	end
	local ch = Engine:_DebugChannels()["Low"]
	return ch and ch.smoothed or 0
end
local function near(got, want)
	return math.abs(got - want) < 1e-4
end

mockFloor = 0.125
check("discrete 0.05 on floor 0.125 = 0.16875", near(settledLow("floor_d05", 0.05, true), 0.16875), true)
check("discrete 0.50 on floor 0.125 = 0.5625", near(settledLow("floor_d50", 0.50, true), 0.5625), true)
check("continuous 0.02 fades below floor = 0.047708", near(settledLow("floor_c02", 0.02, false), 0.047708), true)
check("continuous 0.05 on floor 0.125 = 0.15575", near(settledLow("floor_c05", 0.05, false), 0.15575), true)
check("continuous 0.10 clears the floor = 0.2125", near(settledLow("floor_c10", 0.10, false), 0.2125), true)
check("  and an authored default stays >= floor", settledLow("floor_c10b", 0.10, false) >= 0.125, true)
mockFloor = nil
check("no floor configured: continuous 0.05 passes through", near(settledLow("floor_none", 0.05, false), 0.05), true)
Engine:StopAll()
```

**Where the expected values come from.** Floor f = 0.125 and knee k = 0.0625. The smoothstep is s(t) = t²(3 − 2t).

| Input | Formula | Expected | HEAD produces |
|:--|:--|:--:|:--:|
| discrete 0.05 | 0.125 + 0.875·0.05 | **0.16875** | 0.27266 (floor applied twice) |
| discrete 0.50 | 0.125 + 0.875·0.50 | **0.5625** | 0.6172 |
| continuous 0.02 | 0.125·s(0.32) + 0.875·0.02 | **0.047708** | 0.02 |
| continuous 0.05 | 0.125·s(0.8) + 0.875·0.05 | **0.15575** | 0.05 |
| continuous 0.10 | 0.125·s(1) + 0.875·0.10 | **0.2125** | 0.10 |

**Verification.**
- [Fact] In the disposable copy, fixed code: every new check `ok`; `./scripts/test.sh` gives 7/7 and luacheck 0/0; `stylua --check` is clean on both files.
- [Fact] HEAD's `Engine.lua` with the new test: `FAILURES: 6`. The only passing check is the no-floor case, which is correct because the defect only matters when a floor is set.
- In game: on an ERM preset (Xbox), a light cue (TICK at master 0.7) must be as audible as before `f623a8a`. A low-intensity texture (swim, at slider 0.10) must spin the motor.

### P0.2 PulseProbe event-order instrumentation

**Why.** [Fact] The probe timestamps with `GetTime()` (`PulseProbe/Core.lua:61`). `GetTime()` is frame-cached, so it can't separate or order events delivered in the same frame. Every constant in Phase 1 depends on that ordering.

**Which clocks to record.**
- **[Fact]** `debugprofilestop()` returns *"the time in milliseconds since the last debugprofilestart call"* (`<forever-src>/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua:533-540`). Any addon calling `debugprofilestart()` resets it.
- **[Fact]** `GetTimePreciseSec()` exists on Forever (`…/OsDocumentation.lua:27-34`).
- **[Decision]** Record both. Use `GetTimePreciseSec()` as the primary clock and `debugprofilestop()` only as a cross-check. Never call `debugprofilestart()`, because that would reset every other addon's profiler.
- Add a frame counter (incremented once per `OnUpdate`) and an arrival index within each frame. Together they say "same frame" and "who came first" exactly.

**`PulseProbe/Core.lua`: insert before the "Probe Module Registration" block (`:89`).**

```lua
---------------------------------------------------------------------------
-- Event-order trace (Phase 0 measurement)
---------------------------------------------------------------------------
-- Struct-of-arrays ring, sized once, overwritten in place: recording stores references and
-- numbers, never builds a table or a string (Rule 4). Clocks: frame (per OnUpdate),
-- arrival (order within a frame), precise (GetTimePreciseSec), profile (debugprofilestop,
-- cross-check only; this file never calls debugprofilestart).

local TRACE_CAP = 4096
local tEvent, tFrame, tArrival, tPrecise, tProfile = {}, {}, {}, {}, {}
local tA1, tA2, tA3 = {}, {}, {}
for i = 1, TRACE_CAP do
	tEvent[i], tFrame[i], tArrival[i], tPrecise[i], tProfile[i] = "", 0, 0, 0, 0
	tA1[i], tA2[i], tA3[i] = false, false, false
end

local trace = { head = 0, count = 0, running = false, scenario = "", frame = 0, arrival = 0 }
Probe.TraceState = trace

local SECRET = "<secret>"
local preciseClock = (type(GetTimePreciseSec) == "function") and GetTimePreciseSec or GetTime
local profileClock = (type(debugprofilestop) == "function") and debugprofilestop
	or function()
		return 0
	end

-- Numbers, booleans and client-provided strings are kept as references (no allocation).
-- Anything else is reduced to its type name; secret values are masked, never compared.
local function scalar(v)
	if v == nil then
		return false
	end
	if issecretvalue and issecretvalue(v) then
		return SECRET
	end
	local kind = type(v)
	if kind == "number" or kind == "boolean" or kind == "string" then
		return v
	end
	return kind
end

local clockFrame = CreateFrame("Frame")
clockFrame:SetScript("OnUpdate", function()
	trace.frame = trace.frame + 1
	trace.arrival = 0
end)

function Probe:Record(event, a1, a2, a3)
	if not trace.running then
		return
	end
	trace.arrival = trace.arrival + 1
	local i = (trace.head % TRACE_CAP) + 1
	trace.head = i
	if trace.count < TRACE_CAP then
		trace.count = trace.count + 1
	end
	tEvent[i] = event
	tFrame[i] = trace.frame
	tArrival[i] = trace.arrival
	tPrecise[i] = preciseClock()
	tProfile[i] = profileClock()
	tA1[i], tA2[i], tA3[i] = scalar(a1), scalar(a2), scalar(a3)
end

function Probe:TraceStart(scenario)
	trace.head, trace.count = 0, 0
	trace.scenario = scenario or "unnamed"
	trace.running = true
end

function Probe:TraceStop()
	trace.running = false
end

-- The only allocating path: copies the ring, oldest first, into SavedVariables.
-- Player-initiated, never during play.
function Probe:TraceDump()
	local db = self.DB
	if not db then
		return 0
	end
	db.traces = db.traces or {}
	local rows = {}
	local first = (trace.count < TRACE_CAP) and 1 or ((trace.head % TRACE_CAP) + 1)
	for n = 0, trace.count - 1 do
		local i = ((first - 1 + n) % TRACE_CAP) + 1
		rows[#rows + 1] = { tEvent[i], tFrame[i], tArrival[i], tPrecise[i], tProfile[i], tA1[i], tA2[i], tA3[i] }
	end
	db.traces[#db.traces + 1] = {
		scenario = trace.scenario,
		build = select(2, GetBuildInfo()),
		interface = select(4, GetBuildInfo()),
		rows = rows,
	}
	return #rows
end
```

**Slash commands.** Add these as the first branch of `SlashCmdList["PULSEPROBE"]` (`PulseProbe/Core.lua:165-167`), before `if cmd == "clear"`. The messages are shortened here to plain `print` calls. The prototype prints with the probe's colour prefix.

```lua
	local verb, rest = cmd:match("^trace%s*(%S*)%s*(.*)$")
	if verb then
		if verb == "start" then
			Probe:TraceStart(rest ~= "" and rest or "unnamed")
		elseif verb == "stop" then
			Probe:TraceStop()
		elseif verb == "mark" then
			Probe:Record("MARK", rest)
		elseif verb == "dump" then
			print(("[PulseProbe] dumped %d rows; /reload to write"):format(Probe:TraceDump()))
		end
		return
	end
```

**New `PulseProbe/Probes/Sequencer.lua`** (full reference in Appendix C; append it to `PulseProbe/PulseProbe.toc`). It:
- Registers 30 events: vendor, repair, bags and intake, loot window, interaction windows, mail, bank, pull, swing, equipment.
- Records one or two state samples per event, each answering a specific question:
  - `GetMoney()` on `PLAYER_MONEY`
  - free slots on `BAG_UPDATE_DELAYED`
  - `GetRepairAllCost()` and `InRepairMode()` on `UPDATE_INVENTORY_DURABILITY`
  - the worst `GetInventoryAlertStatus` value on `UPDATE_INVENTORY_ALERTS`
  - `GetNumLootItems()` on `LOOT_READY` (is the list readable yet?)
  - the looter GUID on `CHAT_MSG_LOOT`
  - `InCombatLockdown()` and `UnitAffectingCombat("player")` on `PLAYER_REGEN_*`
- Post-hooks `RepairAllItems`, plus `OpenAllMail.StartOpening`/`StopOpening` if that frame exists.
- Schedules a `C_Timer.After(0)` marker (`TIMER0`) on every interaction hide, to test the deferred-close assumption.
- Polls `GetUIPanel("left")` every frame, to measure how late `panelOpen` is.

**New `scripts/probe-trace-report.lua`** (full reference in Appendix C), run as `luajit scripts/probe-trace-report.lua <path to WTF/Account/<ACCOUNT>/SavedVariables/PulseProbe.lua>`. For every event pair below it prints n, p50, p95, max (ms), and the same-frame count. [Fact] Validated on a synthetic dump; luacheck 0/0.

**`.luacheckrc`** (on top of the uncommitted additions) — add to `read_globals`: `GetLootSlotInfo`, `GetRepairAllCost`, `InRepairMode`, `RepairAllItems`, `INVENTORY_ALERT_STATUS_SLOTS`, `GetTimePreciseSec`, `debugprofilestop`, `OpenAllMail`.

**Scenarios to run.** For each scenario:
1. Run `/probe trace start <name>`.
2. Act out the scenario three times.
3. Run `/probe trace stop` and `/probe trace dump`.
4. `/reload` to write the dump.

Run every scenario twice: at a 30 fps cap, and uncapped at 60+ fps. Do this on wired Ethernet and again on Wi-Fi.

| # | Scenario | Question it answers | Constant or decision it sets | Default if unmeasured |
|:--|:--|:--|:--|:--|
| S1 | Buy 1 item into a new slot; into an existing stack; buy back | Order and gap between money and bag settle | Confirms P1.1 is order-independent (no constant) | — |
| S2 | Repair all (personal); repair all (guild); repair one item with the cursor; equip an item with the vendor open | Hook → confirmation → debit timing; does equipping send `UPDATE_INVENTORY_DURABILITY`? | `REPAIR_WINDOW`, `DEBIT_WINDOW` | 2.0 s, 1.0 s |
| S3 | Corpse loot with autoloot; manual click per slot; with full bags; group loot above the threshold | Gap between slots; tail from `LOOT_CLOSED` to the last `BAG_UPDATE_DELAYED`; does `LOOT_SLOT_CLEARED` exist? Is `GetNumLootItems()` > 0 at `LOOT_READY`? | `LOOT_TAIL`; whether to scan at `LOOT_READY` | 0.30 s; scan at both events |
| S4 | Herb / mine / skin / fish | The gathering cluster: cast end → `LOOT_READY` → intake | Confirms `harvestComplete` yields correctly | — |
| S5 | Talk to an NPC through gossip, then open the vendor; with the mailbox open, click a vendor; close a bank | Does `HIDE` come in the same frame as `SHOW`? Does `TIMER0` run before the `SHOW`? How late is `UIPANEL_LEFT`? | Keep the one-frame deferral (y/n); `DEFAULT_BUS_WINDOW` | Keep; 0.15 s |
| S6 | Open All Mail with 10+ attachments; `/dump OpenAllMail ~= nil` | Does the Blizzard button exist on Forever? Item spacing | Informs a future bulk coalescer (not in Phase 1) | — |
| S7 | Pull a mob (melee, ranged, pet pull) | `InCombatLockdown()` inside `PLAYER_REGEN_DISABLED`; regen → threat gap | Input for the deferred pull bus (see P0.3 "out of scope") | — |
| S8 | Windfury / Sword Specialization procs on a target dummy | `PLAYER_SWING` gaps shorter than the weapon's `swingDuration` | Feasibility of detecting extra attacks without the combat log (Phase 4, not planned here) | — |

### P0.3 The owner rule — formal policy

**Definitions.**
- **Live cue.** `Arbiter:IsLive(id)` is true when all of these hold:
  - `masterEnabled`
  - the cue's own switch (`Database:GetCue(id)`)
  - every gate in front of it (`Pulse:GatesOpen(id)`: its category master and, from P2.1, its page switch)
  - per-cue `intensity > 0`
- **Episode.** A span of time the game marks with its own start and end events: the vendor visit (interaction open → close) and the loot window (`LOOT_READY`/`LOOT_OPENED` → `LOOT_CLOSED`, plus a short tail).
- **Owner.** The cue that speaks for an episode.
- **Yielder.** A cue that would repeat the owner.
- **Semantic exclusion.** A cue that is simply the wrong meaning in that context. For example, a sale is not "consuming" an item: `Inventory.lua:149` keeps that guard unconditionally. A semantic exclusion is not an owner relation and doesn't depend on liveness.
- **Bus.** A family of cues that share one engine layer. A lower-priority cue arriving inside the bus window after a higher one is dropped. A higher one arriving after a lower one replaces it. [Fact] `Engine:PlayMode` on the same layer name bumps that layer's token, which voids the earlier cue's pending steps and overwrites the layer (`Core/Engine.lua:354-355`, `:484`).

**The rule.** A yielder stands down only while its episode is open **and** at least one of that episode's owners is live in the active profile.

**Invariants.** P1.5 and P2.5 test every one of these.

| # | Invariant | Why |
|:--|:--|:--|
| I1 | Never silence an action whose owner isn't live | [Fact] Default has `merchantBuy` off and `bagItemAdded` on (`Database.lua:1032-1035`) |
| I2 | Results don't depend on event order | [Unverified] Arrival order of money, bag, item and chat events isn't guaranteed |
| I3 | No latch outlives its window | The HEAD `wasRepair` latch can swallow a later transaction (review §7.2) |
| I4 | Nothing allocated per event | Rule 4 |
| I5 | No protected call; only post-hooks | Rule 5 |
| I6 | Never write a cue's own setting | Non-destructive |
| I7 | A dropped cue keeps its throttle budget | Otherwise a cue the bus dropped would also lose its next legitimate firing |

**Data (the single source of truth).** Add to `Core/Registry.lua` directly after `Registry.ALERT_CATEGORY_MASTER` (`:88-91`):

```lua
-- Owner-aware arbitration (Core/Arbiter.lua). Data, not code, so cue-audit can check it.
--
-- OWNER RULE: a yielder stands down only while its episode is open AND at least one of the
-- episode's owners is live (enabled, gated open, intensity > 0) in the active profile. A
-- disabled owner never silences its yielders — the Default profile has merchantBuy off and
-- bagItemAdded on, and its players must still feel a purchase.
--
-- NOT HERE: semantic exclusions, where the secondary cue is simply the wrong meaning (a
-- sale is not "consuming" an item — Inventory.lua keeps that unconditional guard).
Registry.EPISODES = {
	vendor = {
		owners = { "merchantBuy" },
		yielders = { "bagItemAdded", "itemObtained" },
	},
	loot = {
		-- Precedence: the first live cue here speaks for the whole loot window's items.
		intake = { "itemObtained", "lootReceived", "bagItemAdded" },
		-- Coins speak only for a coin-only window, or when no item cue is live.
		coin = "lootGold",
		-- The window opening: lootOpened owns it; harvestComplete (LOOT_READY) yields.
		openOwner = "lootOpened",
		openYielders = { "harvestComplete" },
	},
}
```

Buses are per-trigger fields (`bus`, `busPriority`, optional `busWindow`); P1.4 has the table.

**cue-audit additions** (in `PulseChecklist/tests/cue-audit.lua`, a new section after the trigger checks):
- every id named in `EPISODES` exists in `Pulse.Triggers` and has a `mode`
- no cue is both owner and yielder of the same episode
- every trigger with `bus` also has a numeric `busPriority`
- every bus has at least two members

**Out of scope for Phases 0–2 [Decision].** These were recommended in the review but aren't in this brief:
- the `pull` bus (`combatEnter` vs `threatAggro`)
- the bulk-sale / Open-All coalescer
- the self-only filter for `lootReceived` outside a loot window. Delivered anyway in P1.2, because the loot episode already routes that cue.

The pull bus and the bulk coalescer are data-only or near-data additions on top of P1.0. Measure them with S6 and S7 first.

---

## 3. Phase 1 — Event arbitration

### P1.0 Arbitration core

**New file `PulseHaptics/Core/Arbiter.lua`** (complete reference in Appendix A). It provides:
- `IsLive`
- `IsMerchantOpen` / `VendorOwnsIntake`
- the loot episode API: `LootOpened`, `LootClosed`, `LootReset`, `LootIntake`, `LootSlotCleared`
- `ClaimBus` / `SeedBuses`

**`PulseHaptics/PulseHaptics.toc`:** insert `Core/Arbiter.lua` on the line after `Core/Registry.lua` (`:55`). It reads `Pulse.Triggers` and `Registry.EPISODES` at load.

**Why a new core file instead of the "World/Interaction/Engine" split in the brief [Decision].**
- The owner rules are shared by `Inventory.lua`, `World.lua` and `Interaction.lua`. A core service loaded before all modules gives them one source of truth, and replaces the second copy of "is a vendor open" state (`Interaction.lua:108` vs `Inventory.lua:43-86`).
- **`Core/Engine.lua` needs no change.** Replacement on a bus comes from `PlayMode`'s existing per-layer token (`Engine.lua:354-355`, `:484`). The only difference is the layer name `FireIfEnabled` passes.

**`PulseHaptics/Core/Init.lua` changes** (final code, verified):

1. **New `Pulse:GatesOpen(triggerID, trigger)`**, inserted before `FireIfEnabled` (`:52`). It replaces the three copies of the category-master check (`:66-69`, `:110-113`, `:152-155`). `HoldIfEnabled` and `HoldRolesIfEnabled` call it instead, so continuous textures obey the same gates.

```lua
function Pulse:GatesOpen(triggerID, trigger)
	local registry = self.Registry
	trigger = trigger or registry:GetTrigger(triggerID)
	if not trigger then
		return false
	end
	local catMaster = registry.ALERT_CATEGORY_MASTER and registry.ALERT_CATEGORY_MASTER[trigger.category]
	if catMaster and catMaster ~= triggerID and not self.Database:GetCue(catMaster) then
		return false
	end
	local gate = registry.CUE_GATE and registry.CUE_GATE[triggerID] -- nil until P2.1
	if gate and gate ~= triggerID and not self.Database:GetCue(gate) then
		return false
	end
	return true
end
```

2. **`Pulse:FireIfEnabled` (`:54-90`)** changes in three ways:
   - It returns `true` when it played and `false` otherwise.
   - It checks the throttle **before** the bus, but stamps it **after** (invariant I7).
   - It plays on the bus layer when the trigger has a `bus`.

```lua
	-- (gates checked above via self:GatesOpen)
	local now
	if trigger.throttle and trigger.throttle > 0 then
		now = GetTime()
		local last = lastFireTime[triggerID]
		if last and (now - last) < trigger.throttle then
			return false
		end
	end

	local layerName = triggerID
	if trigger.bus then
		local ok, layer = self.Arbiter:ClaimBus(trigger.bus, trigger.busPriority, trigger.busWindow, triggerID)
		if not ok then
			return false
		end
		layerName = layer
	end

	if now then
		lastFireTime[triggerID] = now
	end
	-- ... scale / modeID unchanged ...
	self.Engine:PlayMode(layerName, modeID, scale, intensityOverride)
	return true
```

**Compatibility of the return value.** [Fact] PulseDebug post-hooks `FireIfEnabled` with `hooksecurefunc` (`PulseDebug/UI.lua:456-457`), and a post-hook doesn't change the original's return values. The `Pulse.Fire` alias (`Init.lua:190`) inherits the new behaviour. Existing callers ignore the result.

**Loaders the tests need.** Add `"Core/Arbiter.lua",` after `"Core/Registry.lua",` in two lists:
- `PulseChecklist/tests/harness.lua:558`
- `PulseChecklist/tests/cue-audit.lua:119` (cue-audit scans those files for cue-id strings)

[Fact] Without the harness entry, harness fails with `World.lua: attempt to index upvalue 'Arbiter' (a nil value)`.

### P1.1 Vendor purchase guard (`Modules/Inventory.lua:146`)

```lua
			if free < lastFreeSlots then
				-- Owner rule (Registry.EPISODES): a purchase speaks through merchantBuy when
				-- that cue is live, a loot window through its episode speaker. Otherwise
				-- this tick is the only feedback for the item, so it plays.
				if not Pulse.Arbiter:VendorOwnsIntake() and not Pulse.Arbiter:LootIntake() then
					Pulse:FireIfEnabled("bagItemAdded")
				end
```

- **Vendor state comes from one place: `Arbiter:IsMerchantOpen()`.** It checks the interaction manager first, for types `Merchant` (5) and `Vendor` (12) via `Enum.PlayerInteractionType`, with the literals as fallback. `MerchantFrame:IsShown()` is the second check. [Fact] Merchant and bag replacement addons hide `MerchantFrame`, but the interaction doesn't end. This is also the existing function's fallback (`Inventory.lua:62-83`).
- **The check is state-based, so order doesn't matter** (invariant I2). A bag settle that arrives before `PLAYER_MONEY` yields just the same.
- **Default users still feel purchases** (invariant I1). With `merchantBuy` off, `VendorOwnsIntake()` is false and `bagItemAdded` plays.
- **Sell side:** the unconditional guard at `Inventory.lua:148-151` stays. It is a semantic exclusion.
- **Optional hygiene:** add `e.Vendor` next to `e.Merchant` in `isInteractingWithStorageOrMerchant` (`Inventory.lua:65-67`).

### P1.2 Loot episode with a leading-edge claim

**Lifecycle.**

```
LOOT_READY(autoloot) ──► Arbiter:LootOpened()  scan slots · choose speaker · harvestComplete yields to lootOpened
LOOT_OPENED(autoLoot) ─► Arbiter:LootOpened()  rescan (autoloot may have emptied slots)
LOOT_SLOT_CLEARED(n) ──► autoloot: first intake speaks once at the BEST quality
                         manual:   one cue per click at THAT slot's quality (coin slot -> lootGold)
ITEM_PUSH / own CHAT_MSG_LOOT / CHAT_MSG_MONEY / bag gain ──► Arbiter:LootIntake(): speak once or stand down
LOOT_CLOSED ───────────► episode closes; LOOT_TAIL (0.30 s, measured in S3) still stands down
PLAYER_ENTERING_WORLD ─► reset.   Stale guard: an episode open > 60 s closes itself.
```

**Speaker selection** happens once per scan. The speaker is the first live cue in `EPISODES.loot.intake` (`itemObtained` → `lootReceived` → `bagItemAdded`) if the window holds items. If it holds only coins, the speaker is `lootGold`, when that cue is live. Otherwise there's no speaker and nothing is suppressed.

**Tier.** The speaker is played with an `intensityOverride` taken from a static table, `QUALITY_GAIN` = Poor 0.70, Common 0.85, Uncommon 1.00, Rare 1.15, Epic 1.30, Legendary/Artifact 1.45, Heirloom 1.30. A quest item gets at least 1.15.
- [Fact] `Enum.ItemQuality` has no quest tier (`<forever-src>/…/ItemQualitiesDocumentation.lua:6-20`).
- [Fact] `isQuestItem` is `GetLootSlotInfo`'s 7th return (`<forever-src>/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/LootFrame.lua:236,485`).
- [Decision] Separate tier cues and modes are feature work (Phase 4). Phase 1 only removes double firing.

**Edge cases handled** (each has a test in P1.5):

| Case | Behaviour |
|:--|:--|
| Autoloot, several items | One cue, at the best quality's gain. |
| Manual looting | One cue per deliberate click. [Fact] `LOOT_OPENED` carries `autoLoot` (`<forever-src>/…/LootDocumentation.lua:220-226`). |
| Client never sends `LOOT_SLOT_CLEARED` | In manual mode, suppression only starts after the first `LOOT_SLOT_CLEARED` is seen, so looting is never silent. |
| Group-loot roll items | A `locked` slot is never announced. A secret `locked` value is treated as locked. |
| Another player's loot chat | `lootReceived` is filtered to own loot using `CHAT_MSG_LOOT`'s 12th field, the looter GUID (`<forever-src>/…/ChatInfoDocumentation.lua:1817-1834`). This also fixes the raid-wide buzzing in the *Raiding* profile (review §8.5). |
| Bag settle after close | Stands down for `LOOT_TAIL`, then bag cues behave normally again. |

**`Modules/World.lua`.**
- Replace the four `WatchTrigger` lines (`:14-17`) with `self:_WatchLoot()` and `self:_WatchDurability()`.
- Append both functions (loot code below; durability in P1.3).
- The loot frame registers `LOOT_READY`, `LOOT_OPENED`, `LOOT_SLOT_CLEARED`, `LOOT_CLOSED` and `PLAYER_ENTERING_WORLD` whenever any of these cues is enabled: `lootOpened`, `harvestComplete`, `itemObtained`, `lootReceived`, `lootGold`, `bagItemAdded`.
- `ITEM_PUSH`, `CHAT_MSG_LOOT` and `CHAT_MSG_MONEY` are registered only when their own cue is enabled.

```lua
	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "LOOT_READY" then
			Arbiter:LootOpened((...))
			if not Arbiter:IsLive("lootOpened") then
				Pulse:FireIfEnabled("harvestComplete")
			end
		elseif event == "LOOT_OPENED" then
			Arbiter:LootOpened((...))
		elseif event == "LOOT_SLOT_CLEARED" then
			Arbiter:LootSlotCleared((...))
		elseif event == "LOOT_CLOSED" then
			Arbiter:LootClosed()
		elseif event == "ITEM_PUSH" then
			if not Arbiter:VendorOwnsIntake() and not Arbiter:LootIntake() then
				Pulse:FireIfEnabled("itemObtained")
			end
		elseif event == "CHAT_MSG_LOOT" then
			local guid = select(12, ...)
			if isOwnLoot(guid) and not Arbiter:LootIntake() then
				Pulse:FireIfEnabled("lootReceived")
			end
		elseif event == "CHAT_MSG_MONEY" then
			if not Arbiter:LootIntake() then
				Pulse:FireIfEnabled("lootGold")
			end
		elseif event == "PLAYER_ENTERING_WORLD" then
			playerGUID = nil
			Arbiter:LootReset()
		end
	end)
```

`isOwnLoot(guid)` returns false for a secret or non-string GUID, and caches `UnitGUID("player")` (reset on `PLAYER_ENTERING_WORLD`).

**`Modules/AlertWorld.lua:14`:** add `lootReceived = true` to `CUSTOM`, so the generic category watcher no longer also registers it. The trigger keeps `category = "ALERT_WORLD"`; only the watcher moves.

**The `intake` bus (data).** Six cues go on it:
- `itemObtained`, `lootReceived` and `lootGold` at priority 2
- `lootOpened`, `harvestComplete` and `bagItemAdded` at priority 1

Outside any episode (mail attachments, quest rewards), `itemObtained` and `bagItemAdded` then merge in either order. That's test I1/I2, and needs no new code. The loot-window opening tick and the first intake chime also merge into one gesture when autoloot fires them tens of milliseconds apart.

**Interaction.lua isn't involved in loot.** The brief named it, but loot lives entirely in `World.lua` plus `Arbiter.lua`.

### P1.3 Repair recognition and the durability worsening edge (`Modules/Interaction.lua:176-194`, `Modules/World.lua:17`)

**What HEAD does wrong.** [Fact] `wasRepair` is set on any `UPDATE_INVENTORY_DURABILITY` while a vendor is open, and cleared only by the next `PLAYER_MONEY` (`Interaction.lua:176-194`). [Inference] That lets it swallow the next real transaction in three cases:
- a guild-funded repair. [Fact] `RepairAllItems(true)` is on the Forever vanilla merchant frame (`<forever-src>/Interface/AddOns/Blizzard_UIPanels_Game/Vanilla/MerchantFrame.xml:317-318`), and it doesn't move personal money.
- a durability update from equipping gear at the vendor
- money arriving before the durability update

**The replacement.** Every flag has an expiry; nothing latches.

| State (scalars) | Set when | Cleared / expires |
|:--|:--|:--|
| `knownRepairCost` | `GetRepairAllCost()` sampled at vendor open and after every durability update | — |
| `armedUntil`, `armedGuild`, `armedCost` | Post-hook `hooksecurefunc("RepairAllItems", onRepairAllItems)` while a vendor is open and cost > 0 | Confirmation, vendor close, or `REPAIR_WINDOW` (2.0 s) |
| `debitCost`, `debitUntil` | On confirmation: the personal repair cost, or `-1` (unknown amount) for a cursor repair (`InRepairMode()`) | The matching `PLAYER_MONEY`, or `DEBIT_WINDOW` (1.0 s) |
| `repairFiredAt` | `merchantRepair` played | Dedupes the double confirmation (money + durability) within 1.0 s |

**How each event is handled.**
- **`UPDATE_INVENTORY_DURABILITY` while a vendor is open:**
  - If armed, or `InRepairMode()` is true: fire `merchantRepair` once. Then set the debit, except for a guild repair, which never debits personal money.
  - Otherwise, e.g. equipping gear: nothing fires and nothing latches.
- **`PLAYER_MONEY`:** check the cases in this order.
  1. A negative delta within the debit window that matches the debit (or any negative delta when the debit is unknown) is the repair payment. Absorb it silently.
  2. A negative delta within the armed window, not a guild repair, equal to `armedCost`: money arrived first, so this *is* the repair. Fire it once.
  3. Otherwise, `merchantSell` or `merchantBuy` as before.

```lua
	elseif event == "UPDATE_INVENTORY_DURABILITY" then
		if inMerchant then
			local now = GetTime()
			local armed = now < armedUntil
			local cursor = (type(InRepairMode) == "function") and InRepairMode() and true or false
			if armed or cursor then
				fireRepairOnce(now)
				if armed and not armedGuild then
					debitCost, debitUntil = armedCost, now + DEBIT_WINDOW
				elseif cursor then
					debitCost, debitUntil = -1, now + DEBIT_WINDOW
				end
				armedUntil = 0
			end
			knownRepairCost = readRepairCost()
		end
	elseif event == "PLAYER_MONEY" then
		if inMerchant then
			-- (current / delta read and secret-guarded exactly as before)
			local now = GetTime()
			if delta < 0 and now < debitUntil and (debitCost < 0 or -delta == debitCost) then
				debitCost, debitUntil = 0, 0 -- the repair's own payment, already felt
			elseif delta < 0 and now < armedUntil and not armedGuild and -delta == armedCost then
				fireRepairOnce(now) -- money beat the durability update
				armedUntil = 0
			elseif delta > 0 then
				Pulse:FireIfEnabled("merchantSell")
			elseif delta < 0 then
				Pulse:FireIfEnabled("merchantBuy")
			end
		end
```

**Supporting changes.**
- `readRepairCost()` guards with `issecretvalue`, `type`, and `>= 0`.
- `openMerchant()` replaces the two duplicated open blocks (`:119-123` and `:168-172`); `resetRepair()` replaces every `wasRepair = false`.
- `M:OnEnable` installs the hook once: `if type(RepairAllItems) == "function" then hooksecurefunc("RepairAllItems", onRepairAllItems) end`.
- `_DebugInteraction` (`:276-288`) reports `repairArmed`, `repairDebitPending` and `pendingClose` instead of `wasRepair`. [Fact] Neither companion addon reads `wasRepair` (grep over `PulseDebug/` and `PulseChecklist/`).

**Durability fires only when gear gets worse** (`Modules/World.lua`, `_WatchDurability`).
- It reads the worst `GetInventoryAlertStatus(index)` over the Blizzard alert slots: `#INVENTORY_ALERT_STATUS_SLOTS` when that table exists, else 11 (`<forever-src>/Interface/AddOns/Blizzard_DurabilityFrame/DurabilityFrame.lua:1-12`, `:61-87`).
- It fires only on `UPDATE_INVENTORY_ALERTS` when that worst status rises (0 none → 1 yellow → 2 red). Red gets `intensityOverride` 1.25.
- The first reading after login or zoning is a silent baseline.
- A repair (falling status) is silent, so the review's hotspot 3 disappears without any cross-module flag.

[Decision] A player logging in with already-red gear isn't alerted, because the baseline is silent. If that's wanted, fire once at `PLAYER_ENTERING_WORLD` when the worst status is 2. That's a one-line change listed under open questions.

### P1.4 Window priority bus (`Core/Registry.lua`, `Core/Init.lua`, `Modules/Interaction.lua`)

**Bus membership** (data: two fields on each trigger entry; `busWindow` defaults to 0.15 s in `Arbiter.lua`):

| Priority | Cues on `bus = "window"` | Why |
|:--:|:--|:--|
| **3** | `merchantShow` `bankOpened` `mailShow` `trainerShow` `taxiOpened` `tradeSkillShow` `questDetail` `tradeRequest` `guildBankOpened` `auctionHouseShow` `spiritHealerShow` `stableShow` `binderShow` | A specific window arriving (every `TYPE_CUE` target, `Interaction.lua:56-71`) |
| **2** | `gossipShow` `interactionWindow` `bankClosed` | Generic or conversational arrivals; the specific close wins over the generic one |
| **1** | `interactionWindowClosed` `panelOpen` `panelClose` | Generic closes; ControllerUI's 20 Hz panel poll lands 0–50 ms after the event (`Modules/ControllerUI.lua:146-163`, `:415-426`) |

Example entry (`Core/Registry.lua:1837`):

```lua
	{
		id = "merchantShow",
		bus = "window",
		busPriority = 3,
		category = "ALERT_WORLD",
		-- ... unchanged ...
	},
```

**One-frame deferred close (`Modules/Interaction.lua`).**
- `onHide` (`:145-161`) and the `BANKFRAME_CLOSED`/`GUILDBANKFRAME_CLOSED` branch (`:209-211`) no longer fire directly. They call `deferClose(isBank)`.
- Every show path (`onShow`, `MERCHANT_SHOW`, `BANKFRAME_OPENED`/`GUILDBANKFRAME_OPENED`) increments `showSerial`.
- `flushDeferredClose` is a named file-scope function, so there's no closure per close. It drops the close if a `SHOW` arrived in the meantime.

```lua
local showSerial = 0
local pendingCloseSerial = -1
local pendingBankClose = false

local function flushDeferredClose()
	if pendingCloseSerial < 0 then
		return
	end
	local transition = (showSerial ~= pendingCloseSerial)
	local bank = pendingBankClose
	pendingCloseSerial, pendingBankClose = -1, false
	if transition then
		return -- a window opened before this frame ended: the close was part of a chain
	end
	if bank then
		Pulse:FireIfEnabled("bankClosed")
	end
	Pulse:FireIfEnabled(CLOSED_CUE)
end

local function deferClose(isBank)
	if pendingCloseSerial < 0 then
		pendingCloseSerial = showSerial
		C_Timer.After(0, flushDeferredClose) -- static function: no closure per close
	end
	if isBank then
		pendingBankClose = true
	end
end
```

**Why both mechanisms.**
- The deferral removes the close when `HIDE` and `SHOW` share a frame. S5 measures whether they do.
- The bus handles whatever arrives within 150 ms: the specific cue wins, lower priority is dropped, and higher priority replaces.
- Closing a bank now plays `bankClosed` once. `interactionWindowClosed` yields to it on the bus. [Fact] At HEAD both fire from one hide (`Interaction.lua:154-160`); both are on in *Questing*.

**The brief's "Core/Engine.lua" item [Decision]: no Engine change.** Replacement comes from `PlayMode`'s token.
- **Side effect:** layer names `bus:window` and `bus:intake` replace per-cue names for bus members in PulseDebug's layer lists (`PulseDebug/UI.lua:185-218`, `PulseDebug/Debug.lua:136-164`).
- **Mitigation:** the `/pulse debug` fire log still prints the cue id (`Init.lua` debug print, unchanged).

### P1.5 Tests and tooling

**New suite `PulseChecklist/tests/arbitration-test.lua`**, registered in `scripts/test.sh` `SUITES` (`:20-28`) as `"arbitration-test PulseHaptics"`.
- It loads the real `Core/Init.lua`, `Core/Registry.lua`, `Core/Arbiter.lua`, `Modules/Inventory.lua`, `Modules/World.lua` and `Modules/Interaction.lua`.
- It fakes only the Database (a cue table, with gates seeded on like the real one) and the Engine (records `PlayMode` layer names).
- It drives events through stubbed frames, and simulates `hooksecurefunc` on globals.
- 46 checks; the list is in Appendix B.

[Fact] The mutation checks from §0 apply here: 5 failures with HEAD's `Interaction.lua` (R2, R3, R4 ×2, B1) and 2 with HEAD's `Inventory.lua` (V2, L2). The intake bus alone already absorbs the loot duplicates that HEAD's `Inventory.lua` would produce. The owner rule is what catches the purchase and the Default-autoloot cases.

**Other tooling.**
- **`.luacheckrc`:** the globals from P0.2.
- **`harness.lua` and `cue-audit.lua`:** the loader lines from P1.0.

**In-game acceptance for Phase 1** (Default and *Questing* profiles, Xbox-class pad):

| Scenario | Default must feel | Questing must feel |
|:--|:--|:--|
| Buy one item into an empty slot | 1 tick (`bagItemAdded`) | 1 tap (`merchantBuy`); no tick |
| Repair all (personal), then buy | 1 thud, then 1 tap | same |
| Repair all (guild), then sell | 1 thud (`merchantRepair` is on in Default), then nothing (`merchantSell` is off in Default) | 1 thud, then 1 sell tick |
| Autoloot a corpse (2 items) | 1 tick | 1 chime; nothing else |
| Manual loot (coin + 2 items) | 1 tick per item | 1 coin tick + 1 chime per item |
| Mailbox → click a vendor | `panelOpen` only | 1 vendor tap; no close tick |
| Close a bank | `panelClose` | 1 thud |
| Gear goes yellow, then repair | 1 tap on yellow; nothing on repair | same |

---

## 4. Phase 2 — Panel ergonomics and page switches

### P2.1 Page switches: non-destructive group gates

**Data (`Core/Registry.lua`):**
- **Category.** Add `"PAGE_GATE"` to `CATEGORY_ORDER` (`:29-46`) and `PAGE_GATE = "Page switches"` to `CATEGORY_LABELS` (`:47-82`).
- **Ten pure-gate triggers**, appended before `Pulse.Triggers` closes (`:2787`): `gateCombat`, `gateCasting`, `gateMovement`, `gateCharacter`, `gateControl`, `gateTarget`, `gateWorld`, `gateSocial`, `gateInterface`, `gateInteract`. Each has `category = "PAGE_GATE"`, `gate = true`, `default = true`, no `mode`, a label, and a `desc`.
- **`Registry.PAGE_GATES`**, which maps page id to gate id:
  - **CONTROLLER has no gate on purpose.** `padDisconnected` is the safety stop and must never sit behind a switch.
  - **CONTROLLER_UI reuses `controllerUIMaster`** rather than adding a second switch.
- **`Registry.CUE_GATE`**, cue id → gate id, resolved once from `PAGE_LAYOUT`. It skips cues whose category master *is* the page gate.
  - [Fact] In the prototype: 166 of 188 placed cues are gated. The 3 CONTROLLER cues and the CONTROLLER_UI page (covered by its existing master) are not.
- **`Registry:GetPageGate(pageID)`**, a new accessor.
- **The orphan check** (`:3266`) also exempts `trigger.gate`.

**Deviation from the review's "separate gate key", on purpose [Decision].** Gate membership follows the page a cue is shown on. The player's mental model of a switch is exactly the cues listed on its page, so moving a cue between pages moves it between gates. That makes `PAGE_LAYOUT` partly behavioural. The comment block at `Registry.lua:2789-2806` must say so.

**Runtime (`Core/Init.lua`).**
- `GatesOpen` (P1.0) already reads `CUE_GATE`, so `FireIfEnabled`, `HoldIfEnabled` and `HoldRolesIfEnabled` all honour page switches.
- **New `Pulse:IsCueActive(id)`** returns `GetCue(id) and GatesOpen(id)`. Module `sync` functions use it, so a page that's switched off costs nothing, not just plays nothing.
- **`BindFrame` (`:377-383`)** also subscribes `sync` to each cue's page gate and category master, once each (one `seen` table per bind, at bind time only).
- **`WatchTrigger`'s `sync` (`:396`)** uses `IsCueActive`.

**Module migration.** [Fact] There are 96 `Database:GetCue(` call sites in `Modules/`, `Core/Init.lua` and `Core/CastActivity.lua`. [Decision] Change only the calls inside `sync` functions, in this order:
1. Modules that poll per frame, where a gated page still costs CPU: `Movement.lua`, `Locomotion.lua`, `Environment.lua`, `PlayerState.lua`, `ControllerUI.lua` (20 Hz poll), `Combat.lua` (swing estimator `OnUpdate`), `Flight.lua`, `Health.lua`.
2. Event-only modules, as they are next edited.

Calls on the fire path need no change, because `FireIfEnabled` and `Hold*` already check the gates.

**Persistence (`Core/Database.lua`).** Found by the prototype.

| Change | Where | Why |
|:--|:--|:--|
| Gates always seed **ON** | `_SeedProfileTriggerDefaults` (`:1402-1414`): `if trigger.gate then default = true end`, before the `__exclusive` fallback | [Fact] All 12 curated profiles are `__exclusive` (`Database.lua:197`…`:1033`). An unlisted trigger seeds **off**, which would silently mute every page on the first load. |
| "Disable all cues" skips gates | `SetAllCues` loop (`:2884-2887`) | The button means cues; switches stay where the player put them. |
| Curated-profile comparisons skip gates | `_MigrateCuratedProfilesOptionB` loops "A" (`:2020`) and "B" (`:2045`) | [Fact] Without this, the harness Option-B checks fail (52 counted vs 42 expected; 63 vs 53). An untouched curated profile would look customised and miss its migration. Loop "C" (`:2069`) already matches, because `gate.default == true`. |
| Gate flips re-sync after combat | `SetCue` (`:2857-2868`): if `trigger.gate` and `InCombatLockdown()`, set `pendingProfileNotify = true` and return without notifying | The gate itself takes effect immediately in `GatesOpen`. Only the mass event re-registration waits, using the same flush as profile switches (`:1188-1210`, `:2477-2491`). |

`DB_VERSION` stays 11. [Fact] `ApplyDefaults` seeds any missing trigger key on every load (`:1344-1360`), so no migration step is needed.

**Panel greying.** `Spec.lua`'s `cueGate` (`:95-103`) becomes `return masterOn() and Pulse:GatesOpen(trigger.id, trigger)`. One rule is shared with the runtime, so the panel can never grey a cue the engine would play.

### P2.2 Collapsible sections, fold state saved account-wide

**Storage.** Add to `GLOBAL_DEFAULTS` (`Core/Database.lua:29-43`):
- `simpleView = false`
- `collapsedSections = {}`

Both are panel presentation, not playstyle. A profile switch driven by a spec change (`Database.lua:2286-2310`) must never re-fold the window.

New API:
- `Database:IsSectionCollapsed(key)`
- `Database:SetSectionCollapsed(key, bool)`: sanitizes to a boolean, stores `true` or `nil`, and notifies `"collapsedSections"`. [Fact] The panel already subscribes to every `GLOBAL_DEFAULTS` key (`UI/Panel/Panel.lua:86-93`).

Keys are the addon-authored strings `"<PAGEID>/<Section label>"`, so RULE D is satisfied.

**`UI/Panel/Rows.lua`, new `Rows.CreateSectionHeader`** (registered as `section` in `builders`, `:729`):
- It's a `Button` row. A plus/minus texture (`Interface\Buttons\UI-PlusButton-Up` / `UI-MinusButton-Up`) sits next to the title and an "N of M on" badge.
- [Fact] Forever's own UI uses both textures (`<forever-src>` hits in the Blizzard UI).
- `Theme.MarkIgnored(row)` is kept, so no gamepad navigation is added.

**`UI/Panel/Content.lua`.** `rowVisible` gets a third reason to hide a row: its section is folded. It yields to search.

```lua
local function rowVisible(row, filter)
    local spec = row.spec
    if spec and spec.visibleWhen and not spec.visibleWhen() then return false end
    if not filter then
        return not (spec and spec.sectionKey and not row.isSectionHeader and sectionFolded(spec.sectionKey))
    end
    if row.isHeader then return false end   -- decided by its section, below
    return row.searchText and string.find(row.searchText, filter, 1, true) ~= nil
end
```

In `LayoutRows`:
1. A folded section keeps its heading, because the heading is how you unfold it: `headerHasContent` starts as true for a folded section header when no filter is active.
2. After setting the child height, clamp the scroll offset using the height just computed. `GetVerticalScrollRange` only catches up on the scroll frame's next layout pass.

```lua
    local childHeight = math.max(y + Theme.LIST_VERTICAL_PAD, 1)
    self.Child:SetHeight(childHeight)
    local viewHeight = self.Scroll:GetHeight() or 0
    local maxScroll = math.max(0, childHeight - viewHeight)
    if (self.Scroll:GetVerticalScroll() or 0) > maxScroll then
        self.Scroll:SetVerticalScroll(maxScroll)
    end
```

**`UI/Panel/Spec.lua`.** `sectionHeader(page, section)` builds the spec. Its `onToggle` first calls `Panel.Popup.CloseList()` (`UI/Panel/Popup.lua:110`), so no dropdown list stays anchored to a row that's about to hide. Every cue row and tunable row carries `sectionKey`.

### P2.3 One-line cue rows

**Size of the change.** [Fact] Computed from the registry with the detail controls and Play buttons shown (both default on): the 12 cue pages currently build **787 rows**. With one line per cue (bespoke tunables stay as child rows) they build **239**, which is **−70%**. By page, the reduction is 60–72%, for example COMBAT 113 → 35 and WORLD 108 → 31.

**`Rows.CreateCueRow`** (registered as `cue`):
- **Layout:** one 26 px row with checkbox, label, an inline `MinimalSliderWithSteppersTemplate` (intensity), an inline `WowStyle2DropdownTemplate` (mode), and a small Play button.
- **Same closures as before.** Its get/set are the **same closures** `cueCheckbox`, `cueIntensitySlider`, `cueModeDropdown` and `cueTestButton` already build (`Spec.lua:187-360`). Saved values, ranges and tooltips don't move.
- **Dropdown safety:** no `SetupMenu`. `Popup.OpenList` supplies the behaviour, exactly as `Rows.CreateDropdown` does. This avoids the protected-binding path described at `UI/Panel/Popup.lua:12-22`.
- **Detail toggles:** the inline slider and dropdown obey `showAdvancedCueControls` (and simple view, P2.4). The Play button obeys `showCueTestButtons`.
- **Enabling:** the inline controls follow the gates **and** the cue's own switch. The prototype caught a gap here: `Content:RefreshRows` only re-applies `SetRowEnabled` when the gate result changes (`Content.lua:256-280`). So `RefreshValue` also re-evaluates `enabledWhen() and check.get()` for the inline controls.

**`UI/Panel/Theme.lua`:** add these after `BUTTON_LEFT` (`:99`). They are left-anchored offsets inside a row of about 605 px at the stock 920 px window. [Unverified] Check them in game at 1280×800 and UI scale 0.64–1.0.

```lua
Theme.CUE_CHECK_LEFT = 4
Theme.CUE_LABEL_LEFT = 38
Theme.CUE_LABEL_WIDTH = 190
Theme.CUE_SLIDER_LEFT = 232
Theme.CUE_SLIDER_WIDTH = 150
Theme.CUE_DROPDOWN_LEFT = 392
Theme.CUE_DROPDOWN_WIDTH = 150
Theme.CUE_PLAY_LEFT = 550
Theme.CUE_PLAY_WIDTH = 28
```

**`UI/Panel/Spec.lua`:**
- `cueBlock` (`:596-621`) is replaced by `cueBlockCompact`: one `cueRow` spec, then the tunable rows.
- `BuildCuePage` (`:623-647`) emits a `sectionHeader` per section and compact rows under it.
- The Continuous textures page and the Crafting page keep their existing rows. They are tuning surfaces, not cue lists.

### P2.4 Simple view

- **Toggle:** a "Simple view" checkbox on the root page, directly above "Show per-cue detail controls" (`Spec.lua:461`). It is backed by the new global `simpleView`.
- **`advancedShown()` (`Spec.lua:113-115`)** becomes `showAdvancedCueControls and not simpleView`. The stored choice is never rewritten, so leaving simple view restores exactly what was there.
- **New "Page switches" page** (`id = "switches"`), inserted right after the root page in `Spec.BuildPages` (`:1871`):
  - It holds one `isMaster` checkbox per `PAGE_GATES` entry, labelled with the page name.
  - Its badge reads "N of M cues on" / "(page off)" via a new optional `spec.badge(value)` hook in `Rows.CreateCheckbox` (`:290-296`).
- **Sidebar filter.** Pages marked `simple = true` stay visible in simple view: root, switches, profiles, guide.
  - New `SidebarMixin:ApplyFilter(keep)` (`UI/Panel/Sidebar.lua`) re-anchors the buttons `CreateButtons` built once, and creates nothing.
  - New `Panel.ApplySimpleView()` (`UI/Panel/Panel.lua`) applies the filter, moves to `switches` if the current page was hidden, and marks the panel dirty. `Panel.EnsureBuilt` calls it after `Sidebar:Select(pages[1])` (`:417`), and so does the toggle's setter.
- **Presentation only:** simple view writes no cue, gate or profile value.

### P2.5 Tests

**New suite `PulseChecklist/tests/phase2-test.lua`**, registered in `scripts/test.sh` `SUITES` as `"phase2-test PulseHaptics"`.
- It `dofile`s `harness.lua`, as `cue-audit.lua` does, so it runs against the real Database, Registry, Init, Spec, Content, Rows, Sidebar and Panel.
- 49 checks; the list is in Appendix B.

**`harness.lua` count adjustments.** The two "Option B … curated cues" counts (`:1853`, `:1866`) must exclude `gate` triggers, because they count every enabled key.

**In-game acceptance for Phase 2** (visual checks the harness can't make):
- **Row fit:** at 1280×800 and at UI scale 0.64, the one-line rows don't truncate the slider value or the dropdown text. Adjust the `Theme.CUE_*` constants if they do.
- **Fold behaviour:**
  - Folding a section at the bottom of a long page leaves no blank space and no scroll jump beyond the end.
  - An open dropdown closes when its section folds.
- **Page switches:**
  - With WORLD's switch off in combat, WORLD cues stop immediately.
  - The WORLD modules unregister their events when combat ends (check with `/pulse debug` or `/pdebug`).
  - Turning the switch back on restores every cue exactly.
- **Simple view:**
  - It shows Pulse, Page switches, Profiles and Guide.
  - Turning it off restores the full sidebar and the previous detail-control setting.

---

## 5. Risk register and compatibility

| Risk | Likelihood | Mitigation |
|:--|:--|:--|
| A Forever event never arrives or arrives late (`LOOT_SLOT_CLEARED`, `ITEM_PUSH` for loot, same-frame `HIDE`/`SHOW`) | Medium | Every path falls back to "play normally": the manual-loot guard, no speaker means no suppression, and the bus drops only within 150 ms. S1–S5 confirm. |
| `GetRepairAllCost()` already reads 0 inside the post-hook | Medium | The hook prefers `knownRepairCost`, sampled at vendor open and after each durability update. Worst case the repair is recognised by the durability path alone, and the payment is felt as `merchantBuy` once. |
| New gate triggers seeded OFF in curated profiles | Found and fixed | The seeding exemption, plus the P2.5 check "every profile seeds every switch ON". |
| PulseDebug shows `bus:*` layer names | Certain | Documented. The fire log still names cues. Optional follow-up: PulseDebug maps the bus layer back to the last cue that claimed it. |
| PulseChecklist groups by category and sees a new `PAGE_GATE` category | Certain | [Fact] `checklist-test` passes on the prototype. The checklist shows the switches as their own group. |
| The one-line row is too cramped on small screens | Medium | The constants are isolated in `Theme`. Fallback: move the dropdown to a second line when the row width is below ~560 px (row `MeasureHeight`, a `Content.lua` path that already exists). |
| Deferral costs one frame on every close cue | Certain, harmless | About 7–33 ms on a UI close tick. Imperceptible. |

**Unchanged:** SavedVariables schema version, every existing cue id and category, every saved value, the Engine's synthesis path (except the P0.1 fix), and the TOC Interface line.

---

## 6. Open questions for the owner

1. **Red gear at login.** Alert once at login when gear is already red (worst status 2)? The plan says no, because the baseline is silent (P1.3).
2. **Loot quality gains.** The `QUALITY_GAIN` values (0.70 → 1.45) are starting values. Tune them on hardware.
3. **Where `lootReceived` fires.** It becomes own-loot-only everywhere, not just inside loot windows. The plan says yes; that's the review's §8.5 fix.
4. **Gate count.** Should *Controller Interactions* (GAMEPAD_INTERACT) share a switch with *Controller UI*? The plan gives it its own switch.

---

## Appendix A — `PulseHaptics/Core/Arbiter.lua` (reference implementation, verified)

```lua
-- Pulse — Core/Arbiter.lua
--
-- Cross-module cue arbitration: which cue speaks when one game action fires several.
--
-- Three mechanisms, all driven by data in Core/Registry.lua (Registry.EPISODES and the
-- per-trigger `bus` / `busPriority` fields), and none of them allocating per event:
--
--   1. Liveness. Is a cue actually audible right now — master switch, its own switch, its
--      gates, and a non-zero intensity? The owner rule below is only ever asked about a
--      cue that is live: a disabled owner must never silence the cue standing in for it.
--   2. Episodes. A vendor visit and a loot window. A yielder steps aside only while its
--      episode is open AND one of that episode's owners is live.
--   3. Buses. Cue families that chain inside a frame (one window closing as another opens)
--      share one engine layer. A lower-priority cue arriving inside the bus window after a
--      higher one is dropped; a higher one arriving after a lower one replaces it, because
--      Engine:PlayMode on the same layer name bumps that layer's token (Engine.lua:354-355).
--
-- Reads game state only. Calls no protected API, hooks nothing, writes no SavedVariables.

local ADDON_NAME, Pulse = ...

local Arbiter = {}
Pulse.Arbiter = Arbiter

-- ── Liveness ──────────────────────────────────────────────────────────────────

function Arbiter:IsLive(cueID)
	local db = Pulse.Database
	if not db:Get("masterEnabled") or not db:GetCue(cueID) then
		return false
	end
	if not Pulse:GatesOpen(cueID) then
		return false
	end
	local intensity = db:GetTriggerSetting(cueID, "intensity", 1.0)
	return type(intensity) == "number" and intensity > 0
end

local function anyLive(list)
	if not list then
		return false
	end
	for i = 1, #list do
		if Arbiter:IsLive(list[i]) then
			return true
		end
	end
	return false
end

local function firstLive(list)
	if not list then
		return false
	end
	for i = 1, #list do
		if Arbiter:IsLive(list[i]) then
			return list[i]
		end
	end
	return false
end

-- ── Vendor episode ────────────────────────────────────────────────────────────

-- Read through Enum where the client defines it, with the confirmed literal as fallback —
-- the same pattern as Modules/Interaction.lua:36-42.
local function interactionType(name, literal)
	local value = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType[name]
	if type(value) == "number" then
		return value
	end
	return literal
end
local PIM_MERCHANT = interactionType("Merchant", 5)
local PIM_VENDOR = interactionType("Vendor", 12)

local function interacting(kind)
	local pim = C_PlayerInteractionManager
	if not (pim and type(pim.IsInteractingWithNpcOfType) == "function") then
		return false
	end
	local value = pim.IsInteractingWithNpcOfType(kind)
	if issecretvalue(value) then
		return false
	end
	return value and true or false
end

-- The single source of truth for "a vendor is open". Interaction-manager state first:
-- bag and merchant replacement addons hide MerchantFrame, the interaction does not end.
function Arbiter:IsMerchantOpen()
	if interacting(PIM_MERCHANT) or interacting(PIM_VENDOR) then
		return true
	end
	return (MerchantFrame and MerchantFrame:IsShown()) and true or false
end

-- True while a vendor is open and something that speaks for a purchase is live.
function Arbiter:VendorOwnsIntake()
	local episode = Pulse.Registry.EPISODES.vendor
	return self:IsMerchantOpen() and anyLive(episode.owners)
end

-- ── Loot episode ──────────────────────────────────────────────────────────────

local LOOT_TAIL = 0.30 -- [measure: P0.2 S3] last BAG_UPDATE_DELAYED may trail LOOT_CLOSED
local LOOT_STALE = 60 -- a missed LOOT_CLOSED can never pin the episode open
local COIN_CUE = "lootGold"

-- Quality -> intensity multiplier on the speaking cue. Starting values, tuned in game.
local QUALITY_GAIN = { [0] = 0.70, 0.85, 1.00, 1.15, 1.30, 1.45, 1.45, 1.30, 1.00 }
local QUEST_GAIN = 1.15

-- Scalars and three reused arrays: nothing allocated after the first episode.
local loot = {
	open = false,
	autoLoot = false,
	openedAt = 0,
	closedAt = -100,
	speaker = false,
	spoke = false,
	sawSlotCleared = false,
	best = -1,
	quest = false,
	items = 0,
	coins = 0,
}
local slotGain, slotIsCoin, slotLocked = {}, {}, {}

local function gainFor(quality, isQuest)
	local gain = QUALITY_GAIN[quality] or 1.0
	if isQuest and gain < QUEST_GAIN then
		gain = QUEST_GAIN
	end
	return gain
end

local function scan()
	wipe(slotGain)
	wipe(slotIsCoin)
	wipe(slotLocked)
	loot.best, loot.quest, loot.items, loot.coins = -1, false, 0, 0
	local n = GetNumLootItems and GetNumLootItems() or 0
	if issecretvalue(n) or type(n) ~= "number" then
		return
	end
	for slot = 1, n do
		local _, _, _, _, quality, locked, isQuestItem, _, _, isCoin = GetLootSlotInfo(slot)
		if issecretvalue(quality) or type(quality) ~= "number" then
			quality = 1
		end
		if issecretvalue(locked) then
			locked = true -- unknown ownership: treat as a roll item, never ours to announce
		end
		if issecretvalue(isQuestItem) then
			isQuestItem = false
		end
		if issecretvalue(isCoin) then
			isCoin = false
		end
		if isCoin == nil and GetLootSlotType then
			local kind = GetLootSlotType(slot)
			isCoin = (not issecretvalue(kind)) and kind == 2
		end
		slotLocked[slot] = locked and true or false
		slotIsCoin[slot] = isCoin and true or false
		slotGain[slot] = gainFor(quality, isQuestItem)
		if not locked then
			if isCoin then
				loot.coins = loot.coins + 1
			else
				loot.items = loot.items + 1
				if quality > loot.best then
					loot.best = quality
				end
				if isQuestItem then
					loot.quest = true
				end
			end
		end
	end
end

local function chooseSpeaker()
	if loot.items > 0 then
		local cue = firstLive(Pulse.Registry.EPISODES.loot.intake)
		if cue then
			return cue
		end
	end
	if loot.coins > 0 and Arbiter:IsLive(COIN_CUE) then
		return COIN_CUE
	end
	return false
end

local function lootLive()
	if loot.open then
		if (GetTime() - loot.openedAt) > LOOT_STALE then
			loot.open = false
			loot.closedAt = -100
			return false
		end
		return true
	end
	return (GetTime() - loot.closedAt) < LOOT_TAIL
end

-- LOOT_READY and LOOT_OPENED both land here; the first opens the episode, a second call
-- inside the same episode only rescans (autoloot can empty slots between the two).
function Arbiter:LootOpened(autoLoot)
	if not loot.open then
		loot.open = true
		loot.openedAt = GetTime()
		loot.spoke = false
		loot.sawSlotCleared = false
	end
	if not issecretvalue(autoLoot) then
		loot.autoLoot = autoLoot and true or false
	end
	scan()
	if loot.items + loot.coins > 0 or not loot.speaker then
		loot.speaker = chooseSpeaker()
	end
end

function Arbiter:LootClosed()
	if loot.open then
		loot.open = false
		loot.closedAt = GetTime()
	end
end

function Arbiter:LootReset()
	loot.open, loot.speaker, loot.spoke = false, false, false
	loot.closedAt = -100
end

-- Every intake handler (ITEM_PUSH, BAG_UPDATE_DELAYED gain, own CHAT_MSG_LOOT,
-- CHAT_MSG_MONEY) asks this first. true = "handled, do not fire your own cue".
function Arbiter:LootIntake()
	if not lootLive() or not loot.speaker then
		return false
	end
	if loot.autoLoot then
		if not loot.spoke then
			loot.spoke = true
			Pulse:FireIfEnabled(loot.speaker, gainFor(loot.best, loot.quest))
		end
		return true
	end
	-- Manual looting speaks per click from LootSlotCleared. Until the first click has been
	-- seen, intake falls through, so a client that never sends LOOT_SLOT_CLEARED is never
	-- silent.
	return loot.sawSlotCleared
end

-- LOOT_SLOT_CLEARED(slot). Manual looting: one cue per deliberate click, at that slot's
-- own quality. Autoloot: the first clear is simply the earliest intake.
function Arbiter:LootSlotCleared(slot)
	if not loot.open or not loot.speaker then
		return
	end
	if issecretvalue(slot) or type(slot) ~= "number" or slotLocked[slot] then
		return
	end
	if loot.autoLoot then
		self:LootIntake()
		return
	end
	loot.sawSlotCleared = true
	local cue = loot.speaker
	if slotIsCoin[slot] and self:IsLive(COIN_CUE) then
		cue = COIN_CUE
	end
	Pulse:FireIfEnabled(cue, slotGain[slot] or 1.0)
end

function Arbiter:_DebugLoot()
	return loot
end

-- ── Buses ─────────────────────────────────────────────────────────────────────

local DEFAULT_BUS_WINDOW = 0.15 -- [measure: P0.2 S5]; covers ControllerUI's 20 Hz panel poll
local busTime, busPriority, busLayer = {}, {}, {}

-- Pre-seeded from the Registry once, so no key is ever created at event time.
function Arbiter:SeedBuses()
	for _, trigger in ipairs(Pulse.Triggers) do
		local bus = trigger.bus
		if bus and not busLayer[bus] then
			busTime[bus] = -100
			busPriority[bus] = -1
			busLayer[bus] = "bus:" .. bus
		end
	end
end

-- Returns ok, layerName. ok = false when a more important cue on the same bus spoke inside
-- the window. An unknown bus name degrades to "no bus" rather than erroring.
function Arbiter:ClaimBus(bus, priority, window, fallbackLayer)
	local layer = busLayer[bus]
	if not layer then
		return true, fallbackLayer
	end
	local now = GetTime()
	priority = priority or 0
	if (now - busTime[bus]) < (window or DEFAULT_BUS_WINDOW) and priority < busPriority[bus] then
		return false, nil
	end
	busTime[bus] = now
	busPriority[bus] = priority
	return true, layer
end

Arbiter:SeedBuses()
```

---

## Appendix B — Test checklists

**`arbitration-test.lua` (46 checks)**

| Group | Checks |
|:--|:--|
| Vendor | **V1** Default profile (`merchantBuy` off): purchase still felt through `bagItemAdded` · **V2** owner live: `bagItemAdded` yields and `merchantBuy` plays once, with the bag settle arriving **before** the money · **V3** no vendor (bank withdrawal): `bagItemAdded` plays |
| Loot | **L1** autoloot with 2 items: `itemObtained` speaks exactly once, at the best quality's gain (1.00); `bagItemAdded` and `lootReceived` stand down; a bag settle inside the tail stands down; after the tail, bag cues are normal again · **L2** Default autoloot: one `bagItemAdded` per corpse, even with the gap past its own 0.2 s throttle · **L3** manual loot: coin click gives `lootGold` once; one `itemObtained` per item click; quest item gains 1.15 · **L4** manual loot on a client with no `LOOT_SLOT_CLEARED`: never silent · **L5** another player's loot chat is silent; own loot outside a window plays · **L6** a locked (roll) slot cleared is silent |
| Repair | **R1** personal repair: `merchantRepair` once; its payment is not a purchase; the next purchase is felt · **R2** money before durability: repair once, not twice, and not a purchase; the next purchase is felt · **R3** guild repair: repair once; the next **sale** is not swallowed · **R4** durability update without a repair (equipping): silent; the next purchase is felt · **R5** an expired arm can't swallow a later purchase of the same amount · **R6** cursor repair: one repair, payment absorbed |
| Durability | **D1** none → yellow fires; yellow → yellow silent; repair silent; none → red fires with gain 1.25 |
| Window bus | **B1** mailbox → vendor chain: close dropped, vendor arrival felt · **B2** a plain close still plays · **B3** bank close: `bankClosed` once, generic close yields · **B4** higher priority replaces on the same layer (`bus:window`); lower priority inside the window is dropped; the dropped cue's throttle isn't consumed |
| Intake bus | **I1** mail item: `itemObtained` plays and `bagItemAdded` yields · **I2** reversed order: both play on the same layer (the item replaces the bag tick) |

**`phase2-test.lua` (49 checks)**
- **Gates are pure:** all 10 gates play nothing; exactly 10 switches.
- **Gate data:** all 11 `PAGE_GATES` entries resolve to a trigger; `padDisconnected` is never gated; CONTROLLER_UI cues rely on `controllerUIMaster`; `bagItemAdded` sits behind `gateWorld`.
- **Seeding:** every built-in and custom profile seeds every switch ON.
- **Non-destructive runtime:**
  - "Disable all cues" leaves the switches alone.
  - With the gate open the cue plays; closed, it's dropped while its own switch stays untouched; `IsCueActive` reports false; other pages are unaffected; reopening restores it.
- **Row shape:** the WORLD page has one section header per section, exactly one cue row per cue, and no separate Intensity rows.
- **Folding and search:**
  - Folded: the header is shown and its cues are hidden.
  - Search reaches into a folded section; clearing the search folds it again; unfolding shows the cue.
  - Fold state is saved account-wide.
- **Simple view:**
  - It trims the sidebar and lands on the switches page.
  - It never rewrites `showAdvancedCueControls`.
  - Turning it off brings every page back.

---

## Appendix C — PulseProbe `Sequencer.lua` and the report script (reference, verified to compile and lint)

`PulseProbe/Probes/Sequencer.lua`:

```lua
-- PulseProbe — Probes/Sequencer.lua
-- Phase 0 event-order capture. Read-only: registers events, reads state, post-hooks two
-- Blizzard functions with hooksecurefunc. Never calls a protected function or
-- debugprofilestart.
local ADDON_NAME, Probe = ...
local SQ = {}
Probe.Sequencer = SQ
local frame = CreateFrame("Frame")

local EVENTS = {
	"MERCHANT_SHOW", "MERCHANT_CLOSED", "PLAYER_MONEY", "UPDATE_INVENTORY_DURABILITY",
	"UPDATE_INVENTORY_ALERTS", "BAG_UPDATE", "BAG_UPDATE_DELAYED", "ITEM_PUSH", "CHAT_MSG_LOOT",
	"CHAT_MSG_MONEY", "LOOT_READY", "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED",
	"START_LOOT_ROLL", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
	"PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "GOSSIP_SHOW", "GOSSIP_CLOSED", "MAIL_SHOW",
	"MAIL_CLOSED", "MAIL_INBOX_UPDATE", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
	"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_THREAT_SITUATION_UPDATE",
	"PLAYER_ENTER_COMBAT", "PLAYER_SWING", "PLAYER_EQUIPMENT_CHANGED",
}

local function freeSlots()
	if C_Container and C_Container.CalculateTotalNumberOfFreeBagSlots then
		return C_Container.CalculateTotalNumberOfFreeBagSlots()
	end
	return nil
end

frame:SetScript("OnEvent", function(_, event, a1, a2, ...)
	if event == "PLAYER_MONEY" then
		Probe:Record(event, GetMoney and GetMoney())
	elseif event == "BAG_UPDATE_DELAYED" then
		Probe:Record(event, freeSlots())
	elseif event == "UPDATE_INVENTORY_DURABILITY" then
		Probe:Record(event, GetRepairAllCost and GetRepairAllCost(), InRepairMode and InRepairMode())
	elseif event == "UPDATE_INVENTORY_ALERTS" then
		local worst = 0
		for i = 1, 11 do
			local s = GetInventoryAlertStatus and GetInventoryAlertStatus(i)
			if type(s) == "number" and not issecretvalue(s) and s > worst then
				worst = s
			end
		end
		Probe:Record(event, worst)
	elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
		Probe:Record(event, a1, GetNumLootItems and GetNumLootItems())
	elseif event == "CHAT_MSG_LOOT" then
		Probe:Record(event, select(10, ...)) -- 12th payload field: looter GUID
	elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		Probe:Record(event, InCombatLockdown(), UnitAffectingCombat("player"))
	else
		Probe:Record(event, a1, a2)
	end
end)

local function onTimer0()
	Probe:Record("TIMER0")
end
local timerFrame = CreateFrame("Frame")
timerFrame:SetScript("OnEvent", function()
	C_Timer.After(0, onTimer0)
end)

local hooked, mailHooked = false, false
local function hookOnce()
	if hooked then
		return
	end
	hooked = true
	if type(RepairAllItems) == "function" then
		hooksecurefunc("RepairAllItems", function(useGuild)
			Probe:Record("HOOK_RepairAllItems", useGuild, GetRepairAllCost and GetRepairAllCost())
		end)
	end
end
local function hookMail()
	if mailHooked or type(OpenAllMail) ~= "table" then
		return
	end
	mailHooked = true
	if type(OpenAllMail.StartOpening) == "function" then
		hooksecurefunc(OpenAllMail, "StartOpening", function()
			Probe:Record("HOOK_OpenAllMail_Start")
		end)
	end
	if type(OpenAllMail.StopOpening) == "function" then
		hooksecurefunc(OpenAllMail, "StopOpening", function()
			Probe:Record("HOOK_OpenAllMail_Stop")
		end)
	end
end

local lastLeft = false
local pollFrame = CreateFrame("Frame")
pollFrame:SetScript("OnUpdate", function()
	if not Probe.TraceState.running or type(GetUIPanel) ~= "function" then
		return
	end
	local left = GetUIPanel("left") or false
	if left ~= lastLeft then
		lastLeft = left
		Probe:Record("UIPANEL_LEFT", left and left.GetName and left:GetName() or false)
	end
end)

function SQ:OnInit() end
function SQ:OnEnable()
	for _, event in ipairs(EVENTS) do
		pcall(frame.RegisterEvent, frame, event)
	end
	pcall(timerFrame.RegisterEvent, timerFrame, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
	hookOnce()
	hookMail()
	frame:RegisterEvent("ADDON_LOADED") -- Blizzard_MailFrame may load later
end
frame:HookScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == "Blizzard_MailFrame" then
		hookMail()
	end
end)

Probe:RegisterProbe("Sequencer", SQ)
```

**`scripts/probe-trace-report.lua` (core loop).** It loads the SavedVariables file into a private environment (`setfenv`). Then, for each A → B pair in the table below, and for every A, it finds the first B within 2 s. It reports n, p50, p95 and max in ms from the precise clock, plus the count of pairs in the same frame. For the money/bag pair it also counts how often B came *before* A. Finally it prints the `InCombatLockdown()` sample at each `PLAYER_REGEN_DISABLED` and the `GetNumLootItems()` sample at each `LOOT_READY`.

| A → B | Sets |
|:--|:--|
| `PLAYER_MONEY` → `BAG_UPDATE_DELAYED` (signed) | order check for P1.1 |
| `HOOK_RepairAllItems` → `UPDATE_INVENTORY_DURABILITY` | `REPAIR_WINDOW` |
| `UPDATE_INVENTORY_DURABILITY` → `PLAYER_MONEY` | `DEBIT_WINDOW` |
| `LOOT_CLOSED` → `BAG_UPDATE_DELAYED` | `LOOT_TAIL` |
| `LOOT_SLOT_CLEARED` → `LOOT_SLOT_CLEARED` | autoloot spacing |
| `…FRAME_HIDE` → `…FRAME_SHOW` | whether the chain is same-frame |
| `…FRAME_HIDE` → `TIMER0` | deferral validity |
| `…FRAME_SHOW` → `UIPANEL_LEFT` | `DEFAULT_BUS_WINDOW` |
| `MAIL_INBOX_UPDATE` → `ITEM_PUSH` | mail spacing |
| `ITEM_PUSH` → `ITEM_PUSH` | bulk spacing |
| `PLAYER_REGEN_DISABLED` → `UNIT_THREAT_SITUATION_UPDATE` | pull bus (deferred) |

*No addon code was changed. The implementation package in this folder (patches, evidence, tools, `verify.sh`) was added at the owner's request. Nothing was added to `docs/DOCS_COMPILATION.md`.*

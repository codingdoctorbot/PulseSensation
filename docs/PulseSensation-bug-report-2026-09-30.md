# PulseSensation: Bug Report and Proposed Fixes

**Repository:** [codingdoctorbot/PulseSensation](https://github.com/codingdoctorbot/PulseSensation)
**Commit reviewed:** [`8a4309d`](https://github.com/codingdoctorbot/PulseSensation/commit/8a4309d7264bc2f3cd4057e17c550d9b973cde9d) (`chore(release): bump version to 0.3.0-beta`, 2026-09-30 13:48)
**Scope:** code that landed after this morning's review (`docs/PULSEHAPTICS_CODE_REVIEW_2026-09-30.md`):
- [`f623a8a`](https://github.com/codingdoctorbot/PulseSensation/commit/f623a8aa058f1478e1ea421326fb0518cf878c0c): the fixes for that review
- [`2566d36`](https://github.com/codingdoctorbot/PulseSensation/commit/2566d361b481d7b1dd7c0cb0efb84794a29f57d7): the arbitration layer
- [`02ea833`](https://github.com/codingdoctorbot/PulseSensation/commit/02ea833019a955830d63226b2ef0f5135f0d3c3a): page switches (group gates)

**Date:** 2026-09-30

---

## Contents

1. [Summary](#1-summary)
2. [How this was checked](#2-how-this-was-checked)
3. [Findings](#3-findings)
   - [B-01 Vendor purchases paid in a non-gold currency are silent](#b-01-p1-vendor-purchases-paid-in-a-non-gold-currency-are-silent)
   - [B-02 The "instant ability" de-duplication never reaches existing installs](#b-02-p1-the-instant-ability-de-duplication-never-reaches-existing-installs)
   - [B-03 Immersion: Ranged lost its only instant-ability cue](#b-03-p2-immersion-ranged-lost-its-only-instant-ability-cue)
   - [B-04 Craft strikes ignore the Casting page switch](#b-04-p2-craft-strikes-ignore-the-casting-page-switch)
   - [B-05 Shared bus layer cuts off longer patterns](#b-05-p2-shared-bus-layer-cuts-off-longer-patterns)
   - [B-06 Autoloot loses item quality](#b-06-p3-autoloot-loses-item-quality)
   - [B-07 Cursor repair: payment read as a purchase](#b-07-p3-cursor-repair-payment-read-as-a-purchase-next-purchase-swallowed)
   - [B-08 Ocean-zone pattern misses "coast"](#b-08-p3-ocean-zone-pattern-misses-coast)
   - [B-09 Dialogs silently do nothing in combat](#b-09-p3-dialogs-silently-do-nothing-in-combat)
4. [Verification of the proposed fixes](#4-verification-of-the-proposed-fixes)
5. [What still needs the live client](#5-what-still-needs-the-live-client)
6. [Appendix A: repro scenarios](#appendix-a-repro-scenarios)
7. [Appendix B: full patch](#appendix-b-full-patch)

---

## 1. Summary

At `8a4309d`, luacheck passes (0 warnings in 53 files) and all 9 offline suites pass. None of the bugs below is caught by them.

| ID | Sev. | Finding | Evidence |
|---|---|---|---|
| B-01 | **P1** | While "Purchased item from vendor" is on, a purchase paid in any non-gold currency produces no vibration at all. | Reproduced |
| B-02 | **P1** | The v11 migration leaves the doubled `selfCastInstant` in 3 curated profiles for every existing install. Its "stock defaults" check can no longer match any profile saved before the page switches existed. | Reproduced |
| B-03 | P2 | Fresh installs of *Immersion: Ranged* get no feedback for instant abilities. `f623a8a` removed its only such cue. | Fact (fresh DB) |
| B-04 | P2 | With the Casting page switch **off**, craft/gather strikes still play, and the craft still suppresses `castTexture`. | Reproduced |
| B-05 | P2 | Cues on a shared bus cancel the remaining steps of a longer, higher-priority pattern still playing. A cue set to intensity 0 still claims the bus. | Reproduced (first part) |
| B-06 | P3 | Autoloot: if the loot window is re-scanned after autoloot has emptied it, the item-quality gain is lost. | Reproduced |
| B-07 | P3 | Cursor repair, when payment arrives before the durability update: the repair also plays the purchase cue, and the next real purchase is swallowed. | Reproduced (event order needs the live client) |
| B-08 | P3 | Ocean-zone pattern `coastal?` matches "coasta"/"coastal" but not "coast". | Reproduced |
| B-09 | P3 | `Popup.Confirm` and `Popup.Prompt` do nothing in combat, with no feedback. | Fact (code) |

**Also:** the uploaded text dump of the repo was missing `PulseHaptics/Core/Database.lua`, `Core/Registry.lua`, `UI/Panel/Spec.lua` and `PulseChecklist/tests/harness.lua`. This review used a clone of the repository at `8a4309d`, which otherwise matches the dump exactly.

---

## 2. How this was checked

- **Baseline:** built LuaJIT, luacheck, argparse and LuaFileSystem from their GitHub sources, then ran `./scripts/test.sh`. Result: 0/0 lint, 9/9 suites pass.
- **Repros:** small scripts built on the repo's own test setups (the stubbed WoW API and fake engine in `arbitration-test.lua` and `crafting-test.lua`). They drive the **real** `Init.lua`, `Registry.lua`, `Arbiter.lua`, `Modes.lua`, `Interaction.lua`, `World.lua`, `Inventory.lua`, `CastActivity.lua` and `Crafting.lua` with synthetic events. Appendix A lists them.
- **Migration probe:** real saved settings were generated from fresh installs at four commits, then loaded into the HEAD code and compared with a fresh HEAD install. This uses the approach of `docs/review-2026-09-30/probes/migrate.lua`. The four commits:
  - `dace2ab`: v8, before profile curation
  - `db2ffa5`: curated v8
  - `1ca6a24`: v10
  - `8a4309d`: v11
- **Fixes:** every fix proposed below was applied to a scratch copy (full diff in Appendix B). The repros and the full suite were then re-run against both HEAD and the patched copy (§4).

Labels used:
- **[Reproduced]:** failed on HEAD in a repro that runs the real addon code.
- **[Fact]:** read in the code or in generated saved settings.
- **[Inference]:** reasoned, not executed.
- **[Unverified]:** needs the live client.

---

## 3. Findings

Code citations link to `8a4309d`.

### B-01 [P1] Vendor purchases paid in a non-gold currency are silent

**Where**
- [`Core/Arbiter.lua:99-102`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Arbiter.lua#L99-L102): `VendorOwnsIntake`
- [`Modules/Inventory.lua:150`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Modules/Inventory.lua#L150): `bagItemAdded` yields
- [`Modules/World.lua:159`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Modules/World.lua#L159): `itemObtained` yields
- [`Modules/Interaction.lua:284-301`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Modules/Interaction.lua#L284-L301): `merchantBuy` fires only on a `PLAYER_MONEY` decrease
- [`Core/Registry.lua:106`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Registry.lua#L106): `EPISODES.vendor`

**What happens.** The owner rule asks only whether the owner cue is *live*, not whether it actually *spoke*:

```text
on BAG_UPDATE_DELAYED (bag gained an item):
    if merchant window open AND merchantBuy is enabled:   -- VendorOwnsIntake()
        return                                            -- "merchantBuy will speak for this"
    fire bagItemAdded

on PLAYER_MONEY while at a merchant:
    if money went down: fire merchantBuy
```

A purchase paid in badges, honor, crystals or any other non-gold currency changes no gold, so `PLAYER_MONEY` never fires and `merchantBuy` never plays. The bag and item-push cues have already stood down, so **nothing plays**.

`merchantBuy` is enabled in *Immersion: Melee*, *Immersion: Caster*, *Immersion: Ranged* and *Questing* ([`Database.lua:554`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Database.lua#L554), [`:671`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Database.lua#L671), [`:790`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Database.lua#L790), [`:984`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Database.lua#L984)).

**Evidence [Reproduced].** Scenario R1 in Appendix A: merchant open, `ITEM_PUSH` and a bag gain, no `PLAYER_MONEY`.

| | cues felt |
|---|---|
| HEAD | **0** |
| Patched | 1 |

The gold-purchase sanity check S1 still gives exactly one cue with the patch.

**Proposed fix.** The intake yields only if the owner actually spoke within a short window, in either order. If no gold debit shows up, the deferred intake cue plays on its own.

```text
VENDOR_SETTLE = 0.30 s

Interaction, PLAYER_MONEY at merchant, money down:
    Arbiter.VendorOwnerSpoke()        -- stamp time, even if merchantBuy is throttled
    fire merchantBuy

Arbiter.VendorOwnsIntake(cueID):
    if not (merchant open and owner live): return false      -- caller fires normally
    if owner spoke within VENDOR_SETTLE:   return true       -- gold came first
    if nothing pending: remember (cueID, now); schedule flush in VENDOR_SETTLE
    return true

flush():
    if owner did NOT speak within VENDOR_SETTLE of the pending intake:
        fire pending cueID                                   -- non-gold purchase
```

```lua
-- Core/Arbiter.lua
local VENDOR_SETTLE = 0.30 -- [measure] PLAYER_MONEY vs BAG_UPDATE_DELAYED spread
local vendorOwnerAt = -100
local vendorPendingCue, vendorPendingAt = false, 0

function Arbiter:VendorOwnerSpoke()
	vendorOwnerAt = GetTime()
end

local function flushVendorIntake()
	local cue = vendorPendingCue
	vendorPendingCue = false
	if cue and math.abs(vendorOwnerAt - vendorPendingAt) > VENDOR_SETTLE then
		Pulse:FireIfEnabled(cue)
	end
end

function Arbiter:VendorOwnsIntake(cueID)
	local episode = Pulse.Registry.EPISODES.vendor
	if not (self:IsMerchantOpen() and anyLive(episode.owners)) then
		return false
	end
	local now = GetTime()
	if (now - vendorOwnerAt) <= VENDOR_SETTLE then
		return true
	end
	if cueID and not vendorPendingCue then
		vendorPendingCue, vendorPendingAt = cueID, now
		C_Timer.After(VENDOR_SETTLE, flushVendorIntake) -- static function: no closure
	end
	return true
end
```

The callers pass their own cue: `VendorOwnsIntake("bagItemAdded")` in Inventory and `VendorOwnsIntake("itemObtained")` in World. Interaction calls `Pulse.Arbiter:VendorOwnerSpoke()` just before `FireIfEnabled("merchantBuy")`.

**Trade-off.** A currency purchase is felt about 0.3 s late. That is better than not at all, and gold purchases are unchanged.

---

### B-02 [P1] The "instant ability" de-duplication never reaches existing installs

**Where**
- [`Core/Database.lua:1482-1491`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Database.lua#L1482-L1491): migration chain; Option B re-runs at `< 11`
- [`Core/Database.lua:1955-2117`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Database.lua#L1955-L2117): `_MigrateCuratedProfilesOptionB`, with checks A ([L2027](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Database.lua#L2027)), B ([L2056](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Database.lua#L2056)) and C ([L2085](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Database.lua#L2085))
- Commit `f623a8a` removed `selfCastInstant` from four curated profiles and added the `< 11` re-run.

**What happens.** A profile is treated as "untouched", and re-seeded, only if its cue set equals one of three sets:

```text
isProfileUntouched(profile):
    A: equals TODAY's curated set          -- v9/v10 profiles still have selfCastInstant: no
    B: equals LEGACY_V8 curated set        -- no
    C: equals stock trigger.default values -- see below
    otherwise: "the user customised it", leave alone
```

A v9 or v10 install holds the curated set **as shipped at v9/v10**. That set had `selfCastInstant` on in *Dungeon: Healer*, *Dungeon: Caster* and *Immersion: Caster*, alongside `selfCastSucceeded`. It matches none of A, B or C, so it is classed as customised and keeps the doubled cue. The new `< 11` re-run is a no-op for exactly the users it was added for.

**Second defect in the same function.** Checks A and B skip page-switch cues (`trigger.gate`), but check C does not:

```lua
-- Database.lua ~L2086, check C
for _, trigger in ipairs(Pulse.Triggers or {}) do
	local currentVal = profile.triggers[trigger.id] and true or false   -- gate keys absent -> false
	local expected = trigger.default and true or false                  -- gates default true
	if currentVal ~= expected then matchesStock = false break end
```

`Migrate()` runs before `ApplyDefaults`, so any profile saved before `02ea833` has no gate keys. Check C can therefore never match on a real upgrade.

**Evidence [Reproduced].** Old saved settings upgraded with the HEAD code, compared with a fresh HEAD install. The cells show `selfCastInstant` after the upgrade (fresh HEAD = false everywhere):

| Upgraded from | Dungeon: Healer | Dungeon: Caster | Immersion: Caster | Immersion: Ranged |
|---|---|---|---|---|
| v10 (`1ca6a24`) | **true** | **true** | **true** | **true** |
| curated v8 (`db2ffa5`) | **true** | **true** | **true** | **true** |
| pre-curation v8 (`dace2ab`) | false | false | false | false |

Stock-defaults profile with no gate keys (*Dungeon: Tank* shape):

| | cues on after migration |
|---|---|
| HEAD | 53 (left on the stock defaults) |
| Patched | 58 (the curated Tank set) |

**Proposed fix.**

1. Record each earlier shipped curated set as a small difference from today's, and add it as check A2.
2. Make check C skip gates, like A and B.
3. Bump `DB_VERSION` to 12, and change the re-run from `< 11` to `< 12`, so installs that have already loaded v11 get it too.

```text
HISTORIC_CURATED_DELTAS = [
    v9-10: { Healer: {selfCastInstant=true}, Caster: {...=true}, Imm.Caster: {...=true} },
    v11  : { Imm.Ranged: {selfCastInstant=false} },          -- see B-03
]

A2: for each delta in HISTORIC_CURATED_DELTAS:
        expected(cue) = delta[cue] if present, else today's curated rule
        if profile matches expected for every non-gate cue: untouched
C : skip trigger.gate, like A and B
```

```lua
-- Core/Database.lua (abridged; Appendix B has the full hunk)
local DB_VERSION = 12

local HISTORIC_CURATED_DELTAS = {
	{ -- DB_VERSION 9-10
		["Dungeon: Healer"] = { selfCastInstant = true },
		["Dungeon: Caster"] = { selfCastInstant = true },
		["Immersion: Caster"] = { selfCastInstant = true },
	},
	{ -- DB_VERSION 11
		["Immersion: Ranged"] = { selfCastInstant = false },
	},
}

-- in Migrate():
if DB.version < 12 then -- was < 11
	self:_MigrateCuratedProfilesOptionB()
end
```

**Verified.**
- After the patch, upgrades from v8, curated v8, v10 and v11 all end identical to a fresh install for all 12 built-in profiles.
- A v10 *Dungeon: Healer* with one cue deliberately flipped by the user (`jumped`) is correctly left untouched: the edit is kept, and so is `selfCastInstant`.

**Consider later.** `__curatedVersion` is stamped `1` on every profile regardless ([L2114](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Database.lua#L2114)), so it carries no information. Stamping the curation revision (2, 3, ...) would make "which set did this profile start from" answerable, and the growing list of sets to compare against unnecessary.

---

### B-03 [P2] Immersion: Ranged lost its only instant-ability cue

**Where**
- [`Core/Database.lua:732-847`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Database.lua#L732-L847): `PROFILE_TRIGGER_OVERRIDES["Immersion: Ranged"]` (`__exclusive`)
- [`Core/CastActivity.lua:192-195`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/CastActivity.lua#L192-L195): the new Auto Shot / Shoot filter

**What happens.** `f623a8a` ("de-duplicate profile triggers") removed `selfCastInstant` from four profiles. Three of them also had `selfCastSucceeded`, so that was a real de-duplication. *Immersion: Ranged* did not have `selfCastSucceeded`. Removing `selfCastInstant` there removed the only feedback for instant abilities (Arcane Shot, Kill Command, most hunter buttons).

The morning review's F-06 was about Auto Shot firing the cue on every arrow. The same commit already fixed that at the source, in CastActivity lines 192-195. So the profile change was not needed for Ranged.

**Evidence [Fact].** Fresh-install `PulseDB`:

| Profile | selfCastInstant | selfCastSucceeded |
|---|---|---|
| Immersion: Ranged at `1ca6a24` | true | false |
| Immersion: Ranged at `8a4309d` | **false** | **false** |

**Proposed fix.** Restore `selfCastInstant = true` in `PROFILE_TRIGGER_OVERRIDES["Immersion: Ranged"]`. The `v11` entry in B-02's `HISTORIC_CURATED_DELTAS` brings back untouched v11 installs as well.

If dropping the cue was intended, keep the removal but add `selfCastSucceeded` instead, so the profile has at least one "ability done" cue.

---

### B-04 [P2] Craft strikes ignore the Casting page switch

**Where**
- [`Modules/Crafting.lua:368-383`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Modules/Crafting.lua#L368-L383): `beginCraft` checks `GetCue` only
- [`Modules/Crafting.lua:310-313`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Modules/Crafting.lua#L310-L313): `IsCrafting` checks `GetCue` only
- [`Modules/Crafting.lua:418-431`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Modules/Crafting.lua#L418-L431): `_PlayStrike` goes straight to `Engine:PlayMode`
- [`Modules/Crafting.lua:547`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Modules/Crafting.lua#L547): `sync`
- [`Core/Init.lua:186`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Init.lua#L186): `HoldRolesIfEnabled` does check `GatesOpen`
- [`Core/Init.lua:410`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Init.lua#L410): `IsCueActive`, which already exists for this purpose

**What happens.** `craftTexture` sits on the CASTING page, behind the `gateCasting` switch. Only half of the craft respects it:

```text
craft starts:  if craftTexture enabled: active = true         -- gate not checked
each frame:    HoldRolesIfEnabled(bed)                        -- gate checked -> silent
on the beat:   Engine:PlayMode(STRIKE_LAYER, THUD, ...)       -- gate NOT checked -> plays
Combat:        if Pulse.IsCrafting(): suppress castTexture    -- true, but castTexture is gated anyway
```

With the Casting page switched off, a blacksmith or miner still feels every hammer strike.

**Evidence [Reproduced].** R5 in Appendix A: real `Crafting.lua` and `CastActivity.lua`. The harness's `HoldRolesIfEnabled` mirrors `Init.lua:186`. The run is a 3 s blacksmithing craft.

| | craft claimed | bed | strikes |
|---|---|---|---|
| HEAD | **true** | silent | **3** |
| Patched | false | silent | 0 |

**Proposed fix.** Use `Pulse:IsCueActive(CUE)` (cue on AND gates open) wherever Crafting currently uses `GetCue(CUE)`. Also re-check it in `_PlayStrike`, because a page switch flipped in combat defers the module's re-sync ([`Database.lua:2907`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Database.lua#L2907)), not the gate itself.

```lua
-- Modules/Crafting.lua
function M:IsCrafting()
	if not (Pulse.Database and Pulse.Database:Get("masterEnabled") and Pulse:IsCueActive(CUE)) then
		return false
	end
	...
-- beginCraft
	if not (Pulse.Database:Get("masterEnabled") and Pulse:IsCueActive(CUE)) then
		active = false
		return
	end
-- _PlayStrike
	if not Pulse:IsCueActive(CUE) then
		return
	end
-- sync
	local wanted = (Pulse.Database:Get("masterEnabled") and Pulse:IsCueActive(CUE)) or false
```

`crafting-test.lua` needs a `Pulse:IsCueActive` stub. Appendix B includes it.

**Related, worth a sweep [Inference].** Any other module that decides at registration or craft/episode start with `GetCue` rather than `IsCueActive`, and then plays through the engine directly, has the same gap. `Crafting.lua:430` is the only direct `Engine:PlayMode` call in `Modules/` outside previews and `/pulse test` helpers. That makes it the only live leak found, but a lint-style test ("no `Engine:PlayMode`/`Set` in Modules except previews") would keep it that way.

---

### B-05 [P2] Shared bus layer cuts off longer patterns

**Where**
- [`Core/Arbiter.lua:285`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Arbiter.lua#L285): `DEFAULT_BUS_WINDOW = 0.15`
- [`Core/Arbiter.lua:302-315`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Arbiter.lua#L302-L315): `ClaimBus`
- [`Core/Init.lua:101-123`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Init.lua#L101-L123): `FireIfEnabled` plays on the shared layer
- [`Core/Engine.lua:354`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Engine.lua#L354) and [`:484`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Engine.lua#L484): each `PlayMode` bumps the layer token, and a pending step whose token is stale is dropped
- [`Core/Modes.lua:21-50`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Modes.lua#L21-L50) and [`:117-124`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Modes.lua#L117-L124): pattern lengths

**What happens.** Every cue on a bus plays on one engine layer (`bus:window`, `bus:intake`). Priority protects a higher cue for only 0.15 s:

```text
ClaimBus(bus, prio):
    if now - lastClaim < 0.15 and prio < lastPrio: refuse
    else: claim; PlayMode on the shared layer -> bumps token -> cancels remaining steps
```

Several patterns on the buses outlast 0.15 s:

| Pattern | Length | Used by (examples) |
|---|---|---|
| DOUBLE_TAP | ≈ 0.36 s | `guildBankOpened` |
| CHIME | ≈ 0.28 s | `itemObtained`, `auctionHouseShow` |
| LONG | ≈ 0.45 s | `spiritHealerShow` |

A lower-priority cue that arrives between 0.15 s and the end of the pattern cuts it short. Before `2566d36`, each cue had its own layer and both played in full.

A second problem: `FireIfEnabled` claims the bus before it looks at intensity. A cue the user set to **0** (a common way to mute one cue) still claims the bus and bumps the token. It can cancel another cue's pattern, or block a lower-priority one, while playing nothing itself. This is inconsistent with `Arbiter:IsLive`, which treats intensity 0 as off ([L35-L36](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Arbiter.lua#L35-L36)).

**Evidence [Reproduced].** R4 in Appendix A: `guildBankOpened` (priority 3, DOUBLE_TAP), then `interactionWindowClosed` (priority 1) 0.2 s later.
- **HEAD:** both play on `bus:window`, so the second one cancels the DOUBLE_TAP's second tap.
- **Patched:** the priority-1 cue is refused while the DOUBLE_TAP is still running.

The zero-intensity part is **[Fact]** from reading the code. The harness's fake database cannot set intensity.

**Proposed fix.**

```text
FireIfEnabled:
    scale  = intensity setting;  if scale <= 0: return false     -- before the bus claim
    modeID = user override or trigger.mode
    ClaimBus(bus, prio, window, fallbackLayer, modeID)

ClaimBus:
    held = (now - lastClaim < window) OR (now < busUntil)        -- pattern still playing
    if held and prio < lastPrio: refuse
    busUntil = now + modeLength(modeID)                          -- Σ baseDuration*relDuration + gaps, cached
```

```lua
-- Core/Arbiter.lua
local modeLengthCache = {}
local function modeLength(modeID)
	local cached = modeLengthCache[modeID]
	if cached then
		return cached
	end
	local mode = modeID and Pulse.Modes and Pulse.Modes[modeID]
	local total = 0
	if mode and not mode.continuous and mode.steps then
		for _, step in ipairs(mode.steps) do
			if step.gap then
				total = total + step.gap
			else
				total = total + (mode.baseDuration or 0) * (step.relDuration or 1)
			end
		end
	end
	if modeID then
		modeLengthCache[modeID] = total
	end
	return total
end

function Arbiter:ClaimBus(bus, priority, window, fallbackLayer, modeID)
	local layer = busLayer[bus]
	if not layer then
		return true, fallbackLayer
	end
	local now = GetTime()
	priority = priority or 0
	local held = (now - busTime[bus]) < (window or DEFAULT_BUS_WINDOW) or now < busUntil[bus]
	if held and priority < busPriority[bus] then
		return false, nil
	end
	busTime[bus] = now
	busUntil[bus] = now + modeLength(modeID)
	busPriority[bus] = priority
	return true, layer
end
```

In `Init.lua`, move the `scale` and `modeID` reads above the bus claim and return `false` when `scale <= 0` (Appendix B).

**Caveats.**
- The length is an estimate: it ignores per-mode duration tuning (`durMult` in the engine). If tuning can stretch patterns a lot, pass the tuned length from the engine instead.
- A lower-priority cue refused this way is dropped, not queued. That matches the bus's existing "the more important cue speaks" rule.

---

### B-06 [P3] Autoloot loses item quality

**Where:** [`Core/Arbiter.lua:211-225`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Arbiter.lua#L211-L225) (`LootOpened`), [`:138-142`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Core/Arbiter.lua#L138-L142) (`scan` resets `best`/`quest` first)

**What happens.** `LOOT_READY` and `LOOT_OPENED` both call `LootOpened`. The code comment itself notes that autoloot can empty slots between the two:

```text
LOOT_READY : scan -> best = Epic(4), speaker = itemObtained
LOOT_OPENED: scan -> window now empty -> best = -1, quest = false
             items+coins == 0 and speaker already set -> keep speaker   (correct)
             ...but best/quest stay clobbered                           (bug)
first intake: fire speaker at gainFor(-1) = 1.0 instead of 1.30
```

**Evidence [Reproduced].** R2 in Appendix A: an Epic in `LOOT_READY`, and an empty window at `LOOT_OPENED`.

| | gain played |
|---|---|
| HEAD | 1.0 |
| Patched | 1.3 |

**Proposed fix.**

```lua
function Arbiter:LootOpened(autoLoot)
	...
	local prevBest, prevQuest = loot.best, loot.quest
	scan()
	if loot.items + loot.coins > 0 or not loot.speaker then
		loot.speaker = chooseSpeaker()
	else
		loot.best, loot.quest = prevBest, prevQuest -- window emptied by autoloot: keep first scan
	end
end
```

---

### B-07 [P3] Cursor repair: payment read as a purchase, next purchase swallowed

**Where:** [`Modules/Interaction.lua:266-283`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Modules/Interaction.lua#L266-L283) (durability branch; `debitCost = -1` at L278), [`:291-301`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Modules/Interaction.lua#L291-L301) (money branch)

**What happens.** A cursor repair (repair-mode click on one item) is not armed by the `RepairAllItems` hook. The code expects durability first, then money. If the money update arrives first:

```text
PLAYER_MONEY (-repair cost): not armed, no debit pending -> fires merchantBuy        (wrong cue)
UPDATE_INVENTORY_DURABILITY: InRepairMode() -> fires merchantRepair,
                             sets debitCost = -1 (= "any amount") for 1 s
PLAYER_MONEY (real purchase within 1 s): matches debit -1 -> swallowed               (lost cue)
```

**Evidence [Reproduced].** R3b in Appendix A.
- **HEAD:** the repair payment plays `merchantBuy`, and the purchase 0.4 s later plays nothing.
- **Patched:** the repair plays once, and the purchase plays `merchantBuy`.
- The "durability first" order (R3) works on both.
- **[Unverified]:** whether the client ever delivers money before durability for a cursor repair.

**Proposed fix.** While the repair cursor is active, a gold debit is a repair, never a purchase. And a payment already seen means no open-ended debit is armed afterwards.

```lua
local cursorPaidAt = -100

-- PLAYER_MONEY, before the armed/purchase branches:
elseif delta < 0 and type(InRepairMode) == "function" and InRepairMode() then
	fireRepairOnce(now)
	cursorPaidAt = now

-- UPDATE_INVENTORY_DURABILITY:
elseif cursor and (now - cursorPaidAt) > DEBIT_WINDOW then
	debitCost, debitUntil = -1, now + DEBIT_WINDOW
```

---

### B-08 [P3] Ocean-zone pattern misses "coast"

**Where:** [`Modules/Movement.lua:52`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/Modules/Movement.lua#L52)

**What happens.** In a Lua pattern, `?` applies to the preceding character only. So `"%f[%a]coastal?%f[%A]"` means "coasta" + optional "l". It matches "coastal" but not "coast", the word it replaced from the old substring list.

**Evidence [Reproduced].** In LuaJIT, `("north coast"):find("%f[%a]coastal?%f[%A]")` returns `nil`, and `("coastal cliffs"):find(...)` returns `1`.

**Proposed fix.**

```lua
	"%f[%a]coasts?%f[%A]",
	"%f[%a]coastal%f[%A]",
```

---

### B-09 [P3] Dialogs silently do nothing in combat

**Where:** [`UI/Panel/Popup.lua:668-671`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/UI/Panel/Popup.lua#L668-L671), [`:683-686`](https://github.com/codingdoctorbot/PulseSensation/blob/8a4309d7264bc2f3cd4057e17c550d9b973cde9d/PulseHaptics/UI/Panel/Popup.lua#L683-L686)

**What happens.** `f623a8a` added `if InCombatLockdown() then return end` to `Confirm` and `Prompt`. The combat guard is sensible, but the user gets no feedback: "Delete profile", "Rename", "Reset" and similar buttons do nothing when clicked in combat. **[Fact]**, from reading the code.

**Proposed fix (not in the Appendix B patch).**

```lua
local function refuseInCombat()
	if InCombatLockdown and InCombatLockdown() then
		if UIErrorsFrame and ERR_NOT_IN_COMBAT then
			UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1)
		else
			print("Pulse: not available in combat. Try again after combat.")
		end
		return true
	end
	return false
end

function Popup.Confirm(text, acceptText, onAccept)
	if refuseInCombat() then
		return
	end
	...
```

A nicer alternative is to queue the dialog and open it on `PLAYER_REGEN_ENABLED`.

---

## 4. Verification of the proposed fixes

Appendix B was applied to a scratch copy of `8a4309d`. Results:

| Check | HEAD `8a4309d` | Patched |
|---|---|---|
| luacheck (53 files) | 0 / 0 | 0 / 0 |
| `scripts/test.sh`, 9 suites | 9 pass | 9 pass |
| `arbitration-test.lua` with `Core/Modes.lua` also loaded, so bus lengths are live | n/a | pass |
| R1 currency purchase felt | ✗ 0 cues | ✓ 1 |
| S1 gold purchase: exactly one cue | ✓ | ✓ |
| R2 Epic autoloot gain 1.3 | ✗ 1.0 | ✓ |
| R3 cursor repair, durability first | ✓ | ✓ |
| R3b cursor repair, money first | ✗ ✗ | ✓ ✓ |
| R4 DOUBLE_TAP not cut by a lower-priority cue | ✗ | ✓ |
| R5 Casting page off: craft not claimed, 0 strikes | ✗ (3 strikes) | ✓ |
| Migration v8 / curated v8 / v10 / v11 → identical to fresh (12 profiles) | ✗ (4 profiles differ from v10 and curated v8) | ✓ |
| Stock-shaped profile (no gate keys) gets curated | ✗ | ✓ |
| User-edited v10 profile left alone | ✓ | ✓ |

Test expectations changed by the patch:
- `harness.lua`: DB version 11 → 12.
- `crafting-test.lua`: adds a `Pulse:IsCueActive` stub that follows `gateCasting`.

**Suggested permanent tests.** Add R1, R2, R3b and R4 to `arbitration-test.lua`, and R5 to `crafting-test.lua`. Add a migration test that loads a v10-shaped and a v11-shaped `PulseDB` and asserts equality with a fresh install. Only fresh-install migration is covered today, which is why B-02 passed CI.

---

## 5. What still needs the live client

- **VENDOR_SETTLE (0.30 s):** the real spread between `PLAYER_MONEY` and `BAG_UPDATE_DELAYED` for a purchase. The value should cover the slowest observed case.
- **Cursor-repair event order (B-07):** whether money can arrive before `UPDATE_INVENTORY_DURABILITY`.
- **Tuned pattern lengths (B-05):** whether per-mode duration tuning stretches patterns enough that `modeLength` should come from the engine.
- **General caveat:** the stub API does not model `C_Timer` vs `OnUpdate` frame ordering, real controller hardware, or real event payloads.

---

## Appendix A: repro scenarios

All scenarios reuse the stubbed API from the repo's own tests: `arbitration-test.lua` for R1-R4 and S1, `crafting-test.lua` for R5.

<details>
<summary>R1: currency purchase (arbitration-test setup)</summary>

```lua
fresh({ "bagItemAdded", "itemObtained", "merchantBuy" }) -- Questing / Immersion shape
merchantOpen = true
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)
fire("MERCHANT_SHOW")
fire("ITEM_PUSH", 1, 0)
freeSlots = 19
fire("BAG_UPDATE_DELAYED")
-- no PLAYER_MONEY: paid with a non-gold currency
nextFrame(0.35) -- let any deferred intake flush
check("R1 total cues felt for the purchase", #fired, 1)
```
</details>

<details>
<summary>S1: gold purchase sanity</summary>

```lua
fresh({ "bagItemAdded", "itemObtained", "merchantBuy" })
merchantOpen = true
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)
fire("MERCHANT_SHOW")
fire("ITEM_PUSH", 1, 0)
freeSlots = 19
fire("BAG_UPDATE_DELAYED")
money = money - 100; fire("PLAYER_MONEY")
nextFrame(0.35)
check("S1 gold purchase: exactly one cue (merchantBuy)", #fired, 1)
```
</details>

<details>
<summary>R2: autoloot emptied before LOOT_OPENED</summary>

```lua
fresh({ "itemObtained" })
lootSlots = { { quality = 4 } } -- Epic -> gain 1.30
fire("LOOT_READY", true)
lootSlots = {}                  -- autoloot already took it
fire("LOOT_OPENED", true, false)
fire("ITEM_PUSH", 1, 0)
check("R2 itemObtained gain for an Epic", fired[1] and fired[1].override, 1.3)
```
</details>

<details>
<summary>R3b: cursor repair, money first</summary>

```lua
fresh({ "merchantBuy", "merchantRepair" })
merchantOpen = true
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)
fire("MERCHANT_SHOW")
repairMode = true
money = money - 500; fire("PLAYER_MONEY")    -- repair payment arrives first
check("R3b repair payment misread as merchantBuy", count("merchantBuy"), 0)
fire("UPDATE_INVENTORY_DURABILITY")
now = now + 0.4
repairMode = false
money = money - 100; fire("PLAYER_MONEY")    -- a real purchase
check("R3b repair felt once", count("merchantRepair"), 1)
check("R3b the purchase played merchantBuy", fired[#fired].id == "merchantBuy", true)
```
</details>

<details>
<summary>R4: shared bus layer (loads Core/Modes.lua too)</summary>

```lua
fresh({ "guildBankOpened", "interactionWindowClosed" })
Pulse:FireIfEnabled("guildBankOpened")         -- window bus prio 3, DOUBLE_TAP ~0.36 s
now = now + 0.2
Pulse:FireIfEnabled("interactionWindowClosed") -- window bus prio 1
check("R4 plays on the shared layer while DOUBLE_TAP still runs", #plays, 1)
```
</details>

<details>
<summary>R5: Casting page switch off (crafting-test setup)</summary>

```lua
-- Mirrors Core/Init.lua:186: HoldRolesIfEnabled returns early when the cue's gate is closed.
cues.gateCasting = false
Pulse.HoldRolesIfEnabled = function(_, id, roles)
	if id == "craftTexture" and not cues.gateCasting then return end
	Pulse.__bed = roles and roles.low
end
recipeProfession = Enum.Profession.Blacksmithing
startCraft(1234, 3.0)
check("R5 craft still claimed mid-craft", Pulse.IsCrafting(), false)
runCraft(3.0, 60)
check("R5 strikes played", strikes, 0)
```
</details>

---

## Appendix B: full patch

Against `8a4309d`. It covers B-01 to B-08 plus the two test updates; B-09 is proposed above but not included. Apply with `git apply`.

<details>
<summary>fixes.patch (10 files, +163 / −29)</summary>

```diff
diff --git a/PulseChecklist/tests/crafting-test.lua b/PulseChecklist/tests/crafting-test.lua
index 223cf77..0da943b 100755
--- a/PulseChecklist/tests/crafting-test.lua
+++ b/PulseChecklist/tests/crafting-test.lua
@@ -132,6 +132,10 @@ function Pulse:HoldRolesIfEnabled(_, roles)
 end
 
 local cues, settings = { craftTexture = true }, {}
+-- Mirrors Core/Init.lua: switched on AND its page gate (gateCasting) open.
+function Pulse:IsCueActive(id)
+	return (cues[id] and cues.gateCasting ~= false) and true or false
+end
 Pulse.Database = {
 	Get = function(_, key)
 		return key == "masterEnabled"
diff --git a/PulseChecklist/tests/harness.lua b/PulseChecklist/tests/harness.lua
index 7f1a8a3..71ed9cb 100755
--- a/PulseChecklist/tests/harness.lua
+++ b/PulseChecklist/tests/harness.lua
@@ -1838,7 +1838,7 @@ do
 		_G.PulseDB = mockDB
 		Pulse.Database:Init()
 
-		check("Option B: DB version migrated to 11", _G.PulseDB.version, 11)
+		check("Option B: DB version migrated to 12", _G.PulseDB.version, 12)
 		check(
 			"Swim migration: separateMotors migrated to 0",
 			_G.PulseDB.profiles.MyCustomBuild.triggerSettings.swimTexture.separateMotors,
diff --git a/PulseHaptics/Core/Arbiter.lua b/PulseHaptics/Core/Arbiter.lua
index 61e8f5f..5d077a9 100644
--- a/PulseHaptics/Core/Arbiter.lua
+++ b/PulseHaptics/Core/Arbiter.lua
@@ -95,10 +95,43 @@ function Arbiter:IsMerchantOpen()
 	return (MerchantFrame and MerchantFrame:IsShown()) and true or false
 end
 
--- True while a vendor is open and something that speaks for a purchase is live.
-function Arbiter:VendorOwnsIntake()
+-- A purchase paid in gold produces PLAYER_MONEY (merchantBuy) and a bag/ITEM_PUSH intake,
+-- in either order. A purchase paid in another currency produces only the intake. So the
+-- intake yields only when the owner actually spoke within VENDOR_SETTLE of it; otherwise it
+-- is deferred for that long and plays if the owner stayed silent.
+local VENDOR_SETTLE = 0.30 -- [measure] PLAYER_MONEY vs BAG_UPDATE_DELAYED spread
+local vendorOwnerAt = -100
+local vendorPendingCue, vendorPendingAt = false, 0
+
+-- Interaction.lua calls this on every gold debit at an open vendor, throttled or not.
+function Arbiter:VendorOwnerSpoke()
+	vendorOwnerAt = GetTime()
+end
+
+local function flushVendorIntake()
+	local cue = vendorPendingCue
+	vendorPendingCue = false
+	if cue and math.abs(vendorOwnerAt - vendorPendingAt) > VENDOR_SETTLE then
+		Pulse:FireIfEnabled(cue)
+	end
+end
+
+-- true = handled (the caller must not fire now). cueID is the caller's own cue, played
+-- later by the deferred flush if no gold debit shows up.
+function Arbiter:VendorOwnsIntake(cueID)
 	local episode = Pulse.Registry.EPISODES.vendor
-	return self:IsMerchantOpen() and anyLive(episode.owners)
+	if not (self:IsMerchantOpen() and anyLive(episode.owners)) then
+		return false
+	end
+	local now = GetTime()
+	if (now - vendorOwnerAt) <= VENDOR_SETTLE then
+		return true -- the gold debit already spoke for this item
+	end
+	if cueID and not vendorPendingCue then
+		vendorPendingCue, vendorPendingAt = cueID, now
+		C_Timer.After(VENDOR_SETTLE, flushVendorIntake) -- static function: no closure
+	end
+	return true
 end
 
 -- ── Loot episode ──────────────────────────────────────────────────────────────
@@ -218,9 +251,14 @@ function Arbiter:LootOpened(autoLoot)
 	if not issecretvalue(autoLoot) then
 		loot.autoLoot = autoLoot and true or false
 	end
+	local prevBest, prevQuest = loot.best, loot.quest
 	scan()
 	if loot.items + loot.coins > 0 or not loot.speaker then
 		loot.speaker = chooseSpeaker()
+	else
+		-- Autoloot emptied the window between LOOT_READY and LOOT_OPENED: keep what the
+		-- first scan saw, or the speaker plays at the default gain.
+		loot.best, loot.quest = prevBest, prevQuest
 	end
 end
 
@@ -283,7 +321,32 @@ end
 -- ── Buses ─────────────────────────────────────────────────────────────────────
 
 local DEFAULT_BUS_WINDOW = 0.15 -- [measure, §11]; covers ControllerUI's 20 Hz panel poll
-local busTime, busPriority, busLayer = {}, {}, {}
+local busTime, busPriority, busLayer, busUntil = {}, {}, {}, {}
+
+-- Approximate audible length of a discrete mode, cached per mode id. Continuous modes
+-- report 0 so the plain window applies.
+local modeLengthCache = {}
+local function modeLength(modeID)
+	local cached = modeLengthCache[modeID]
+	if cached then
+		return cached
+	end
+	local mode = modeID and Pulse.Modes and Pulse.Modes[modeID]
+	local total = 0
+	if mode and not mode.continuous and mode.steps then
+		for _, step in ipairs(mode.steps) do
+			if step.gap then
+				total = total + step.gap
+			else
+				total = total + (mode.baseDuration or 0) * (step.relDuration or 1)
+			end
+		end
+	end
+	if modeID then
+		modeLengthCache[modeID] = total
+	end
+	return total
+end
 
 -- Pre-seeded from the Registry once, so no key is ever created at event time.
 function Arbiter:SeedBuses()
@@ -291,6 +354,7 @@ function Arbiter:SeedBuses()
 		local bus = trigger.bus
 		if bus and not busLayer[bus] then
 			busTime[bus] = -100
+			busUntil[bus] = -100
 			busPriority[bus] = -1
 			busLayer[bus] = "bus:" .. bus
 		end
@@ -299,17 +363,22 @@ end
 
 -- Returns ok, layerName. ok = false when a more important cue on the same bus spoke inside
 -- the window. An unknown bus name degrades to "no bus" rather than erroring.
-function Arbiter:ClaimBus(bus, priority, window, fallbackLayer)
+-- A lower-priority cue is refused for the bus window OR while the higher cue's own
+-- pattern is still playing, whichever is longer: sharing one layer means a later PlayMode
+-- bumps the token and cancels whatever steps remain.
+function Arbiter:ClaimBus(bus, priority, window, fallbackLayer, modeID)
 	local layer = busLayer[bus]
 	if not layer then
 		return true, fallbackLayer
 	end
 	local now = GetTime()
 	priority = priority or 0
-	if (now - busTime[bus]) < (window or DEFAULT_BUS_WINDOW) and priority < busPriority[bus] then
+	local held = (now - busTime[bus]) < (window or DEFAULT_BUS_WINDOW) or now < busUntil[bus]
+	if held and priority < busPriority[bus] then
 		return false, nil
 	end
 	busTime[bus] = now
+	busUntil[bus] = now + modeLength(modeID)
 	busPriority[bus] = priority
 	return true, layer
 end
diff --git a/PulseHaptics/Core/Database.lua b/PulseHaptics/Core/Database.lua
index b0f79eb..1ccb784 100755
--- a/PulseHaptics/Core/Database.lua
+++ b/PulseHaptics/Core/Database.lua
@@ -24,7 +24,7 @@ local Database = {}
 Pulse.Database = Database
 
 local DB
-local DB_VERSION = 11
+local DB_VERSION = 12
 
 local GLOBAL_DEFAULTS = {
 	masterEnabled = true,
@@ -813,8 +813,8 @@ local PROFILE_TRIGGER_OVERRIDES = {
 		recipeLearned = true,
 		resurrectRequest = true,
 		rolePoll = true,
+		selfCastInstant = true,
 		selfCastInterrupted = true,
-
 		skillUp = true,
 		softEnemyChanged = true,
 		softFriendChanged = true,
@@ -1486,7 +1486,8 @@ function Database:Migrate()
 	if DB.version < 10 then
 		self:_MigrateSwimSettings()
 	end
-	if DB.version < 11 then
+	if DB.version < 12 then
+		-- Was `< 11`. Re-run for installs that already reached 11 without the v10 comparison.
 		self:_MigrateCuratedProfilesOptionB()
 	end
 	DB.version = DB_VERSION
@@ -1950,6 +1951,22 @@ local LEGACY_V8_OVERRIDES = {
 	},
 }
 
+-- Earlier shipped curated sets, each written as its difference from today's
+-- PROFILE_TRIGGER_OVERRIDES. A profile that still equals one of them was never edited by
+-- the player and can safely be re-seeded. Add one entry per future curation change.
+local HISTORIC_CURATED_DELTAS = {
+	-- DB_VERSION 9-10: selfCastInstant doubled with selfCastSucceeded (removed in f623a8a).
+	{
+		["Dungeon: Healer"] = { selfCastInstant = true },
+		["Dungeon: Caster"] = { selfCastInstant = true },
+		["Immersion: Caster"] = { selfCastInstant = true },
+	},
+	-- DB_VERSION 11: f623a8a also dropped Immersion: Ranged's only instant-ability cue.
+	{
+		["Immersion: Ranged"] = { selfCastInstant = false },
+	},
+}
+
 -- One-time, DB_VERSION 8 -> 9 (Option B): automatically updates untouched built-in profiles
 -- to their new curated trigger overrides while preserving any profiles modified by the user.
 function Database:_MigrateCuratedProfilesOptionB()
@@ -2053,6 +2070,32 @@ function Database:_MigrateCuratedProfilesOptionB()
 			return true
 		end
 
+		-- A2. Matches an earlier shipped curated set (today's set + a recorded delta)
+		for _, deltas in ipairs(HISTORIC_CURATED_DELTAS) do
+			local delta = deltas[name]
+			local matchesOld = delta ~= nil and currentOverrides ~= nil
+			for _, trigger in ipairs(matchesOld and Pulse.Triggers or {}) do
+				if not trigger.gate then
+					local currentVal = profile.triggers[trigger.id] and true or false
+					local expected = delta[trigger.id]
+					if expected == nil then
+						expected = currentOverrides[trigger.id]
+						if expected == nil then
+							expected = not currentOverrides.__exclusive and (trigger.default and true or false)
+								or false
+						end
+					end
+					if currentVal ~= (expected and true or false) then
+						matchesOld = false
+						break
+					end
+				end
+			end
+			if matchesOld then
+				return true
+			end
+		end
+
 		-- B. Matches legacy v8 overrides
 		local legacyOverrides = LEGACY_V8_OVERRIDES[name]
 		local matchesLegacy = true
@@ -2085,11 +2128,14 @@ function Database:_MigrateCuratedProfilesOptionB()
 		-- C. Matches pre-curation stock defaults (all trigger.default, e.g. v1-v6)
 		local matchesStock = true
 		for _, trigger in ipairs(Pulse.Triggers or {}) do
-			local currentVal = profile.triggers[trigger.id] and true or false
-			local expected = trigger.default and true or false
-			if currentVal ~= expected then
-				matchesStock = false
-				break
+			-- Same gate skip as A and B: a pre-Phase-2 profile has no gate keys at all.
+			if not trigger.gate then
+				local currentVal = profile.triggers[trigger.id] and true or false
+				local expected = trigger.default and true or false
+				if currentVal ~= expected then
+					matchesStock = false
+					break
+				end
 			end
 		end
 		if matchesStock then
diff --git a/PulseHaptics/Core/Init.lua b/PulseHaptics/Core/Init.lua
index 3c105e0..7072def 100755
--- a/PulseHaptics/Core/Init.lua
+++ b/PulseHaptics/Core/Init.lua
@@ -98,9 +98,18 @@ function Pulse:FireIfEnabled(triggerID, intensityOverride)
 		end
 	end
 
+	-- Resolved before the bus claim: the bus needs the pattern length, and a cue dialled
+	-- to zero must not claim a shared layer it will play nothing on.
+	local scale = self.Database:GetTriggerSetting(triggerID, "intensity", 1.0)
+	if type(scale) ~= "number" or scale <= 0 then
+		return false
+	end
+	local modeID = self.Database:GetTriggerMode(triggerID) or trigger.mode
+
 	local layerName = triggerID
 	if trigger.bus then
-		local ok, layer = self.Arbiter:ClaimBus(trigger.bus, trigger.busPriority, trigger.busWindow, triggerID)
+		local ok, layer =
+			self.Arbiter:ClaimBus(trigger.bus, trigger.busPriority, trigger.busWindow, triggerID, modeID)
 		if not ok then
 			return false
 		end
@@ -111,12 +120,6 @@ function Pulse:FireIfEnabled(triggerID, intensityOverride)
 		lastFireTime[triggerID] = now
 	end
 
-	-- Per-cue intensity (2026-09-15), replacing the old per-category scale. Seeded by
-	-- Database:ApplyDefaults, so it is an ordinary GetTriggerSetting read.
-	local scale = self.Database:GetTriggerSetting(triggerID, "intensity", 1.0)
-	-- A user-chosen mode override wins over the trigger's own Registry.lua default: same
-	-- trigger, same everything else, a different shape.
-	local modeID = self.Database:GetTriggerMode(triggerID) or trigger.mode
 	if self.debug then
 		print(("Pulse: %s fired -> %s (intensity %.2f)"):format(trigger.label or triggerID, modeID, scale))
 	end
diff --git a/PulseHaptics/Modules/Crafting.lua b/PulseHaptics/Modules/Crafting.lua
index ac5bf83..107a2a2 100755
--- a/PulseHaptics/Modules/Crafting.lua
+++ b/PulseHaptics/Modules/Crafting.lua
@@ -308,7 +308,7 @@ end
 local lastCraftSeen = 0
 
 function M:IsCrafting()
-	if not (Pulse.Database and Pulse.Database:Get("masterEnabled") and Pulse.Database:GetCue(CUE)) then
+	if not (Pulse.Database and Pulse.Database:Get("masterEnabled") and Pulse:IsCueActive(CUE)) then
 		return false
 	end
 	if active then
@@ -377,7 +377,7 @@ local function beginCraft(recipeSpellID, explicitProfessionID)
 	end
 
 	-- If the craftTexture cue itself is off, do not claim the craft or suppress castTexture
-	if not (Pulse.Database:Get("masterEnabled") and Pulse.Database:GetCue(CUE)) then
+	if not (Pulse.Database:Get("masterEnabled") and Pulse:IsCueActive(CUE)) then
 		active = false
 		return
 	end
@@ -419,6 +419,11 @@ function M:_PlayStrike()
 	if not work.mode then
 		return
 	end
+	-- Straight-to-engine path: re-check the gates, which can close mid-craft (a page switch
+	-- flipped in combat defers the module re-sync, not the gate itself).
+	if not Pulse:IsCueActive(CUE) then
+		return
+	end
 	local intensity = setting("intensity", 1.0)
 	local strength = clamp01(work.strike * gain * setting("strikeGain", 1.0) * intensity)
 	if strength <= 0 then
@@ -544,7 +549,7 @@ local function onActivity(result)
 end
 
 local function sync()
-	local wanted = (Pulse.Database:Get("masterEnabled") and Pulse.Database:GetCue(CUE)) or false
+	local wanted = (Pulse.Database:Get("masterEnabled") and Pulse:IsCueActive(CUE)) or false
 
 	-- CastActivity only registers its events while something wants them; keyed by consumer
 	-- so toggling casting cues does not unregister crafting, and disabling crafting clears its hold.
diff --git a/PulseHaptics/Modules/Interaction.lua b/PulseHaptics/Modules/Interaction.lua
index 48c52d2..20a51b7 100755
--- a/PulseHaptics/Modules/Interaction.lua
+++ b/PulseHaptics/Modules/Interaction.lua
@@ -122,6 +122,7 @@ local armedCost = 0
 local debitCost = 0 -- copper a personal repair will take; -1 = unknown (cursor repair)
 local debitUntil = 0
 local repairFiredAt = -100
+local cursorPaidAt = -100 -- a cursor repair's payment seen before its durability update
 
 -- One-frame deferred close (window bus, Core/Arbiter.lua): a close is dropped when an
 -- interaction SHOW arrives before the deferred close runs.
@@ -274,7 +275,7 @@ frame:SetScript("OnEvent", function(_, event, arg1)
 				fireRepairOnce(now)
 				if armed and not armedGuild then
 					debitCost, debitUntil = armedCost, now + DEBIT_WINDOW
-				elseif cursor then
+				elseif cursor and (now - cursorPaidAt) > DEBIT_WINDOW then
 					debitCost, debitUntil = -1, now + DEBIT_WINDOW
 				end
 				armedUntil = 0
@@ -290,6 +291,10 @@ frame:SetScript("OnEvent", function(_, event, arg1)
 				local now = GetTime()
 				if delta < 0 and now < debitUntil and (debitCost < 0 or -delta == debitCost) then
 					debitCost, debitUntil = 0, 0 -- the repair's own payment, already felt
+				elseif delta < 0 and type(InRepairMode) == "function" and InRepairMode() then
+					-- Repair cursor active: a debit now is a repair, never a purchase.
+					fireRepairOnce(now)
+					cursorPaidAt = now
 				elseif delta < 0 and now < armedUntil and not armedGuild and -delta == armedCost then
 					-- Money beat the durability update: this IS the repair.
 					fireRepairOnce(now)
@@ -297,6 +302,7 @@ frame:SetScript("OnEvent", function(_, event, arg1)
 				elseif delta > 0 then
 					Pulse:FireIfEnabled("merchantSell")
 				elseif delta < 0 then
+					Pulse.Arbiter:VendorOwnerSpoke()
 					Pulse:FireIfEnabled("merchantBuy")
 				end
 			end
diff --git a/PulseHaptics/Modules/Inventory.lua b/PulseHaptics/Modules/Inventory.lua
index 7eaa88c..d10e3a8 100755
--- a/PulseHaptics/Modules/Inventory.lua
+++ b/PulseHaptics/Modules/Inventory.lua
@@ -147,7 +147,7 @@ function M:OnEnable()
 				-- Owner rule (Registry.EPISODES): a purchase speaks through merchantBuy when
 				-- that cue is live, a loot window through its episode speaker. Otherwise
 				-- this tick is the only feedback for the item, so it plays.
-				if not Pulse.Arbiter:VendorOwnsIntake() and not Pulse.Arbiter:LootIntake() then
+				if not Pulse.Arbiter:VendorOwnsIntake("bagItemAdded") and not Pulse.Arbiter:LootIntake() then
 					Pulse:FireIfEnabled("bagItemAdded")
 				end
 			elseif free > lastFreeSlots then
diff --git a/PulseHaptics/Modules/Movement.lua b/PulseHaptics/Modules/Movement.lua
index b0d8f54..733249b 100755
--- a/PulseHaptics/Modules/Movement.lua
+++ b/PulseHaptics/Modules/Movement.lua
@@ -49,7 +49,8 @@ end
 local OCEAN_PATTERNS = {
 	"%f[%a]seas?%f[%A]",
 	"%f[%a]oceans?%f[%A]",
-	"%f[%a]coastal?%f[%A]",
+	"%f[%a]coasts?%f[%A]",
+	"%f[%a]coastal%f[%A]",
 	"%f[%a]shores?%f[%A]",
 	"%f[%a]bays?%f[%A]",
 	"%f[%a]coves?%f[%A]",
diff --git a/PulseHaptics/Modules/World.lua b/PulseHaptics/Modules/World.lua
index 7216af2..1a86cc0 100755
--- a/PulseHaptics/Modules/World.lua
+++ b/PulseHaptics/Modules/World.lua
@@ -156,7 +156,7 @@ function M:_WatchLoot()
 		elseif event == "LOOT_CLOSED" then
 			Arbiter:LootClosed()
 		elseif event == "ITEM_PUSH" then
-			if not Arbiter:VendorOwnsIntake() and not Arbiter:LootIntake() then
+			if not Arbiter:VendorOwnsIntake("itemObtained") and not Arbiter:LootIntake() then
 				Pulse:FireIfEnabled("itemObtained")
 			end
 		elseif event == "CHAT_MSG_LOOT" then
```
</details>

# Pulse Regression Investigation: Damage/Parry/Block Detection and Casting Texture

## Summary

Two separate regressions appear likely rather than a single broken haptic-engine problem:

- **Damage taken / parry / block detection:** the current combat-text implementation appears stale relative to the current Blizzard combat-text API.
- **Casting texture:** the existing implementation is now fragile because it independently watches raw cast events, depends on `UnitCastingInfo()` timing values, has secret-value guards, and can be suppressed by crafting state.

The important point is that these are likely **event/state-detection regressions**, not fundamental failures of the Pulse haptic engine.

---

# 1. Damage Taken / Parry / Block

## Current implementation

The current `Combat.lua` implementation uses:

```lua
textFrame:SetScript("OnEvent", function(_, event, messageType)
```

and registers:

```lua
textFrame:RegisterEvent("COMBAT_TEXT_UPDATE")
```

The code treats `messageType` as the combat-text payload.

## Why this is suspicious

Current Blizzard combat-text code handles `COMBAT_TEXT_UPDATE` by retrieving the current event information through:

```lua
C_CombatText.GetCurrentEventInfo()
```

Blizzard's implementation conceptually does:

```lua
elseif (event == "COMBAT_TEXT_UPDATE") then
    data, arg3, arg4 = C_CombatText.GetCurrentEventInfo();
    messageType = arg1;
```

The important distinction is:

- the event argument identifies the message type
- the additional combat-text information is obtained through `C_CombatText.GetCurrentEventInfo()`

Pulse currently does not use `C_CombatText.GetCurrentEventInfo()`.

## Relevant combat-text message types

The Blizzard combat-text system still exposes message types including:

- `DAMAGE`
- `DAMAGE_CRIT`
- `BLOCK`
- `SPELL_BLOCK`
- `PARRY`
- `DODGE`

Therefore, these cues do not necessarily need to be abandoned.

## Likely issue

The existing implementation was built around the older combat-text event behavior and does not fully follow the current Blizzard implementation.

That makes it a strong candidate for why damage/parry/block cues stopped working.

## Recommended investigation

First update/test the combat-text handler so it follows the current API pattern:

```lua
textFrame:SetScript("OnEvent", function(_, event, messageType)
    local desc1, desc2 = C_CombatText.GetCurrentEventInfo()

    -- existing messageType handling
end)
```

The exact additional values required by Pulse should be determined from the existing cue logic.

The important part is to retrieve current combat-text information through the modern API rather than relying entirely on the old event payload assumptions.

---

# 2. Casting Texture

## Current implementation

The casting texture independently registers:

```lua
castFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
castFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
```

The cast timing is then obtained through:

```lua
local _, _, _, startTimeMs, endTimeMs = UnitCastingInfo("player")
```

The implementation protects against secret values with logic equivalent to:

```lua
if not issecretvalue(startTimeMs)
    and not issecretvalue(endTimeMs)
then
    ...
end
```

## Why this can silently fail

Current Midnight APIs can return protected/secret values for cast information in restricted situations.

`UnitCastingInfo()` is subject to secret-value restrictions.

Therefore this condition can simply evaluate false:

```lua
if not issecretvalue(startTimeMs) and not issecretvalue(endTimeMs)
```

When that happens, the cast texture does not call the haptic hold function.

There may be no Lua error at all.

This would produce exactly the symptom:

> "Casting texture stopped working."

while the addon itself otherwise continues functioning.

---

# 3. There is also a duplicated casting architecture

Pulse now has:

```text
Core/CastActivity.lua
```

which represents the newer centralized casting-state system.

But `Combat.lua` still contains its own independent `castFrame` and raw:

```text
UNIT_SPELLCAST_START
UNIT_SPELLCAST_CHANNEL_START
```

handling.

That means there are effectively two casting systems:

1. **CastActivity**
2. **Combat.lua castTexture**

The newer `Casting.lua` is described as a thin consumer of `Core/CastActivity.lua`.

The old `castTexture` implementation, however, still performs its own raw event/timing detection.

This is an architectural mismatch worth addressing.

---

# 4. Crafting may also suppress the casting texture

The casting texture contains an early return equivalent to:

```lua
if Pulse.IsCrafting and Pulse.IsCrafting() then return end
```

This occurs before the casting behavior proceeds.

Therefore, if the crafting state becomes stuck or incorrectly remains true, the casting texture can be completely suppressed.

This is another plausible regression introduced as crafting/cast-state handling was expanded.

## Quick diagnostic

Temporarily remove or bypass:

```lua
if Pulse.IsCrafting and Pulse.IsCrafting() then return end
```

If casting haptics return, the problem is the crafting-state suppression rather than the cast event itself.

---

# 5. The most useful diagnostic test for casting

Temporarily bypass the timing calculation and test only whether the cast event reaches the haptic engine.

Conceptually:

```lua
if isCasting then
    Pulse:HoldIfEnabled("castTexture", 0.1, 0.3)
end
```

If this works, then:

- the cast event is arriving
- the haptic engine is working
- the cue is working

and the problem is specifically in the `UnitCastingInfo()` timing/secrecy path.

If it does not work, investigate:

- event registration
- `Pulse.IsCrafting()`
- cue enable/state
- CastActivity interaction
- downstream haptic handling

---

# 6. Do Not Switch to COMBAT_LOG_EVENT_UNFILTERED

Going back to:

```text
COMBAT_LOG_EVENT_UNFILTERED
```

is not the appropriate repair path for Midnight.

Midnight restricts addon access to combat-log events.

The existing Blizzard combat-text mechanism is therefore much more relevant for damage/parry/block detection.

---

# 7. Likely regression chain from the project history

The Git progression suggests a plausible sequence:

```text
Original Pulse
    ↓
COMBAT_TEXT_UPDATE based damage/combat detection
    ↓
CastActivity introduced
    ↓
Casting state becomes centralized
    ↓
Crafting state added
    ↓
Cast texture still independently watches raw cast events
    ↓
Midnight secret-value hardening added
    ↓
UnitCastingInfo timing values become guarded
    ↓
Current implementation can silently suppress cast texture
```

At the same time:

```text
Old COMBAT_TEXT_UPDATE assumptions
    ↓
Midnight / current Blizzard combat-text implementation changes
    ↓
Pulse continues using older retrieval pattern
    ↓
Damage / parry / block cues stop firing correctly
```

This would explain why two seemingly unrelated cue families stopped working around the same general period.

---

# 8. Recommended repair order

## A. Combat text

Bring `Combat.lua`'s combat-text handling in line with Blizzard's current implementation.

Specifically:

1. Continue listening for `COMBAT_TEXT_UPDATE`.
2. Obtain current combat-text information using `C_CombatText.GetCurrentEventInfo()`.
3. Preserve the existing Pulse message-type mapping.
4. Test:
   - damage taken
   - critical damage taken
   - parry
   - block
   - spell block
   - dodge if currently supported.

Do not redesign the cue system yet.

## B. Casting texture

Test the casting texture in three progressively simpler states:

### Test 1 — existing implementation

Confirm whether the current raw cast event fires.

### Test 2 — bypass timing

Temporarily remove the `startTimeMs/endTimeMs` dependency.

If haptics return, the timing/secret-value path is the regression.

### Test 3 — bypass crafting suppression

Temporarily remove:

```lua
if Pulse.IsCrafting and Pulse.IsCrafting() then return end
```

If that restores casting, investigate the crafting state machine.

---

# 9. Longer-term architecture

The casting texture should probably consume the existing `CastActivity` state rather than independently reconstructing cast state from raw events.

A cleaner architecture would be:

```text
UNIT_SPELLCAST_*
        ↓
   CastActivity
        ↓
   casting state
        ↓
   Casting.lua / castTexture
        ↓
   Pulse haptic engine
```

instead of:

```text
UNIT_SPELLCAST_*
        ├── CastActivity
        │      ↓
        │   Casting.lua
        │
        └── Combat.lua castTexture
               ↓
        UnitCastingInfo()
               ↓
        haptic engine
```

The first design gives one source of truth for casting state and reduces the number of Midnight API restrictions that individual consumers need to understand.

However, this should be done after confirming the immediate regression. A targeted repair is preferable to another broad rewrite.

---

# 10. Bottom line

The strongest current hypotheses are:

### Damage / parry / block

**Likely stale combat-text handling.**

Pulse listens to `COMBAT_TEXT_UPDATE`, but its implementation does not retrieve the current combat-text event information through the modern `C_CombatText.GetCurrentEventInfo()` path used by Blizzard.

### Casting texture

**Likely a combination of duplicated cast-state handling and Midnight secret-value restrictions.**

The particularly suspicious path is:

```lua
UnitCastingInfo("player")
        ↓
startTimeMs / endTimeMs
        ↓
issecretvalue()
        ↓
timing logic
        ↓
HoldIfEnabled()
```

If those timing values are secret, the texture can simply do nothing.

A second independent suppression point is:

```lua
Pulse.IsCrafting()
```

Finally, the existence of `CastActivity` means the old `Combat.lua` cast detector is now architecturally redundant and potentially fragile.

---

## Sources / API references

The relevant current Blizzard implementation uses `C_CombatText.GetCurrentEventInfo()` when handling `COMBAT_TEXT_UPDATE`.

Current WoW API documentation also documents `UnitCastingInfo()` and the secret-value restrictions affecting cast information.

These findings should be treated as **investigation hypotheses until verified in the actual running client**. The next step should be a minimal diagnostic patch rather than a broad engine rewrite.

# Pulse --- Updated Crafting / Casting Regression Assessment

## Summary

Crafting should be treated as a specialized form of casting, not as
something that exists outside the casting system.

The current Pulse code appears to have **two competing casting
architectures**:

1.  The newer `Core/CastActivity.lua` system, which explicitly models
    crafting as a cast.
2.  The older `Modules/Combat.lua` cast-texture system, which
    independently detects casts and suppresses its texture whenever
    `Pulse.IsCrafting()` returns true.

This makes the crafting system itself less suspicious than the
interaction between the two systems.

------------------------------------------------------------------------

## Key finding

`Core/CastActivity.lua` already understands crafting as a cast.

The newer architecture handles:

-   `TRADE_SKILL_CRAFT_BEGIN`
-   `UNIT_SPELLCAST_START`
-   craft detection
-   `CRAFT_CAST_START`
-   `CRAFT_COMPLETE`
-   `CRAFT_STOPPED`

Conceptually:

``` text
CastActivity
    ├── normal spell cast
    ├── channel
    └── crafting
```

This is the correct general model.

**Crafting is a specialized cast.**

------------------------------------------------------------------------

## The suspicious legacy path

`Modules/Combat.lua` still maintains an independent casting
implementation.

It listens directly for events such as:

-   `UNIT_SPELLCAST_START`
-   `UNIT_SPELLCAST_CHANNEL_START`
-   `UNIT_SPELLCAST_STOP`
-   `UNIT_SPELLCAST_CHANNEL_STOP`
-   `UNIT_SPELLCAST_FAILED`
-   `UNIT_SPELLCAST_INTERRUPTED`

It also maintains its own `isCasting` / `isChanneling` state and drives
the casting texture.

This means Pulse currently has two systems with overlapping
responsibility for casting state.

------------------------------------------------------------------------

## Critical interaction

The older cast-texture path contains logic equivalent to:

``` lua
if Pulse.IsCrafting and Pulse.IsCrafting() then
    return
end
```

This means that when crafting is active:

``` text
Craft begins
    ↓
Pulse.IsCrafting() == true
    ↓
Combat castTick()
    ↓
return
    ↓
normal cast texture is suppressed
```

This is intentional behavior in the current implementation, but it
creates a fragile dependency between the crafting state and the generic
casting texture.

------------------------------------------------------------------------

## Why this matters

If `Pulse.IsCrafting()` becomes stuck or incorrectly remains true after
a craft, the same suppression mechanism can affect ordinary spell casts.

The failure mode becomes:

``` text
Craft finishes
    ↓
crafting state fails to clear
    ↓
Pulse.IsCrafting() == true
    ↓
normal spell cast starts
    ↓
cast texture is suppressed
```

That would make an apparently unrelated casting-texture regression
actually originate from stale crafting state.

------------------------------------------------------------------------

## Updated diagnosis

The current evidence does **not** support saying:

> "The crafting function is fundamentally broken."

A better diagnosis is:

> **The crafting/casting relationship is architecturally
> overcomplicated, and the legacy cast-texture suppression may be
> responsible for the regression.**

### Current investigation priorities

  -----------------------------------------------------------------------
  Priority                Area                    Assessment
  ----------------------- ----------------------- -----------------------
  1                       Duplicate casting       High concern
                          systems                 

  2                       `Pulse.IsCrafting()`    High-value diagnostic
                          stale/incorrect state   

  3                       Explicit craft          Definitely capable of
                          suppression in          suppressing texture
                          `Combat.lua`            

  4                       Secret                  Possible independent
                          `UnitCastingInfo()`     issue
                          timing values           

  5                       Fundamental             Currently less
                          CraftActivity design    suspicious
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## Immediate diagnostic

Do **not** redesign the whole system yet.

Temporarily bypass the casting suppression:

``` lua
if Pulse.IsCrafting and Pulse.IsCrafting() then
    return
end
```

Then test:

1.  Normal spell cast.
2.  Crafting.
3.  Normal spell cast immediately after crafting.
4.  Channel.
5.  Interrupted cast.

### Interpretation

If normal casting texture returns after bypassing the check, the
investigation should focus on the crafting-state interaction rather than
the basic casting texture implementation.

If normal casting remains broken, investigate the separate
`UnitCastingInfo()` / timing path next.

------------------------------------------------------------------------

## Recommended architecture

The eventual architecture should avoid two independent systems deciding
whether the player is casting.

Prefer:

``` text
                    CastActivity
                         │
              ┌──────────┴──────────┐
              │                     │
        Normal cast             Craft cast
              │                     │
        cast texture          craft texture
```

rather than:

``` text
Combat.lua
    │
    ├── independently detects casts
    │
    └── asks Crafting.lua
             │
             └── "Should I suppress myself?"
```

The important distinction is:

**Do not make crafting stop being a cast.**

Instead:

**Make crafting a classified type of cast.**

------------------------------------------------------------------------

## Recommended implementation direction

### Short term

-   Keep the current crafting implementation.
-   Test the `Pulse.IsCrafting()` suppression first.
-   Verify that crafting state reliably clears.
-   Verify normal casting immediately after crafting.
-   Do not rewrite the haptic engine yet.

### Medium term

Move casting-state ownership toward `CastActivity`.

`Combat.lua` should not independently maintain a second authoritative
casting state if `CastActivity` already provides it.

### Long term

Use `CastActivity` as the source of truth:

``` text
CastActivity
    │
    ├── normal cast → casting texture
    ├── channel → channel texture
    └── craft cast → crafting texture
```

The underlying oscillator/texture implementation can still be shared
when appropriate.

------------------------------------------------------------------------

## Important conclusion

The fact that **crafting counts as a cast** makes the existing
`IsCrafting()` suppression more suspicious, not less.

The likely architectural problem is not:

> Crafting should be removed from casting.

It is:

> **Crafting and normal casting are being represented twice, and one
> system suppresses the other.**

The first practical test should therefore be the `IsCrafting()` early
return and the lifecycle of the crafting `active` state.

No broad engine rewrite is justified until that test is performed.

# Pulse Minimap Button — Forbidden Action and Rendering Investigation

**Archive examined:** `Pulse 2.zip`  
**Primary files examined:**  
- `Pulse/UI/Minimap.lua`
- `Pulse/Core/Init.lua`
- `Pulse/Core/Database.lua`

## 1. Executive Summary

The current minimap implementation contains two distinct areas of concern.

### Forbidden-action message

The strongest code-level suspect is **not the minimap button construction itself**. The right-click handler ultimately changes the global `masterEnabled` database value:

```lua
Pulse.Database:Set("masterEnabled", not current)
```

`Database:Set()` immediately notifies every listener registered for that global key. `Pulse:BindFrame()` registers every affected watcher against the same `masterEnabled` notification, and each watcher can synchronously call `UnregisterAllEvents()` followed by multiple `RegisterEvent()` / `RegisterUnitEvent()` calls.

Therefore the actual execution chain is:

```text
Minimap right-click
    ↓
toggleMasterEnabled()
    ↓
Database:Set("masterEnabled", ...)
    ↓
notify(globalListeners, "masterEnabled")
    ↓
many registered sync() callbacks
    ↓
UnregisterAllEvents()
    ↓
RegisterEvent()/RegisterUnitEvent()
```

This is a significantly more plausible place to investigate the `ADDON_ACTION_FORBIDDEN` message than the simple right-click itself.

However, **the code alone does not prove that this chain is the protected call producing the error**. The exact protected function should be obtained from the client's `ADDON_ACTION_FORBIDDEN` report/taint log.

### Minimap icon rendering

There is a definite geometry problem in the minimap artwork:

```lua
btn:SetSize(32, 32)
```

but the tracking border is:

```lua
border:SetSize(53, 53)
border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
```

A 53×53 texture is therefore positioned from the button's top-left corner rather than centered over the 32×32 button. This is highly likely to produce incorrect positioning, clipping, or an oversized/offset minimap border.

The icon itself is only 18×18 and is centered correctly, so the border construction is the clearest concrete explanation for the reported visual problem.

---

# 2. Right-Click Execution Path

The minimap button is created as a normal addon button:

```lua
local btn = CreateFrame("Button", "PulseMinimapButton", UIParent)
btn:SetSize(32, 32)
```

`Pulse/UI/Minimap.lua`, lines 123–124.

It registers for clicks:

```lua
btn:RegisterForClicks("anyUp")
```

and its click handler contains:

```lua
btn:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        toggleMasterEnabled(self)
    else
        ...
    end
end)
```

`Pulse/UI/Minimap.lua`, approximately lines 191 onward.

The right-click therefore does not directly call a haptic API or a secure action. It calls `toggleMasterEnabled()`.

That function performs:

```lua
local current = Pulse.Database:Get("masterEnabled")
Pulse.Database:Set("masterEnabled", not current)
```

`Pulse/UI/Minimap.lua`, lines 104–105.

This distinction is important: the minimap button's immediate action is simply a database change.

---

# 3. The Master Toggle Has a Large Synchronous Side Effect

The code itself explicitly acknowledges the scale of this operation:

```lua
-- In-combat protection: changing master state unregisters/registers events across 22 modules
```

`Pulse/UI/Minimap.lua`, line 91.

The function checks:

```lua
if InCombatLockdown and InCombatLockdown() then
    ...
    return
end
```

before changing the value.

`Pulse/UI/Minimap.lua`, lines 92–102.

This is good defensive behavior for combat lockdown, but it does not eliminate possible taint issues outside combat.

The important part is what `Database:Set()` does.

---

# 4. `Database:Set()` Immediately Notifies Global Listeners

`Pulse/Core/Database.lua` implements the global setting change as follows:

```lua
DB[key] = value
...
notify(globalListeners, key)
```

`Pulse/Core/Database.lua`, lines 1563–1570.

There is no deferred callback here.

Therefore:

```lua
Pulse.Database:Set("masterEnabled", ...)
```

does not merely change SavedVariables state.

It immediately invokes all registered listeners for `masterEnabled`.

This is significant because `masterEnabled` has deliberately been made a global synchronization mechanism for the event watchers.

---

# 5. `Pulse:BindFrame()` Subscribes Watchers to `masterEnabled`

In `Pulse/Core/Init.lua`:

```lua
function Pulse:BindFrame(cueIDs, sync)
    for _, cueID in ipairs(cueIDs) do
        self.Database:OnCueChanged(cueID, sync)
    end
    self.Database:OnGlobalChanged("masterEnabled", sync)
    sync()
end
```

`Pulse/Core/Init.lua`, lines 283–289.

The critical line is:

```lua
self.Database:OnGlobalChanged("masterEnabled", sync)
```

This means each frame using `Pulse:BindFrame()` receives the master-enabled change.

The generic watcher then implements:

```lua
local function sync()
    frame:UnregisterAllEvents()

    if not Pulse.Database:Get("masterEnabled") then
        return
    end

    if not Pulse.Database:GetCue(trigger.id) then
        return
    end

    for _, event in ipairs(trigger.events) do
        if trigger.unit then
            frame:RegisterUnitEvent(event, trigger.unit)
        else
            frame:RegisterEvent(event)
        end
    end
end
```

`Pulse/Core/Init.lua`, lines 297–312.

Consequently, switching Pulse **on** causes each relevant watcher to:

1. unregister its existing events;
2. read `masterEnabled`;
3. check its cue;
4. register its events again.

This occurs as part of the same notification initiated by the minimap click.

---

# 6. Why ON and OFF Can Behave Differently

The reported symptom is:

> Right-click to activate haptics → forbidden-action message.  
> Right-click to deactivate haptics → no error.

The source code provides a reasonable explanation for why the two directions are not equivalent.

When turning Pulse **off**, the generic synchronization path effectively becomes:

```lua
frame:UnregisterAllEvents()

if not Pulse.Database:Get("masterEnabled") then
    return
end
```

So after unregistering, the function exits.

When turning Pulse **on**, it proceeds into:

```lua
for _, event in ipairs(trigger.events) do
    ...
    frame:RegisterUnitEvent(...)
    ...
    frame:RegisterEvent(...)
end
```

Thus the ON transition performs substantially more work.

This does **not prove** that `RegisterEvent()` or `RegisterUnitEvent()` is the forbidden operation. It does establish that the ON path has additional operations that the OFF path does not.

That asymmetry makes the master-enable synchronization chain a strong investigation target.

---

# 7. The Error Should Not Be Attributed to the Minimap Button Without the Protected Function

WoW's `ADDON_ACTION_FORBIDDEN` event reports the addon involved and the protected function that was called. Importantly, the addon name reported does not necessarily identify the original source of taint; the documentation explicitly notes that it can represent the addon last involved in the execution path.

Taint can propagate through execution paths, so seeing Pulse named in an error does not by itself prove that the minimap button is the originating problem. Blizzard UI/forum discussions also document cases where addons are blamed because their code became part of a tainted execution path.

Therefore the correct conclusion from the source code is:

> **The master-toggle notification chain is a strong suspect, but the exact protected function must be obtained from the client's taint/error report before calling it the confirmed cause.**

This distinction matters.

---

# 8. The Minimap Button Is Not Obviously a Secure Action Button

The button is created with:

```lua
CreateFrame("Button", "PulseMinimapButton", UIParent)
```

and does not inherit `SecureActionButtonTemplate`.

There is also no visible `SetAttribute("type", ...)` or spell/action attribute configuration in the minimap implementation.

The click handler simply invokes Lua code.

Therefore there is no obvious direct secure-action implementation in `UI/Minimap.lua` that would explain the forbidden-action message by itself.

This makes the downstream `masterEnabled` synchronization path more interesting than the button's basic creation.

---

# 9. LibDataBroker Duplicates the Same Toggle Path

Pulse also exposes a LibDataBroker launcher:

```lua
ldbObj = ldb:NewDataObject("Pulse", {
    type = "launcher",
    text = "Pulse",
    icon = "Interface\\Icons\\Spell_Nature_WispSplode",
    OnClick = function(_, button)
        if button == "RightButton" then
            toggleMasterEnabled(nil)
        else
            ...
        end
    end,
```

`Pulse/UI/Minimap.lua`, lines 271–285.

The important point is that the LibDataBroker button and the physical minimap button both call the **same** `toggleMasterEnabled()` function.

Therefore the problem, if reproduced through another LibDataBroker display, should not depend on the physical minimap button's frame construction.

That gives a useful diagnostic distinction:

- Error only from the physical Pulse minimap button → investigate button/frame interaction.
- Error from another LDB display of Pulse as well → strongly points toward `toggleMasterEnabled()` and the database notification chain.

---

# 10. Login-Time Initialization

The minimap button is initialized during addon startup:

```lua
if Pulse.UI.Minimap and Pulse.UI.Minimap.Init then
    Pulse.UI.Minimap:Init()
end
```

`Pulse/Core/Init.lua`, lines 355–356.

`MinimapButton:Init()` then:

```lua
initLDB()
...
createMinimapButton()
self:Refresh()
```

`Pulse/UI/Minimap.lua`, lines 320–330.

It also creates a `PLAYER_ENTERING_WORLD` listener:

```lua
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:SetScript("OnEvent", function(frame)
    frame:UnregisterAllEvents()
    MinimapButton:Refresh()
end)
```

`Pulse/UI/Minimap.lua`, lines 336–342.

This is relevant to the observation that the icon appears at login.

However, `PLAYER_ENTERING_WORLD` only calls `Refresh()`. It does not itself toggle `masterEnabled`.

So there is no direct evidence in this file that login-time refresh is responsible for the forbidden-action message.

---

# 11. Concrete Minimap Rendering Problem

The rendering issue is much easier to identify from the source.

The button is:

```lua
btn:SetSize(32, 32)
```

`Pulse/UI/Minimap.lua`, line 124.

The background is:

```lua
bg:SetSize(20, 20)
bg:SetPoint("CENTER", btn, "CENTER", 0, 0)
```

Lines 146–149.

The actual icon is:

```lua
icon:SetSize(18, 18)
icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
```

Lines 154–158.

Those are internally consistent.

The tracking border, however, is:

```lua
border:SetSize(53, 53)
border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
```

Lines 177–180.

This is not centered.

The geometry is effectively:

```text
53 × 53 border
┌─────────────────────────────┐
│                             │
│   ┌─────────────────────┐   │
│   │      32 × 32        │   │
│   │       button        │   │
│   │                     │   │
│   └─────────────────────┘   │
│                             │
└─────────────────────────────┘
```

The border begins at the button's top-left but is considerably larger than the button.

A centered 53×53 border would instead use:

```lua
border:SetPoint("CENTER", btn, "CENTER")
```

That would at least make the border geometrically symmetrical around the button.

### Important qualification

I would not state that changing the anchor alone guarantees a perfect icon.

The code also combines:

- an 18×18 icon;
- `SetTexCoord(0.08, 0.92, 0.08, 0.92)`;
- a portrait alpha mask;
- a 20×20 minimap background;
- a 53×53 Blizzard tracking border;
- a 22×22 Blizzard zoom-button highlight.

So the entire visual construction is somewhat heterogeneous.

Nevertheless, the **53×53 border anchored at the button's top-left is an objective layout error**, independent of subjective appearance.

---

# 12. The Icon Mask Is Another Potential Visual Complication

The icon additionally uses:

```lua
icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
```

when available.

`Pulse/UI/Minimap.lua`, lines 161–163.

The fallback creates the same mask texture manually and applies it to the icon.

There is nothing inherently wrong with using a mask, but it adds another transformation layer to a very small 18×18 icon.

Because the icon is already using:

```lua
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
```

the final appearance is affected by both cropping and masking.

This is not enough evidence to call the mask broken. It is simply a secondary area worth simplifying if the icon still looks wrong after fixing the border geometry.

---

# 13. The Button's Parent Is Not the Obvious Problem

The button is deliberately parented to:

```lua
CreateFrame("Button", "PulseMinimapButton", UIParent)
```

rather than `Minimap`.

The source comment says this is intended to avoid inheriting:

> MinimapCluster / EditMode / Gamepad context restrictions

`Pulse/UI/Minimap.lua`, lines 122–123.

The button is then positioned relative to Minimap:

```lua
buttonFrame:SetPoint("CENTER", Minimap, "CENTER", x, y)
```

in `updateButtonPosition()`.

This is a reasonable design distinction:

```text
parent = UIParent
position relative to = Minimap
```

It means the button does not need to be a child of the Minimap simply to appear around it.

There is therefore no strong evidence from this code that `UIParent` is responsible for either reported problem.

---

# 14. Overall Assessment

## Confirmed from the code

### A. The master toggle has a large synchronous fan-out

`masterEnabled` is changed by the minimap click, and `Database:Set()` immediately notifies its listeners.

`Pulse:BindFrame()` subscribes event watchers to that notification.

Those watchers unregister and, when enabling, re-register events.

This is a real architectural chain in the current implementation.

### B. ON and OFF have different work profiles

OFF:

```text
UnregisterAllEvents()
→ return
```

ON:

```text
UnregisterAllEvents()
→ RegisterEvent/RegisterUnitEvent repeatedly
```

This matches the reported asymmetry sufficiently well to make the path worth investigating.

### C. The minimap border has objectively incorrect geometry

A 53×53 border is attached at the top-left of a 32×32 button instead of being centered.

That is the clearest source-level explanation for the rendering problem.

---

# 15. What Is Not Proven Yet

The current source inspection does **not** establish that:

- `RegisterEvent()` itself is the forbidden function;
- `RegisterUnitEvent()` itself is the forbidden function;
- the minimap button is tainted;
- LibDataBroker is responsible;
- `UIParent` is responsible;
- the tracking-border texture itself is invalid;
- the mask itself is broken.

Those would require runtime evidence.

In particular, `ADDON_ACTION_FORBIDDEN` should not be reverse-engineered solely from the fact that the error occurs after a click. WoW's taint system can involve a longer execution path, and the event's reported addon can be the addon last involved in that path rather than the original source.

---

# 16. Recommended Diagnostic Sequence

The cleanest investigation is therefore:

### Test 1 — bypass the database toggle

Temporarily make the minimap right-click only print a message.

If the forbidden-action message disappears, the minimap button's basic click path is probably not the problem.

### Test 2 — call the database toggle from a non-minimap route

Use an equivalent `/pulse` command or another existing UI control to toggle `masterEnabled`.

If that produces the same forbidden action, the minimap button can be largely ruled out.

### Test 3 — inspect the exact protected function

Enable WoW's taint logging:

```text
/console taintLog 1
/reload
```

Reproduce the ON transition and inspect `Logs/taint.log`.

The key piece of evidence is the protected function named by the report. The `ADDON_ACTION_FORBIDDEN` event specifically exposes the protected function that was called.

### Test 4 — compare ON versus OFF

If ON produces the error and OFF does not, compare the exact operations performed by the `sync()` callbacks.

The current source already shows that ON causes event registrations while OFF does not.

---

# 17. Suggested Code-Level Direction

The minimap rendering issue can be fixed independently.

The obvious first correction is:

```lua
border:SetPoint("CENTER", btn, "CENTER")
```

rather than:

```lua
border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
```

The forbidden-action issue should **not** be "fixed" by arbitrarily removing the master toggle or disabling event registration until the protected function is known.

The more appropriate architectural question is whether changing the global master switch should synchronously reconfigure a large number of event watchers directly inside the click execution path.

A safer design could eventually separate:

```text
user interaction
      ↓
request master-state change
      ↓
state changes
      ↓
event-watcher synchronization
```

rather than having the click immediately fan out through every watcher.

That should be done carefully, however, because the existing synchronization mechanism is functional architecture rather than an obvious coding error.

---

# Conclusion

The **minimap visual problem has a concrete source-level defect**: the 53×53 tracking border is anchored at the top-left of a 32×32 button rather than centered.

The **forbidden-action problem is more likely downstream of the right-click than in the minimap button construction itself**. The critical path is:

```text
PulseMinimapButton.OnClick
        ↓
toggleMasterEnabled()
        ↓
Database:Set("masterEnabled")
        ↓
notify(globalListeners, "masterEnabled")
        ↓
many BindFrame() sync callbacks
        ↓
UnregisterAllEvents()
        ↓
when enabling:
RegisterEvent() / RegisterUnitEvent()
```

The source therefore gives a strong, testable hypothesis for why **ON** can produce an error while **OFF** does not, but the exact cause should not be declared proven until the protected function from the WoW taint report is known.

The two issues should be treated separately:

**Rendering:** there is an identifiable layout bug in `Minimap.lua`.

**Forbidden action:** there is a suspicious synchronous master-toggle/event-registration path that requires runtime taint evidence before a definitive diagnosis.
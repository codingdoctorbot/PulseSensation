# Pulse QA In-Game Test Plan

This document outlines the step-by-step verification procedures for testing the **PulseSensation** haptics suite in World of Warcraft `_classic_beta_` ("WoW Forever").

---

## 1. Crafting & Gathering Verification

### Test 1.1: Production Crafting (TradeSkill Window)
* **Objective**: Confirm that crafting window crafts engage `craftTexture`, produce the proper rhythmic cadence, land the final strike, and cleanly suppress generic `castTexture`.
* **Prerequisites**: A character with any production profession (Blacksmithing, Cooking, Leatherworking, Tailoring, Alchemy, or Smelting at a forge).
* **Steps**:
  1. Open the profession window (e.g., Cooking or Blacksmithing).
  2. Craft a single item with a multi-second cast time (e.g., *Rough Sharpening Stone* or *Roasted Boar Meat*).
  3. Observe haptic feel:
     - Continuous low-frequency rumble bed throughout the cast.
     - Rhythmic percussive strikes (e.g., Blacksmithing `THUD` at ~1.1 Hz cadence; Cooking subtle `TICK`).
     - Distinct final strike that lands precisely on the moment of completion.
  4. Craft another item and move to cancel the cast halfway through.
  5. Confirm the vibration halts immediately upon movement with no lingering ghost strikes.
  6. Open `/pulsedebug` and switch to the **Modules** tab to verify `_DebugCraft` reflects active states and strike counts.

### Test 1.2: Open-World Gathering (Herbalism, Mining Node, Skinning)
* **Objective**: Verify behavior during open-world gathering and diagnose whether the gathering spell behaves as `castTexture` (current architecture) or requires conversion to `craftTexture`.
* **Steps**:
  1. Locate an open-world node:
     - **Herbalism**: Peacebloom, Silverleaf, Earthroot.
     - **Mining**: Copper Vein, Tin Vein.
     - **Skinning**: Any skinnable dead beast.
  2. Right-click to gather.
  3. Check sensation:
     - Notice if the vibration is a smooth casting swell/hum (`castTexture`) rather than a rhythmic strike cadence.
  4. Check `/pulsedebug` **Log** view:
     - Verify if the event logged is `CAST_START` / `castTexture` or `CRAFT_START`.
  5. Upon completing the gather, verify that `harvestComplete` fires when the loot window opens (`LOOT_READY`).

---

## 2. Minimap Button Integrity & Combat Safety

### Test 2.1: Visual Rendering & Icon Framing
* **Objective**: Confirm the minimap button displays a circular, crisp starburst icon with zero texture stretching or horizontal scanline artifacts.
* **Steps**:
  1. Log into the game or type `/reload`.
  2. Inspect the minimap button at the perimeter (default 8 o'clock):
     - **Border**: Clean golden circular ring (`MiniMap-TrackingBorder`).
     - **Backing**: Dark circular backing behind the icon.
     - **Icon**: Uncompressed, glowing purple/blue starburst (`Spell_Nature_WispSplode`).
     - **Integrity**: NO horizontal scanlines, NO striped box artifacts, NO cut-off bottom half.
  3. Hover mouse over the button:
     - Highlight aura appears smoothly.
     - Tooltip displays with header `Pulse Haptics`, Status (`Enabled`/`Disabled`), Active Profile, and controls hint.

### Test 2.2: Left-Click & Drag Functionality
* **Objective**: Verify standard UI interaction and coordinate persistence.
* **Steps**:
  1. Left-click the minimap button.
  2. Confirm the Pulse settings window opens smoothly. Left-click again to toggle/close.
  3. Click and hold the Left Mouse Button on the icon and drag it around the minimap circle.
  4. Confirm smooth 360° circular movement along the minimap edge.
  5. Release mouse button at a new position (e.g., 2 o'clock).
  6. Type `/reload` and verify the button remains anchored at the new position.

### Test 2.3: Right-Click Toggle & Combat Lockdown Protection
* **Objective**: Ensure toggling master haptics never triggers `ADDON_ACTION_FORBIDDEN` or taints the minimap ping mechanism.
* **Steps (Out of Combat)**:
  1. Right-click the minimap button.
  2. Confirm status toggles between `Enabled` and `Disabled` (tooltip updates immediately).
  3. Rapidly right-click 5 times in succession.
  4. Confirm debounce prevents spam and NO error popups appear.
  5. Click the minimap directly underneath/near the button to confirm no unintentional ping location errors occur.
* **Steps (In Combat)**:
  1. Enter combat with an enemy mob.
  2. While actively in combat, right-click the minimap button.
  3. Confirm the action is blocked safely with a red chat message:
     ```text
     [Pulse] Cannot toggle master haptics while in combat.
     ```
  4. Confirm NO `ADDON_ACTION_FORBIDDEN` popup is triggered.

---

## 3. Controller UI & SmartNavigation Edge Detection

### Test 3.1: Standard Navigation (Default State)
* **Objective**: Verify gamepad navigation functions cleanly without edge callback taint.
* **Prerequisites**: Gamepad connected or Gamepad mode active.
* **Steps**:
  1. Verify in `/pulseui` under **Controller UI** that `UI navigation hit an edge` is **OFF** by default.
  2. Navigate bags, quest dialogs, or options menus using the controller D-pad / thumbstick.
  3. Confirm focus moves smoothly with `uiFocusIn` and `uiNavigate` haptic feedback.
  4. Open radial menu (if configured) and verify `radialTick`, `radialSelect`, and `radialClose`.

### Test 3.2: Edge Detection Isolation Check (Optional Trial)
* **Objective**: Test if turning `uiNavigateEdge` ON causes any engine taint on your client build.
* **Steps**:
  1. Open `/pulseui` -> **Controller UI**.
  2. Toggle `UI navigation hit an edge` to **ON**.
  3. Navigate to the edge of a grid (e.g., end of a bag row or top of a menu).
  4. Push the stick against the edge.
  5. If the WoW client pops an `ADDON_ACTION_FORBIDDEN` warning:
     - Note the error and toggle the cue back to **OFF**.
     - (Confirms Blizzard's secure frame restriction on `SmartNavigation:RegisterCallback`).
  6. If no error occurs, enjoy subtle boundary bump haptics.

---

## 4. Engine & Log Verification

### Test 4.1: Taint Log Cleanliness
* **Objective**: Guarantee zero execution taint was logged during the session.
* **Steps**:
  1. Complete the testing steps above and log out or exit the client.
  2. Check the game's taint log file:
     ```bash
     tail -n 20 "/Applications/World of Warcraft/_classic_beta_/Logs/taint.log"
     ```
  3. Confirm NO new entries were generated during your session.

### Test 4.2: Automated Test Harness Baseline
* **Objective**: Confirm offline unit tests remain 100% clean.
* **Command**:
  ```bash
  lua PulseChecklist/tests/engine-test.lua Pulse && \
  lua PulseChecklist/tests/locomotion-test.lua Pulse && \
  lua PulseChecklist/tests/crafting-test.lua Pulse && \
  lua PulseChecklist/tests/checklist-test.lua PulseChecklist && \
  lua PulseChecklist/tests/pulsedebug-test.lua PulseDebug
  ```
* **Expected Output**: `0 failures across all 5 suites (112 tests passing)`.

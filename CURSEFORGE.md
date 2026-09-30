# Feel Azeroth.

**PulseHaptics brings World of Warcraft to your controller with rich, customizable haptic feedback.**

Feel combat impacts. Feel your spells. Feel movement, flight, swimming, UI interactions, and the world around you.

PulseHaptics turns game events into tactile feedback designed to complement what you see and hear — from quick impact pulses to continuous sensations that evolve with what you're doing.

---

## 🎮 Features

### 🎯 190 Granular Haptic Cues

A rich collection of customizable cues across 16 distinct categories:

*   **Combat & Defense:** Weapon swings, crits, parries, blocks, damage taken, combo points, and execute alerts.
*   **Spellcasting & Channels:** Cast build-up crescendo, channel hum, instant casts, interrupt and failure alerts.
*   **Shaped Locomotion:** Footfalls with 6 physical surface timbres (Boot, Hoof, Paw, Heavy, Claw, Metal) and stereo left/right motor split.
*   **Mounts & Flight:** Gallop rhythm, takeoff thrust, landing impact, taxi flights, and dragonriding speed turbulence.
*   **Environment & Weather:** Rain patter, blizzard biting chatter, storm rumbles, breath loss, and swimming drag.
*   **Tradeskills & Economy:** Anvil hammer beats, mining pick taps, skinning, herbalism, fishing bobber rumble, and loot pulses.
*   **Controller UI & Menus:** Radial menu ticks, panel transitions, popup dialogs, and soft-targeting reticle locks.
*   **Tactile Radar & Accessibility:** Loss of control stuns, interrupt windows, boss ability telegraphs, and threat transitions.

### 🎭 12 Curated Built-in Profiles

Tailor your haptic feedback to your exact activity without manual configuration:

*   **Default:** Balanced baseline across combat, environment, movement, and alerts (42 active cues, zero motor fatigue).
*   **Dungeon: Tank:** Threat lost/aggro alarms, active mitigation, CC suite, and boss cast telegraphs; zero footstep or ambient clutter.
*   **Dungeon: Healer:** Triage low-health alarms, heal completion confirmations, dispels, and interrupt warnings.
*   **Dungeon: Melee:** Strike cadence, combo points, execute warnings, boss telegraphs, and kick windows.
*   **Dungeon: Caster:** Continuous channel beds, completion snaps, lockout alarms, and proc notifications.
*   **Dungeon: Hunter:** Auto-shot timing, melee weave cadence, and feign-death threat alarms.
*   **Immersion: Melee:** Armor-weighted gait, terrain landings, parry/block impacts, weather, and world looting.
*   **Immersion: Caster:** Flowing spell textures, elemental channeling, environmental weather, and magical interactions.
*   **Immersion: Ranged:** Ranged shot cadence, weapon swings, bag handling, and world exploration.
*   **PvP (Tactical Radar):** Pure competitive reaction radar — CC suite, enemy casts, defensives, and life-threatening danger; zero ambient noise.
*   **Raiding:** Boss telegraph alarms, phase transitions, tank swaps, defensive cooldowns, and raid coordination.
*   **Questing:** Open-world adventure — footfalls, mount gallop, weather, dialogue, level up, bag/item management, and crisp mob kills.

### 👣 Shaped Locomotion & Authentic Gait

*   **Zero-Smoothing Bypass:** Discrete footstep taps bypass the continuous low-pass filter entirely using an exponential decay envelope, ensuring footsteps feel crisp and punchy rather than turning into a muddy drone.
*   **Stereo Pan / Split-Feet:** Alternates left and right footstep weights across low and high rumble motors on dual-motor gamepads (automatically disengages on single-motor schemas to maintain perfect balance).
*   **Mount Gallop Cadence:** Quadruped gaits merge footfall pairs under 80ms into authentic "ba-dump... ba-dump" stride rhythms.

### 🎛️ 35 Haptic Modes & Dual-Motor Transients

A reusable library of distinct vibration patterns, including:

*   **Punchy Transients:** `SNAP`, `DRAW`, `MICRO_TAP`, `STACCATO`, `RECOIL`, `SHUTTLE`, `TENSION` (reprogrammed for dual-motor coordination).
*   **Physical Impacts & Pulses:** `THUD`, `CLICK`, `TAP`, `HEARTBEAT`, `WARNINGBEAT`, `PULSE`, `DOUBLE_PULSE`, `TRIPLE_PULSE`, `CRACK`, `BURST`, `CRESCENDO`, `FLUTTER`, `RUMBLE`, `STUTTER`, `HEAVY_IMPACT`, `SURGE`, `PING`.
*   **Continuous Textures:** `HUM`, `THRUM`, `WAVE`, `PATTER`, `DRIFT`.
*   **Dynamic Ramps & Fades:** Customizable attack, decay, and peak strength.

### ⚡ One-Click Cue Sweeps

*   **Enable All / Disable All:** Quickly turn all 190 cues on or off in a single click from the Cue Index or Profiles page, or via chat commands (`/pulse enableall` and `/pulse disableall`). Ideal for debugging or building custom profiles.

### 📊 Live Haptic Oscilloscope & Telemetry HUD

*   **Real-time Waveform Monitor (`/pulse scope`):** Live telemetry tracking motor power, instantaneous RMS energy, and saturation meters for low and high rumble channels. Includes an active haptic layer monitor so you can see exactly which gameplay systems are driving vibration in real time. Can be run as a floating overlay or docked directly inside the Settings window.

### 🔀 Smart Event Arbitration & Coalescence

*   **No More Double-Buzzing:** Multi-event interactions (like purchasing an item and putting it into your bag) now trigger a single, clean vibration instead of machine-gun overlapping pulses.
*   **Owner-Aware Vendor Shopping:** Vendor transactions speak cleanly through `merchantBuy`, seamlessly falling back to bag intake for alternate currency purchases (honor/badges).
*   **Loot Episode Burst Absorption:** Multi-item corpse or chest looting is absorbed into a single satisfying intake pulse with dynamic item quality weighting (Uncommon, Rare, Epic).
*   **Smart Armor Repairs:** Merchant repairs (`RepairAllItems`) are recognized immediately, eliminating false-alarm durability loss alerts when fixing your gear.
*   **Window Priority Bus:** Resolves rapid window open/close overlap across Gossip, Quest, Merchant, Mail, and Bank frames.

### 🎨 Streamlined Settings Menu & Category Master Switches (`/pulse`)

*   **Category Master On/Off Gates:** Turn entire feature groups (Loot, Commerce, Combat Rhythm, Hazards, etc.) On or Off with a single master checkbox without wiping your customized child sliders underneath.
*   **70% Less Scrolling:** Redesigned compact 1-line rows reduce vertical scroll bloat by ~70% (from 787 to 239 rows).
*   **Collapsible Sections & Simple View:** Fold and unfold categories to keep your menu clean, with fold states preserved account-wide, plus a one-click "Simple View" overview.

### 🎮 Controller Support & Tuning

PulseHaptics is engineered to take full advantage of modern gamepads:

*   **PlayStation 5 DualSense / DualShock 4** (Linear resonance & haptic role routing)
*   **Xbox Wireless & Elite Series Controllers** (Tuned asymmetrical ERM rumble motors)
*   **Steam Deck & Steam Controller**
*   **Nintendo Switch Pro & 8BitDo Ultimate**

*Includes 4 swappable hardware schemas:* `Standard`, `High Motor Only`, `Low Motor Only`, and `Inverted`.
*Zero-Deadband Shutoff & Soft Breakaway Floor:* Automatically snaps decaying continuous rumble to 0 below stall thresholds to eliminate motor whine, while scaling continuous textures so low slider settings fade cleanly into dead silence.

### 🌊 Zero-GC Performance & 100% Taint Immunity

*   **Zero Garbage in Tight Loops:** Continuous oscillators allocate zero throwaway tables per frame, eliminating Lua garbage collection stutters in 40-man raids and intense battlegrounds.
*   **Taint-Immune UI:** Never triggers `ADDON_ACTION_BLOCKED`. Uses passive state polling and Classic aperture framing rather than dangerous Blizzard protected UI hooks.

---

## ♿ Accessibility & Immersion

Haptics provide another channel for perceiving important game events.

PulseHaptics can be used purely for immersion, as an additional feedback layer alongside sound and visuals, or as a tactical sensory radar to make selected combat and boss mechanics physically noticeable without staring at UI frames.

---

## 🚀 Quick Start

### 1. Enable Gamepad & Vibration in WoW

Run these two commands once in-game:

```text
/console GamePadEnable 1
/console GamePadVibration 1
```

### 2. Installation

Extract the `PulseHaptics` folder into your World of Warcraft `Interface/AddOns/` directory:

*   **macOS:** `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/PulseHaptics`
*   **Windows:** `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\PulseHaptics`

*(Note: Developer diagnostic tools like `PulseDebug`, `PulseChecklist`, `PulseProfileReview`, and `PulseProbe` are available directly in the [GitHub repository](https://github.com/codingdoctorbot/PulseSensation) for contributors and testers).*

### 3. In-Game Commands

| Command | Action |
|:---|:---|
| `/pulse` or `/pulsehaptics` | Open the main settings window. |
| `/pulse scope` | Open the real-time haptic oscilloscope & telemetry HUD. |
| `/pulse test <mode>` | Play a vibration mode (e.g. `thud`, `snap`, `wave`, `surge`, `heartbeat`). |
| `/pulse enableall` | Enable all 190 cues in the active profile in one sweep. |
| `/pulse disableall` | Disable all 190 cues in the active profile in one sweep. |
| `/pulse stop` (or `/pulse off`, `/pulse mute`) | Immediately stop all active vibrations. |
| `/pulse profile [name]` | Inspect or switch the active profile. |
| `/pulse minimap` | Toggle the minimap icon on or off. |
| `/pulse debug` | Toggle verbose logging and view engine error diagnostics. |
| `/pdebug` *(PulseDebug)* | Open the real-time diagnostic and troubleshooting HUD. |
| `/pcheck` *(PulseChecklist)* | Open the in-game cue verification checklist (all 190 cues). |
| `/pcheck export` *(PulseChecklist)* | Generate a markdown QA report to copy to clipboard. |
| `/pcheck import` *(PulseChecklist)* | Restore statuses and notes from a previous export. |
| `/pulsereview` *(PulseProfileReview)* | Open the profile cue review and auditing tool. |
| `/probe` *(PulseProbe)* | Open the telemetry probe and safety auditor HUD. |

---

## 🛠️ Open Source Hobby Project

PulseHaptics is a **free, open-source hobby project** developed independently for the World of Warcraft community.

It is actively developed and currently in **Public Beta (v0.3.0-beta)**. The core engine is fully implemented, while authored cues continue to be tuned in-game against Blizzard's evolving controller APIs.

Feedback, bug reports, testing, and contributions are welcome.

---

## 📜 Credits & Attributions

**Author:** codingdoctorbot

**AI-assisted development:** Claude Code (Anthropic) and Google Antigravity (Google DeepMind)

**Tremor:** Precursor project that provided initial inspiration, core structural ideas, and the foundational accessibility cue set used by PulseHaptics.

**Third-party libraries:**
*   `LibStub` — Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel
*   `CallbackHandler-1.0` — Cladhaire, Ammo
*   `LibDataBroker-1.1` — tekkub

---

## ⚠️ Disclaimer

PulseHaptics is a community-made World of Warcraft addon and is not affiliated with or endorsed by Blizzard Entertainment.

World of Warcraft and Blizzard Entertainment are trademarks of Blizzard Entertainment.

---

**Feel Azeroth.**

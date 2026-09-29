# ⚡ PulseHaptics
### **Feel Azeroth in your hands.**

[![WoW Version](https://img.shields.io/badge/World%20of%20Warcraft-Forever%20%2F%20Classic%20Beta%20(120100)-blue.svg)](https://github.com/codingdoctorbot/PulseSensation)
[![Status](https://img.shields.io/badge/Release-0.2.0--beta-purple.svg)](https://github.com/codingdoctorbot/PulseSensation/releases)
[![Performance](https://img.shields.io/badge/Performance-Zero--GC%20Tight%20Loops-brightgreen.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**PulseHaptics** is an immersive, console-style tactile haptics and sensory feedback engine built specifically for World of Warcraft gamepad players.

Feel the heavy, distinct thud of plate boots crushing cobblestone. Feel the viscous drag and resistance of deep water as you dive under. Feel the rhythmic hammer strikes of blacksmithing on an anvil, the hum of raw arcane energy swelling in your palms before a spell unleashes, and the violent crack of a critical hit.

---

## 🎮 The Experience: What Does Azeroth Feel Like?

| Sensation Family | What You Physically Feel |
|:---|:---|
| 🛡️ **Locomotion & Gait** | Shaped, fast-attack footfalls with 6 distinct movement timbres; stereo split-feet emulation alternating across left and right motors; authentic hooved gallop cadence for mounts; zero muddy drone. |
| ⚔️ **Living Combat Texture** | Dual-wield weapon swings alternate dynamically with your character's real melee haste; parries and blocks kick back through the controller with crisp deflection snaps. |
| 🔮 **Spellcasting & Channels** | Spells build from an ambient micro-flutter into a powerful crescendo at completion. Channels maintain a steady, hypnotic hum. |
| 🔨 **Tradeskill & Gathering** | Crafting is no longer a silent progress bar. Blacksmithing strikes rhythmically on the beat; mining picks chip stone with sharp percussive taps; herbalism, skinning, and fishing each carry their own distinct gather texture and a crisp harvest-complete pulse on loot. |
| 🌧️ **Environmental Immersion** | Distant thunderstorms rumble gently in your grip before lightning strikes; blizzards bite with icy high-frequency chatter; breath loss triggers an urgent, rising heartbeat. |
| ♿ **Tactile Accessibility & Radar** | Full situational awareness without watching UI frames: loss-of-control stuns, kick windows, incoming telegraphs, threat transitions, and execution procs felt instantly. |

---

## 🚀 Key Features

### 🎯 190 Granular Haptic Cues
Every moment of the game has been mapped to tactile telemetry across 16 distinct categories: Combat, Spells, Health, Movement, Locomotion, Environment, World, Inventory, Crafting, Encounter, Alert Loss Of Control, Alert Threat, Alert Unit Watch, Alert World, Alert Social, and Controller UI.

### 🎭 12 Curated Built-in Profiles
Tailor your sensory experience to your exact playstyle with curated default profiles vetted across all 190 cues:
- **`Default`** — Balanced baseline across combat, environment, movement, and alerts (42 active cues, avoiding motor fatigue).
- **`Dungeon: Tank`** — Commanding protection archetype. Emphasizes threat alerts, active mitigation, crowd control, and kick windows; 100% stripped of footfalls, weather, and world clutter.
- **`Dungeon: Healer`** — Attentive triage archetype. Prioritizes low-health alarms, heal completion confirmations, dispels, and interrupt warnings.
- **`Dungeon: Melee`** — High-tempo physical execution. Snappy combo points, resource spenders, execute range alerts, boss telegraphs, and kick windows.
- **`Dungeon: Caster`** — Fluid spellcasting pacing. Continuous channel beds during casts, crisp completion snaps, lockout warnings, and proc notifications.
- **`Dungeon: Hunter`** — Paced ranged rhythm with melee-weaving support. Auto-shot timing, weapon swings, feign-death threat warning, and boss mechanics.
- **`Immersion: Melee`** — Visceral physical game-feel. Armor-weighted footstep gait, terrain landings, parry/block impacts, weather, and rich world looting.
- **`Immersion: Caster`** — Atmospheric and arcane. Flowing spellcast textures, elemental channeling, environmental weather, and magical world interactions.
- **`Immersion: Ranged`** — Paced ranged cadence, auto-shots, bows and guns, bag handling, dialogue, and exploration.
- **`PvP (Tactical Radar)`** — Pure competitive reaction radar. Instant tactical alerts for crowd control, enemy casts, defensive activations, and life-threatening danger; zero ambient noise.
- **`Raiding`** — Boss encounter clarity. Telegraph alarms, tank swaps, phase transitions, defensive cooldowns, and raid coordination with zero environmental clutter.
- **`Questing`** — Open-world adventure and progression. Footsteps, mount gallop, weather shifts, quest turn-ins, dialogue, level up, bag/item management, and crisp mob kills.

### 👣 Shaped Locomotion Engine
- **Transient Shaped Layers**: Footfalls bypass continuous low-pass smoothing entirely using an exponential decay envelope and initial kick gain, delivering crisp, punchy steps that never mush into a continuous rumble.
- **6 Movement Timbres**: Tailored profiles for Walk, Run, Sprint, Mount Gallop, Swimming, and Glide.
- **Stereo Pan / Split-Feet**: Alternates left and right footstep weight across low and high rumble motors on dual-motor gamepads.
- **Authentic Mount Gallop**: Detects quadrupeds and merges galloping footfall pairs under 80ms into authentic "ba-dump... ba-dump" gait rhythms.

### 🎛️ 35 Authorable Vibration Modes
A rich library of tactile waveforms, from organic pulses to punchy transients:
- **Punchy Transients**: `SNAP`, `DRAW`, `MICRO_TAP`, `STACCATO`, `RECOIL`, `SHUTTLE`, `TENSION` (reprogrammed for dual-motor coordination).
- **Physical Impacts & Pulses**: `THUD`, `CLICK`, `TAP`, `HEARTBEAT`, `WARNINGBEAT`, `PULSE`, `DOUBLE_PULSE`, `TRIPLE_PULSE`, `CRACK`, `BURST`, `CRESCENDO`, `FLUTTER`, `RUMBLE`, `STUTTER`, `HEAVY_IMPACT`, `SURGE`, `PING`.
- **Continuous Textures**: `HUM`, `THRUM`, `WAVE`, `PATTER`, `DRIFT`.
- **Ramps & Fades**: Dynamic duration and envelope shaping.

### ⚡ One-Click Cue Sweeps
- **Enable All / Disable All**: Instantly turn all 190 cues on or off in a single click from the Cue Index or Profiles page, or via chat commands (`/pulse enableall` and `/pulse disableall`). Perfect for isolated debugging or starting fresh profiles from scratch.

### 🛡️ Zero-GC Engine & 100% Taint Immunity
- **Zero-GC in Tight Loops**: Continuous oscillators and high-frequency frames allocate zero throwaway tables per frame, eliminating garbage collection micro-stutters during intense 40-man raids and battlegrounds.
- **Taint-Immune Gamepad UI**: Never triggers `ADDON_ACTION_BLOCKED`. Uses passive state polling and Classic aperture framing rather than dangerous Blizzard protected UI hooks.
- **Zero-Deadband Shutoff**: Automatically snaps decaying continuous rumble to 0 below 0.025 to eliminate mechanical motor stall whine and reduce telemetry overhead.

---

## 🕹️ Hardware & Gamepad Support

Engineered to take full advantage of modern gamepads:
- **PlayStation 5 DualSense / DualShock 4** (Linear resonance & haptic role routing)
- **Xbox Wireless & Elite Series Controllers** (Tuned asymmetrical ERM rumble motors)
- **Steam Deck & Steam Controller**
- **Nintendo Switch Pro & 8BitDo Ultimate**

*Includes 4 swappable hardware schemas:* `Standard`, `High Motor Only`, `Low Motor Only`, and `Inverted`.

---

## ⚡ 30-Second Quick Start

### 1. Enable Gamepad & Vibration in WoW
World of Warcraft requires native gamepad input and vibration telemetry to be enabled in its engine console. Run these two chat commands once in-game:
```text
/console GamePadEnable 1
/console GamePadVibration 1
```

### 2. Installation
Install **PulseHaptics** into your World of Warcraft `Interface/AddOns/` directory:
- **Download**: Extract `PulseHaptics-v*.zip` into `Interface/AddOns/`
- **macOS Path**: `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/`
- **Windows Path**: `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\`

*(Developer tools like `PulseDebug`, `PulseChecklist`, and `PulseProfileReview` are available directly in the [GitHub repository](https://github.com/codingdoctorbot/PulseSensation) for contributors and testers).*

### 3. Immediate Taste Test
Make sure your gamepad is turned on and try these chat commands to feel your controller come alive:
- `/pulse test thud` — Heavy physical impact (boots, hammer, mace)
- `/pulse test snap` — Crisp, sharp tactile transient snap
- `/pulse test heartbeat` — Urgent cardiac rhythm
- `/pulse test wave` — Smooth environmental ocean swell
- `/pulse test surge` — Powerful magical energy surge

### 4. Customization
Type **`/pulse`** (or click the concentric ripple icon on your minimap) to open the settings window with **over 1,000 interactive controls across 190 distinct triggers and 16 active categories**.

---

### Available In-Game Commands

| Command | Action |
|:---|:---|
| `/pulse` or `/pulsehaptics` (or `/pulseui`) | Toggle the main settings window. |
| `/pulse test <mode>` | Play any authored vibration mode (e.g. `thud`, `snap`, `wave`, `surge`, `heartbeat`). |
| `/pulse enableall` | Enable all 190 cues in the active profile in one sweep. |
| `/pulse disableall` | Disable all 190 cues in the active profile in one sweep. |
| `/pulse stop` (or `/pulse off`, `/pulse mute`) | Immediately stop all active haptic vibrations. |
| `/pulse profile [name]` | Inspect or switch the active profile via chat. |
| `/pulse minimap` | Toggle the minimap button on or off. |
| `/pulse debug` | Toggle verbose console logging and view engine error diagnostics. |
| `/pdebug` *(PulseDebug)* | Open the real-time diagnostic and troubleshooting HUD. |
| `/pcheck` *(PulseChecklist)* | Open the in-game cue verification checklist (all 190 cues). |
| `/pcheck export` *(PulseChecklist)* | Generate a markdown QA status report you can copy to clipboard. |
| `/pcheck import` *(PulseChecklist)* | Open the import dialog to restore cue verification statuses. |
| `/pulsereview` *(PulseProfileReview)* | Open the profile cue review and auditing tool. |
| `/console GamePadEnable 1` | Ensure Blizzard gamepad engine subsystem is enabled. |
| `/console GamePadVibration 1` | Ensure Blizzard gamepad vibration output is enabled. |

---

## 📦 Addon Distribution & Developer Tools

PulseHaptics is distributed as a **single, self-contained package** (`PulseHaptics-v*.zip`) for CurseForge, Wago, and GitHub Releases:

| Component | Distribution | Purpose |
|:---|:---:|:---|
| **`PulseHaptics`** | 📦 **Release ZIP** | The complete haptic engine, 190 authored triggers, 12 curated profiles, 22 module watchers, custom settings UI, and profile manager. |
| **`PulseDebug`** | 🐙 *GitHub Repo* | Developer HUD for real-time channel telemetry and trigger inspection (`/pdebug`). |
| **`PulseChecklist`** | 🐙 *GitHub Repo* | In-game QA tracking checklist for verifying all 190 cues with markdown export (`/pcheck`). |
| **`PulseProfileReview`** | 🐙 *GitHub Repo* | Companion auditing tool for vetting profile cue sets and bulk toggling (`/pulsereview`). |

> *If you are developing, testing, or reviewing cues, simply clone the [GitHub repository](https://github.com/codingdoctorbot/PulseSensation) to access the entire developer suite.*

---

## 📜 Credits & Attributions

- **Author**: `codingdoctorbot`
- **AI Pair Programming Assistance**:
  - [Claude Code](https://claude.com/claude-code) — Anthropic
  - [Google Antigravity](https://deepmind.google) — Google DeepMind
- **Precursor Inspiration**:
  - **`Tremor`** — The proof-of-concept precursor that pioneered controller vibration exploration in World of Warcraft and provided foundational inspiration.
- **Embedded Third-Party Libraries**:
  - `LibStub` — Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel
  - `CallbackHandler-1.0` — Cladhaire, Ammo
  - `LibDataBroker-1.1` — tekkub

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for full details and third-party notices.

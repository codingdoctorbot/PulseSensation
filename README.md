# ⚡ PulseHaptics
### **Feel Azeroth in your hands.**

[![WoW Version](https://img.shields.io/badge/World%20of%20Warcraft-Forever%20%2F%20Classic%20Beta%20(120100)-blue.svg)](https://github.com/codingdoctorbot/PulseSensation)
[![Status](https://img.shields.io/badge/Release-0.2.0--beta-purple.svg)](https://github.com/codingdoctorbot/PulseSensation/releases)
[![Performance](https://img.shields.io/badge/GC%20Overhead-0%20KB%2Fs%20(Zero%20Stutter)-brightgreen.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**PulseHaptics** isn't another vibration alert addon that buzzes like a pager. It is a full-fidelity, console-grade haptic physics and sensory synthesizer built specifically for World of Warcraft.

Feel the heavy, distinct thud of plate boots crushing cobblestone. Feel the viscous drag and resistance of deep water as you dive under. Feel the rhythmic hammer strikes of blacksmithing on an anvil, the hum of raw arcane energy swelling in your palms before a spell unleashes, and the violent crack of a critical hit.

---

## 🎮 The Experience: What Does Azeroth Feel Like?

| Sensation Family | What You Physically Feel |
|:---|:---|
| 🛡️ **Locomotion & Armor Weight** | Heavy plate footfalls deliver low-frequency physical inertia; leather and cloth whisper; mounted gaits authentically mirror horse, wolf, and kodo stride rhythms. |
| ⚔️ **Living Combat Texture** | Dual-wield weapon swings alternate dynamically with your character's real melee haste; parries and blocks kick back through the controller with crisp deflection snaps. |
| 🔮 **Spellcasting & Channels** | Spells build from an ambient micro-flutter into a powerful crescendo at completion. Channels maintain a steady, hypnotic hum. |
| 🔨 **Tradeskill & Gathering** | Crafting is no longer a silent progress bar. Blacksmithing strikes rhythmically on the beat; mining picks chip stone with sharp percussive taps; herbalism, skinning, and fishing each carry their own distinct gather texture and a crisp harvest-complete pulse on loot. |
| 🌧️ **Environmental Immersion** | Distant thunderstorms rumble gently in your grip before lightning strikes; blizzards bite with icy high-frequency chatter; breath loss triggers an urgent, rising heartbeat. |
| ♿ **Tactile Accessibility** | Full situational awareness without watching UI frames: loss-of-control stuns, interrupts, threat transitions, and execution procs felt instantly. |

---

## 🚀 Why PulseHaptics Is Architecturally Different

- **Continuous Multi-Layer Blending**: PulseHaptics never drops sensations. You can ride your mount, channel a spell, endure a rainstorm, and absorb an incoming hit *all at the same time*. The engine blends 4 logical roles across hardware channels in real time.
- **Zero-GC Engine Discipline (0 FPS Drops)**: Built with obsessive performance discipline for WoW's embedded Lua 5.1 runtime. Continuous oscillators allocate **zero throwaway tables per frame**, eliminating garbage collection frame drops in 40-man raids and intense battlegrounds.
- **100% Taint-Immune Gamepad UI**: Never triggers `ADDON_ACTION_BLOCKED`. Uses passive 20Hz state polling and Classic aperture framing rather than dangerous Blizzard UI hooks.

---

## 🕹️ Hardware & Gamepad Support

Engineered to take full advantage of modern gamepads:
- **PlayStation 5 DualSense / DualShock 4** (Linear resonance & haptic role routing)
- **Xbox Wireless & Elite Series Controllers** (Impulse trigger motor mappings)
- **Steam Deck & Steam Controller**
- **Nintendo Switch Pro & 8BitDo Ultimate**

*Includes 6 swappable hardware schemas:* `Standard`, `High Motor Only`, `Low Motor Only`, `Inverted`, `Trigger Emphasis`, and `Rumble & Triggers`.

---

## ⚡ 30-Second Quick Start

### 1. Enable Gamepad & Vibration in WoW
World of Warcraft requires native gamepad input and vibration telemetry to be enabled in its engine console. Run these two chat commands once in-game:
```text
/console GamePadEnable 1
/console GamePadVibration 1
```

### 2. Installation
Drop the three folders (`PulseHaptics`, `PulseDebug`, and `PulseChecklist`) into your World of Warcraft `Interface/AddOns/` directory:
- **macOS**: `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/`
- **Windows**: `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\`

### 3. Immediate Taste Test
Make sure your gamepad is turned on and try these chat commands to feel your controller come alive:
- `/pulse test thud` — Heavy physical impact (boots, hammer, mace)
- `/pulse test heartbeat` — Urgent cardiac rhythm
- `/pulse test wave` — Smooth environmental ocean swell
- `/pulse test surge` — Powerful magical energy surge

### 4. Customization
Type **`/pulse`** (or click the concentric ripple icon on your minimap) to open the settings window with **1,408 settings rows (over 1,000 interactive controls and 190 distinct cues) across 21 pages**.

---

### Available In-Game Commands

| Command | Action |
|:---|:---|
| `/pulse` or `/pulsehaptics` (or `/pulseui`) | Toggle the main settings window. |
| `/pulse test <mode>` | Play any authored vibration mode (e.g. `thud`, `wave`, `surge`, `heartbeat`, `crack`). |
| `/pulse profile [name]` | Inspect or switch the active profile via chat. |
| `/pulse minimap` | Toggle the minimap button on or off. |
| `/pulse debug` | Toggle verbose console logging on or off. |
| `/pdebug` (or `/pulsedebug`) | Open the real-time diagnostic and troubleshooting HUD. |
| `/pcheck` (or `/pulsecheck`) | Open the in-game cue verification checklist (all 190 cues). |
| `/pcheck export` | Generate a markdown QA status report you can copy to clipboard. |
| `/pcheck import` | Open the import dialog — paste a previous export to restore all statuses and notes. |
| `/console GamePadEnable 1` | Ensure Blizzard gamepad engine subsystem is enabled. |
| `/console GamePadVibration 1` | Ensure Blizzard gamepad vibration output is enabled. |

---

## 📦 Addon Suite Components

| Addon Directory | Purpose |
|:---|:---|
| **`PulseHaptics`** | The core haptic engine, authored modes, 22 module watchers, settings UI, and profile manager. |
| **`PulseDebug`** | Companion developer & troubleshooting window for real-time channel introspection and trigger auditing. |
| **`PulseChecklist`** | In-game QA verification checklist tracking all 190 cues. Ships with a pre-verified baseline so a WTF reset never loses confirmed results. Supports export (markdown report) and import (paste-to-restore) entirely in-game. |

---

## 📜 Credits & Attributions

- **Author**: `codingdoctorbot`
- **AI Pair Programming Assistance**:
  - [Claude Code](https://claude.com/claude-code) — Anthropic
  - [Google Antigravity](https://deepmind.google) — Google DeepMind
- **Precursor Inspiration**:
  - **`Tremor`** — The proof-of-concept precursor that pioneered controller vibration exploration in World of Warcraft and provided the foundational inspiration and initial accessibility cue models.
- **Embedded Third-Party Libraries**:
  - `LibStub` — Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel
  - `CallbackHandler-1.0` — Cladhaire, Ammo
  - `LibDataBroker-1.1` — tekkub
  - `LibDBIcon-1.0` (aperture framing architecture) — Torhal

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for full details and third-party notices.

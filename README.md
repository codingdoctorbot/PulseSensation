# PulseHaptics

Immersive controller vibration suite for World of Warcraft (`_classic_beta_` / WoW Forever & Modern clients). **PulseHaptics** transforms in-game events into rich, layered tactile sensations — landing hard, gliding fast, weapon swings, tradeskill rhythms, taking a critical hit, or a storm rolling in — closer to a modern console game's nuanced haptics than a simple notification buzzer.

Cues layer and blend continuously through an authored multi-layer oscillator rather than one cue preempting or cutting off another.

Developed by **codingdoctorbot** with AI pair-programming assistance from [Claude Code](https://claude.com/claude-code) (Anthropic) and [Google Antigravity](https://deepmind.google) (Google DeepMind). Free to reuse, redistribute, and share under the MIT License.

---

## Key Features

- **110 Sensory Cues Across 15 Categories**:
  - **Locomotion & Movement**: Distinct gaits for walking, running, jumping, landing, swimming resistance, and Skyriding thrust.
  - **Combat Texture**: Weapon swings (main/off-hand haste pacing), spellcast swelling hum, channel flutter, auto-shot releases, and proc glows.
  - **Tradeskill Rhythms**: Authentic percussive work beats tailored by profession (Blacksmithing hammer strikes, Mining pick strikes, Engineering rapid ticks, etc.).
  - **Damage & Deflection**: Real-time feedback for damage taken, critical strikes, parries, blocks, and dodges.
  - **Environment & World**: Dynamic weather intensity (rain, storms, blizzards), zone transitions, breath loss, and underwater immersion.
  - **Accessibility & Awareness**: Threat lost/gained, interrupts, loss-of-control CC alerts, low health heartbeat, and group readiness checks (imported and expanded from precursor alpha `Tremor`).

- **Zero-Garbage Engine Architecture (Rule 4 Compliance)**:
  - Continuous haptic oscillators and frame sweeps allocate **0 garbage tables per frame**, eliminating Lua garbage collector stutter and FPS drops in combat.
  - Idle `OnUpdate` frame scripts automatically detach when actions cease, ensuring zero idle CPU consumption.

- **Taint-Immune Gamepad UI**:
  - Native Classic LibDBIcon minimap button aperture geometry (zero GPU shader clamp artifacts).
  - Ultra-lightweight passive 20Hz polling for controller navigation — strictly avoids Blizzard UI execution taint (`ADDON_ACTION_BLOCKED`).
  - Protected combat-lockdown state deferral for all profile switches and option updates.

- **Deep Motor & Hardware Routing**:
  - Maps logical roles (`low`, `high`, `ltrigger`, `rtrigger`) across standard rumble and PS5 DualSense / Xbox controller profiles.
  - Built-in hardware schemas: `Standard`, `High Motor Only`, `Low Motor Only`, `Inverted`, `Trigger Emphasis`, and `Rumble & Triggers`.

- **Comprehensive In-Game Configuration & QA Tools**:
  - Over 1,300 intuitive controls across 21 dedicated settings pages.
  - **`PulseDebug`** (`/pdebug`): Real-time event log, live channel monitor, CVar gate diagnostics, and interactive test triggers.
  - **`PulseChecklist`** (`/pcheck`): Interactive in-game QA testing checklist with character stamps and status tracking.

---

## Addon Suite Components

| Addon Directory | Purpose |
|:---|:---|
| **`PulseHaptics`** | The core haptic engine, authored modes, 22 module watchers, settings UI, and profile manager. |
| **`PulseDebug`** | Companion developer & troubleshooting window for real-time channel introspection and trigger auditing. |
| **`PulseChecklist`** | In-game verification checklist to track which of the 110 cues have been field-tested on your character. |

---

## Status

**Beta (`0.2.0-beta`)** — Targeting World of Warcraft `1.60.1.69913` (Interface `120100` / Patch 12.1.0). Fully verified against official WoW Forever client source code with zero static analysis warnings and 100% test suite pass rate.

---

## Installation

1. Download or clone this repository.
2. Copy (or symlink) the following folders into your World of Warcraft `Interface/AddOns/` directory:
   - `PulseHaptics/`
   - `PulseDebug/`
   - `PulseChecklist/`
3. Launch World of Warcraft and ensure the addons are enabled in the character select **AddOns** menu.
4. Type `/pulse` in chat or click the minimap button to open the settings panel.

### Slash Commands

- `/pulse` or `/pulsehaptics` — Toggle the PulseHaptics settings panel.
- `/pulse test <mode>` — Trigger a test haptic shape (e.g. `/pulse test thud`).
- `/pdebug` (or `/pulsedebug`) — Open the real-time diagnostic and troubleshooting HUD.
- `/pcheck` (or `/pulsecheck`) — Open the in-game cue verification checklist.

---

## Credits & Attributions

- **Author**: `codingdoctorbot`
- **AI Pair Programming Assistance**:
  - [Claude Code](https://claude.com/claude-code) — Anthropic
  - [Antigravity](https://deepmind.google) — Google DeepMind
- **Precursor Inspiration**:
  - **`Tremor`** — Foundational proof-of-concept alpha that pioneered controller vibration exploration in WoW and provided the initial accessibility cue models.
- **Embedded Third-Party Libraries**:
  - `LibStub` — Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel
  - `CallbackHandler-1.0` — Cladhaire, Ammo
  - `LibDataBroker-1.1` — tekkub
  - `LibDBIcon-1.0` (aperture framing architecture) — Torhal

---

## License

This project is licensed under the **MIT License** — free to use, modify, redistribute, and enjoy.

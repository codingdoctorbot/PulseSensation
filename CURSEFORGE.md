# Pulse Haptics: Feel Azeroth

**Customizable controller vibration for World of Warcraft.**

Feel combat impacts, spellcasting, footsteps, mount movement, gathering, loot, and interface interactions through your gamepad. PulseHaptics uses WoW's native gamepad support, with 190 configurable cues, 35 vibration modes, and 12 built-in profiles.

Choose the feedback you want, adjust its strength and timing, and keep the rest quiet. Presets are available for Xbox, PlayStation DualSense and DualShock 4, Steam Deck, Steam Controller, Nintendo Switch Pro, and 8BitDo controllers. Motor behavior varies by hardware and connection method.

## New in v0.3.3-beta

- **Six-step guided setup:** choose controller hardware, combat feedback, world and interface cues, continuous effects, and overall strength.
- **Conservative continuous-effect defaults:** new setups enable casting, crafting, low-health heartbeat, and breath depletion. Other continuous effects start off. Existing profiles keep their saved choices.
- **Controller navigation:** move between controls, adjust sliders, select dropdown choices, and read contextual button prompts.
- **Settings handoff fixes:** improved cleanup when settings close after being opened from the Game Menu. The wizard and Advanced Settings no longer capture gameplay keys through hidden click targets.
- **Windfury tracking:** a standalone proc-tracking module and Experimental settings page.

## Feedback you can tune

- **Combat and defense:** swings, critical hits, parries, blocks, incoming damage, combo points, and execute alerts.
- **Casting and channels:** cast build-up, channel feedback, completion, interrupts, and failure alerts.
- **Movement and mounts:** distinct footstep and gait styles, galloping, takeoff, landing, and flight feedback.
- **Environment:** weather, swimming, underwater breath, and exploration cues.
- **Professions and loot:** crafting rhythms, gathering, fishing, item collection, and inventory interactions.
- **Interface and targeting:** radial menus, panel transitions, soft targeting, and selected combat alerts.

Enable or disable individual cues or whole categories without clearing the settings underneath. Collapsible sections and Simple View keep Advanced Settings manageable. The engine coalesces overlapping events and keeps high-frequency haptic loops allocation-conscious.

## Profiles and vibration modes

Start with **Default**, **Questing**, **Raiding**, **PvP – Tactical Radar**, dungeon-role profiles for Tank, Healer, Melee, Caster, and Hunter, or the three Immersion profiles for Melee, Caster, and Ranged. Customize any profile to suit your playstyle.

The vibration library includes short transients, physical impacts, rhythmic pulses, continuous textures, and ramps. Examples include `SNAP`, `MICRO_TAP`, `THUD`, `DOUBLE_PULSE`, `HEARTBEAT`, `RUMBLE`, `HUM`, `WAVE`, and `CRESCENDO`.

Four motor schemas are available: Standard, High Motor Only, Low Motor Only, and Inverted. Supported dual-motor devices can use alternating left/right footstep emphasis.

## Quick start

1. Install the `PulseHaptics` folder in your WoW `Interface/AddOns/` directory, or install through CurseForge.
2. Enable WoW's gamepad and vibration options. If needed, run:

```text
/console GamePadEnable 1
/console GamePadVibration 1
```

3. Complete the setup wizard on first login. Run `/pulse setup` to revisit it. Saved choices are preserved.
4. Open `/pulse` for Advanced Settings. Try `/pulse test thud` to check controller output.

## Useful commands

| Command | Action |
| --- | --- |
| `/pulse` or `/pulsehaptics` | Open Advanced Settings |
| `/pulse setup` or `/pulsewizard` | Open guided setup |
| `/pulse test <mode>` | Test a vibration mode |
| `/pulse scope` | Open the live waveform and motor telemetry display |
| `/pulse stop` | Stop active vibration |
| `/pulse profile [name]` | Inspect or switch the active profile |
| `/pulse enableall` / `/pulse disableall` | Enable or disable cues in the active profile |
| `/pulse minimap` | Toggle the minimap icon |
| `/pulse debug` | Toggle diagnostic logging |

## Compatibility and project status

**Public beta: v0.3.3-beta.** Current development targets **WoW Forever 1.60.1, Interface 16001**, with native gamepad support. The TOC retains compatibility entries for other clients; those entries do not mean every effect has been verified on each client. Individual cues continue to be tuned as Blizzard's APIs evolve.

Haptics supplement the game's visual and audio cues. Actual feedback depends on the controller, connection, client support, and enabled effects.

PulseHaptics is a free, open-source hobby project. Feedback, bug reports, and contributions are welcome. The source and developer tools (`PulseDebug`, `PulseChecklist`, and `PulseProfileReview`) are available in the [GitHub repository](https://github.com/codingdoctorbot/PulseSensation2).

## Credits

- **Author:** codingdoctorbot
- **AI-assisted development:** Claude Code (Anthropic), Google Antigravity (Google DeepMind), and Codex (OpenAI)
- **Tremor:** precursor project that supplied initial inspiration, structural ideas, and foundational accessibility cues
- **Libraries:** LibStub, CallbackHandler-1.0, and LibDataBroker-1.1; see the source and included license notices for their authors

PulseHaptics is a community addon and is not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft and Blizzard Entertainment are trademarks of Blizzard Entertainment.

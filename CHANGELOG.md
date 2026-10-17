# PulseHaptics v0.3.3

## Guided setup

- Added a six-step setup wizard for controller hardware, combat feedback, world and interface cues, continuous effects, and master strength. It opens for first-time setup and can be revisited with `/pulse setup` or `/pulsewizard`.
- New setups enable casting, crafting, low-health heartbeat, and breath depletion. Other continuous effects start disabled.
- Existing profiles and choices made during an earlier wizard run are preserved.
- Wizard cue toggles now enable the relevant category gates, so an enabled effect can actually play.
- Closing the wizard, including with Escape or when combat starts, stops continuous previews and releases its controller input.

## Controller navigation and Game Menu

- Added controller sub-focus for toggles, sliders, dropdowns, and test controls, with contextual button prompts.
- Removed hidden gameplay-key capture from the wizard and Advanced Settings. Any pending cleanup waits until combat ends.
- Fixed the Game Menu handoff that could leave gameplay bindings unavailable after closing settings.
- Refined the PulseHaptics Game Menu button's spacing, hardware glyphs, and text layout, and fixed a font-template error during creation.

## Other changes

- Added standalone Windfury proc tracking and an Experimental settings page.
- Updated the setup documentation, source links, release packaging, and offline regression coverage.

This release targets WoW Forever 1.60.1 (Interface 16001). Existing compatibility TOC entries are retained; they do not establish testing on those other clients. Controller response varies by hardware and connection method.

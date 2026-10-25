# PulseHaptics v0.4.0

## Languages

- PulseHaptics is now available in all 11 languages World of Warcraft supports: English,
  German, Spanish (Spain and Latin America), French, Italian, Brazilian Portuguese, Russian, Korean, and Simplified and Traditional Chinese. Every settings page, the setup wizard, profiles, cue names, and chat
  messages are translated.
- The addon follows your game language automatically. To use a different one, choose it in
  Quick Setup step 1 or under **Addon language** in Advanced Settings. A reload applies the
  change, and Quick Setup reopens where you left it.
- Vibration mode pickers show readable, translated names (Double Tap, Thud, ...). Saved
  settings and `/pulse test <MODE>` still use the original mode IDs, which the tooltip shows.
- Strings that are not translated yet fall back to English.

## Quick Setup layout

- Buttons size to their text, and hint lines fit the space available.
- Step 5 shows every effect description in full; the window grows taller when a language
  needs more room.
- Controller hints use symbols every game font can display.

## Compatibility

Client interface entries are unchanged: `16001`, `120100`, `110200`, and `110100`.
Existing profiles and settings are preserved.

---

# PulseHaptics v0.3.4

## Fixed

- Closing Advanced Settings now stops motor-calibration ramps and one-shot motor tests.
  Previously a ramp could continue vibrating and printing calibration steps for up to
  20 seconds after the window closed.
- Temporary continuous and multi-step cue previews are also cancelled when settings close.
- Cleanup covers the Close button, corner X, Escape, and switching to Quick Setup.
- Normal gameplay haptics keep running; saved profiles and calibration values are unchanged.

## Compatibility

The existing client interface entries are unchanged: `16001`, `120100`, `110200`, and
`110100`. This patch does not narrow the addon to WoW Forever.

---

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

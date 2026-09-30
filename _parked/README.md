# Parked Companion Addons

These addons are parked, not loaded by the game, not tested, not linted, and not shipped.

---

### Addon Status & Rationale

- **PulseCompass**: Directional corpse/waypoint pings. Fix attempt reverted because it affected haptic feel. Candidate to rebuild as a standalone addon that drives `C_GamePad` directly and defers to Pulse when Pulse is mid-cue.
- **PulseStudio**: Mode timeline editor. Save/export don't match the mode format. Salvageable: the mode-to-timeline conversion in `Studio:LoadBuiltin` (`Sequencer.lua`).
- **PulseAudio**: Sounds on cues. Its hooks never see real cues. Salvageable: a throttled "sound when a cue fires" debug aid for `PulseDebug`, using verified `SOUNDKIT` IDs only.
- **PulseSync**: Profile export/import. Imported profiles never get registered. Idea to move into `PulseHaptics`' Profiles page later; the serializer is salvageable once malformed counts are bounded.
- **PulseBridge**: WeakAuras/macro/boss-mod hooks. Calls engine methods that don't exist. Keep the idea of a WeakAuras/macro hook for a future public Pulse API; the boss-mod hooks are unverified.
- **PulseProbe**: Telemetry probe and event-order tracer ring. Parked for offline analysis; its trace capture ring and `/probe` HUD are kept for future event timing research.

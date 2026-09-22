# PulseGit

World of Warcraft addon suite, built around **Pulse** — turns what's happening in
the game into controller vibration (landing hard, gliding fast, taking a crit, a
storm rolling in) closer to a console game's rumble than to a notification system.
Cues layer and blend continuously rather than one cue preempting another.

Vibe-coded, non-commercial hobby project, written with [Claude Code](https://claude.com/claude-code)
rather than hand-authored line by line. Free to reuse, redistribute, and share
as-is — no warranty, no support commitment, expect rough edges rather than
production polish.

## Features

- **110 cues across 15 categories** — movement, flight & mounts, combat texture,
  environment, world & game-feel, your own casting, loss of control, threat,
  target/focus, group & social, world & interface, controller state, and a full
  accessibility set (combat/life state) imported from sibling addon Tremor.
- **21 authored vibration modes** — 16 one-shot pulses (from a light `TICK` up to
  a reserved-for-the-worst-moments `HEAVY`) and 5 continuous textures (`HUM`,
  `THRUM`, `WAVE`, `PATTER`, `DRIFT`) for ambient, held sensations rather than
  a single beep.
- **Cues blend instead of interrupting each other** — an ambient cast hum, a
  gliding presence, and a crit thump can all play at once, smoothed continuously
  by the engine rather than the loudest cue winning and the rest getting dropped.
- **6 continuous textures** for things that don't have a single instant — swimming
  resistance, dragonriding/Skyriding thrust, casting, underwater breath, low
  health, taxi flight — each fading in and out with the condition instead of
  announcing itself once.
- **Deep motor & intensity control** — pick which physical motor (or PS5
  DualSense adaptive trigger) drives which logical role, tune per-mode low/high
  motor and duration multipliers, dial overall and per-cue intensity, and
  reassign any trigger to a different mode via a "feels like" override.
- **4 built-in profiles** (Default, Raiding, Questing, PvP) with independently
  curated cue selections, plus unlimited custom profiles — each character picks
  its own active profile.
- **A settings panel that explains itself** — an in-panel plain-English guide, a
  mode tester to feel a cue before enabling it, and a `/pulse test <mode>` slash
  command.
- **Two companion QA tools** — `PulseDebug` for live chat-based introspection
  (fire/hold any trigger, see why a cue isn't firing, watch events in real time)
  and `PulseChecklist` for tracking which of the 110 cues are actually confirmed
  working in-game.

## Addons

| Addon | What it does |
|---|---|
| **Pulse** | The main addon — vibration engine, 21 authored "modes" (tap, thud, rising, stutter, ...), and modules covering movement, flight, combat, environment, world events, encounters, health, plus a full accessibility cue set imported from Tremor (stuns, interrupts, threat, social prompts). |
| **PulseChecklist** | QA tracking checklist for Pulse's cues. Read-only against Pulse (via the `_G.Pulse` handle), own window, own SavedVariables, `/pulsecheck` or `/pcheck`. |
| **PulseDebug** | Troubleshooting companion for Pulse. Not shipped alongside it, not a second copy of its logic. |

## Status

Alpha (`0.1.0-alpha`), targeting Interface `120100` (Patch 12.1.0). Built and
iterated on with Claude Code across sessions. Some cues are confirmed working
in-game; others are only `luac -p` clean so far.

## Installation

Copy `Pulse/`, `PulseChecklist/`, and `PulseDebug/` into your WoW `Interface/AddOns/`
folder. `PulseChecklist` and `PulseDebug` both depend on `Pulse` being installed.



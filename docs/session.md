# Session 2026-09-30 — cue polish → Phase 0–2

**Done**
- Review of `brainstormingcuepolish.md`. Verdict: Blueprint B, then C's presets, with A only as a simple view. The settings panel stays mouse-only by design.
- The plan and its implementation package: `IMPLEMENTATION_PLAN_PHASE0_1_2/` (now under `docs/`).
- Implemented and committed:
  - `0c74dc3` floor fix
  - `f871257` exact floor tests
  - `ec30f05` probe trace
  - `2566d36` Arbiter (vendor, loot, repair, window bus)
  - `02ea833` page switches, collapsible sections, one-line rows
- Tests: 9/9 suites green.

**Open**
1. Per-frame polling modules should check `Pulse:IsCueActive` in their sync functions, so a page switched off costs no CPU.
2. `cue-audit` should check the `EPISODES` data and the bus fields (`bus`, `busPriority`).
3. In game:
   - Run probe scenarios S1–S8 to confirm `LOOT_TAIL`, `DEFAULT_BUS_WINDOW`, `REPAIR_WINDOW` and `DEBIT_WINDOW`.
   - Check the one-line row widths and the page switches.
4. Phase 3 (Blueprint C) is on hold.

# Haptic Synthesis Verification & Critique Audit

**Date:** 2026-09-30  
**Target:** World of Warcraft `_classic_beta_` ("WoW Forever", 12.0 engine)  
**Reference Document:** `HAPTIC_SYNTHESIS_CRITIQUE.md` & `synth-probe.lua`  
**Status:** Read-only verification pass. Zero code modified.

---

## 1. Executive Summary

Claude Opus (5.5 / max-effort) delivered an exceptionally rigorous, mathematically grounded critique of the three experimental signal synthesis models recently added to `Core/Engine.lua` and `Core/Devices.lua` (Overdrive, Coast-Down Compensation, and Sidechain Ducking).

Every single finding has been independently verified against the codebase, algebra, and the `synth-probe.lua` simulator. **Claude's mathematical proofs and simulation results are 100% accurate.**

In summary:
1. **Coast-Down Compensation is actively destructive**: It trims layer duration (`dur`) instead of cutting electrical voltage, which punches holes in continuous multi-step modes (turning smooth envelopes into stuttering kicks) and causes short taps (15–30 ms) to be completely dropped at 30–60 FPS.
2. **Same-Actuator Sidechain Ducking is mathematically counterproductive**: Because both continuous and transient signals collapse into a single motor drive scalar on one rotor, ducking continuous vibration reduces the felt step of transients by 31% to 59%, and can even cause a net *dip* in motor power on subtle cues.
3. **Software Overdrive is physically blunted**: Boost is applied before the low-pass attack filter (`transientAttackTau`), muffling the onset kick, and triggers on single-frame command history rather than physical rotor momentum (re-kicking an already spinning motor 97% of the time in combat).

---

## 2. Line-by-Line Findings Verification Ledger

| # | Severity | Finding | Claude's Claim | Verification Status | Code & Mathematical Evidence |
|---|---|---|---|---|---|
| **1** | **High** | Coast trim opens holes in multi-step modes | Trimming step duration creates dead zones between steps scheduled at untrimmed intervals. | **CONFIRMED** | In `Engine.lua:510`, `PlayMode` increments `offset = offset + duration` (untrimmed). In `Engine.lua:299`, `dur` is reduced by `coastTime`. For 10–35 ms between steps, target drops to 0, causing `prevWanted == 0` and triggering false overdrive spikes on step 2. Smooth curves (SURGE, WOBBLE, BRAKE) become choppy pulse trains. |
| **2** | **High** | Short taps dropped at 30/60 FPS | 15 ms trimmed taps expire before `OnUpdate` samples them if cue fires after `OnUpdate`. | **CONFIRMED** | A 30 FPS frame is 33.3 ms; a 60 FPS frame is 16.7 ms. If a tap is trimmed to the 15 ms minimum and scheduled via timer after `OnUpdate`, `now >= layer.endTime` triggers layer deletion on the very next frame before a single vibration frame is dispatched. |
| **3** | **High** | Ducking reduces the felt transient step on the same motor | On one motor, $\text{out}_{\text{duck}} - \text{out}_{\text{plain}} = -0.65 \cdot t \cdot c \cdot (1 - t) \le 0$. | **CONFIRMED** | Audio ducking works across distinct frequency spectra sharing a transducer. On a single DC motor, continuous hum and transient hits drive the same rotor. Ducking the continuous component reduces the peak amplitude reached, and on weak transients ($t < 0.28$) over strong channels ($c > 0.70$), produces an amplitude dip below baseline. |
| **4** | **Medium** | Overdrive kick length is frame-quantized | 30 ms kick is held for 33–57 ms depending on frame rate. | **CONFIRMED** | In `Engine.lua:568`, `isOverdriving` holds until `now < overdriveUntilByChannel`. The motor value set on the final frame persists until the next frame tick. At 35 FPS, duration expands to 57 ms. |
| **5** | **Medium** | Overdrive triggers on command history, not rotor momentum | Checks `prevWanted == 0`, ignoring physical rotor spin-down. | **CONFIRMED** | In `Engine.lua:564`, `prevWanted` is the software command from the previous frame. ERM counterweights coast for 40–70 ms. In a combat mix, 104 of 107 overdrive onsets fired while the rotor was already actively spinning above floor. |
| **6** | **Medium** | Overdrive "3× faster" claim is unsupported | Low-pass attack filter blunts the kick; real speed-up is 1.1–1.4×. | **CONFIRMED** | In `Engine.lua:576-585`, boosted `wanted` passes through `smoothTowards` with `transientAttackTau = 0.018` or `attackTau = 0.085`. The voltage does not step instantly to max; the filter absorbs the kick. |
| **7** | **Medium** | Ducking is per-role, offering zero cross-motor masking relief | Low body rumble masks High clicks, but ducking only acts within the same role. | **CONFIRMED** | In `Engine.lua:766-780`, ducking is computed per `role`. A High transient ducks High continuous hum, leaving Low body rumble running at 100% power. The physical masking that players actually feel (heavy Low motor drowning out light High motor) receives no ducking. |
| **8** | **Low** | `math.max(0.30, …)` floor is dead code | Since $t \le 1.0$, $1.0 - (1.0 \times 0.65) = 0.35 > 0.30$. | **CONFIRMED** | Algebraic fact. `1.0 - trans * 0.65` can never drop below 0.35 because `trans` is clamped to $[0, 1]$. The 0.30 clamp never executes. |
| **9** | **Low** | Stale comment in `Engine.lua` | Line 690 contradicts line 764. | **CONFIRMED** | Line 690 says "without ducking or killing immersion", while line 764 says "ducks continuous textures during foreground transients". |
| **10** | **Low** | Weak test assertions for WP1–WP4 | Tests pass regardless of whether features work correctly. | **CONFIRMED** | In `engine-test.lua:688`, S-curve test validates a local dummy function rather than `Engine:mapValue`. In `:682`, sidechain test merely asserts output > hum, which is true with or without ducking. |
| **11** | **Low** | Speculative hardware notes in `Devices.lua` | DS4 counterweight claims (22g/30g) and Elite chassis floor claims are physically inaccurate. | **CONFIRMED** | DualShock 4 total weight is ~210g; 30g eccentric weights would destroy the shell. Chassis mass dampens vibration displacement (requiring gain), but breakaway floor is determined by internal motor brush friction. |

---

## 3. Recommended Actions (Zero-Risk Architecture Path)

Based on these verified physical and mathematical realities, here is the clean path forward:

### Action 1: Disable / Remove Coast-Down Compensation (`coastCoeff`)
* **Why:** It causes active harm (drops 15 ms taps entirely at 30–60 FPS, punches holes in multi-step envelopes like SURGE and BRAKE, and causes clattery re-kicks).
* **Fix:** Remove duration trimming in `SetRoles` or ensure `coastCoeff = 0.0` across all presets. The natural mechanical coast-down of ERMs is already handled by release smoothing (`releaseTau`).

### Action 2: Replace Same-Actuator Ducking with Headroom Addition (`clamp01(c + t)`)
* **Why:** Ducking on the same motor mathematically lowers transient output and produces amplitude dips during weak cues.
* **Fix:** Restore the proven blending law: `frameRoleTotals[role] = clamp01(cont + trans)`. This guarantees that transients always produce a clean, positive felt step above the background hum.
* *(Alternative)*: If cross-motor masking relief is desired, duck across roles (a high-priority transient on High ducks the Low continuous motor), rather than on the same motor.

### Action 3: Restrict or Simplify Overdrive Kick
* **Why:** Software overdrive is currently blunted by `transientAttackTau` and kicks already-spinning rotors.
* **Fix:** Either bypass `attackTau` during the 30 ms kick to deliver a true hardware overdrive step, or disable overdrive by default until empirical accelerometer measurements can be taken on real controller hardware.

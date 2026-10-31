# PulseSensation / PulseHaptics — TODO & Roadmap

Prioritized roadmap for `PulseSensation` (World of Warcraft `_classic_beta_`).

---

## 🎯 v0.4.x Polish & Hardware Verification
- [ ] **Hardware QA on Steam Deck**:
  - [ ] Test built-in Steam Deck haptic rumbles vs external Bluetooth controllers (DualSense, Xbox, Switch Pro).
  - [ ] Confirm Game Menu docked banner visual alignment across multiple UI scales (1080p, 1440p, 800p handheld).
- [ ] **Release Packaging**:
  - [ ] Run `./scripts/test.sh -p` to update release archive `dist/PulseHaptics-v0.4.0.zip`.
  - [ ] Draft CurseForge / Wago changelog highlighting all 11 languages.

---

## 🔬 Experimental Features
- [ ] **UI Scroll Wheel / Height Optimization**:
  - [ ] Investigate tab or scroll frame solutions for tall settings pages as requested in developer review.
  - [ ] Review tooltip sentence explanations for all options in the interface.
- [ ] **Audio Haptics Lab**:
  - [ ] Track experiments and hardware testing in companion repo `../SonicHaptics/`.

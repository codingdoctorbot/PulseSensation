#!/usr/bin/env python3
"""generate_swim_plot.py
Create a line chart representing the expected haptic intensity over a single
swim‑stroke cycle for three common controller types.

- ERM (Xbox) – moderate amplitude, sharper peaks.
- LRA (DualSense) – smoother, higher‑frequency response.
- LRA low‑force (Switch Pro) – same shape as DualSense but lower amplitude.

The plot is saved as `swim_haptic_profile.png` in the same directory.
"""
import numpy as np
import matplotlib.pyplot as plt

# Stroke duration (seconds)
T = 1.2
# Time vector – fine resolution for smooth curves
t = np.linspace(0, T, 600)  # 0.002 s step

# Helper to create a simple envelope for a swimming stroke:
#   start ramp -> plateau -> end ramp
def envelope(t, T):
    # Use a raised cosine for smooth start/end
    start = 0.2 * (1 - np.cos(np.pi * t / (0.2 * T)))  # first 20% of cycle
    mid = np.ones_like(t)
    end = 0.2 * (1 - np.cos(np.pi * (T - t) / (0.2 * T)))  # last 20%
    mask_start = t < 0.2 * T
    mask_end = t > 0.8 * T
    env = np.where(mask_start, start, np.where(mask_end, end, mid))
    return env

env = envelope(t, T)

# ERM – add a slight high‑frequency harmonic to simulate sharper peaks
erm = env * (0.6 + 0.4 * np.sin(2 * np.pi * 5 * t))
# Clip to [0,1]
erm = np.clip(erm, 0, 1)

# LRA – smoother sinusoid with higher base amplitude
lra = env * (0.8 + 0.2 * np.sin(2 * np.pi * 2 * t))

# LRA low‑force – same shape as LRA but scaled down
lra_low = 0.5 * lra

plt.figure(figsize=(6, 3))
plt.plot(t, erm, label='ERM (Xbox)', color='#1f77b4')
plt.plot(t, lra, label='LRA (DualSense)', color='#ff7f0e')
plt.plot(t, lra_low, label='LRA low‑force (Switch Pro)', color='#2ca02c')

# Mark key points: start, mid, end
for pt in [0, T/2, T]:
    plt.axvline(pt, color='gray', linewidth=0.5, linestyle='--')

plt.title('Expected haptic amplitude over a swimming stroke')
plt.xlabel('Time (s)')
plt.ylabel('Normalized intensity (0‑1)')
plt.xlim(0, T)
plt.ylim(0, 1.05)
plt.legend()
plt.tight_layout()
plt.savefig('swim_haptic_profile.png')
print('Plot saved to swim_haptic_profile.png')

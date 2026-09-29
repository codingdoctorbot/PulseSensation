-- Pulse — Core/Modes.lua
--
-- The 21-mode vocabulary. Tremor capped at 6 because accessibility tops out at three or
-- four reliably distinguishable signals under pressure; Pulse is not asking anyone to tell
-- cues apart in a crisis, so a richer palette is right. Every shape is an author-tuned
-- constant in a reusable named vocabulary rather than one baked number per cue — reuse
-- without forty-two sliders.
--
-- Discrete shapes: `steps` is a sequence of {role, relIntensity, relDuration} or {gap},
-- scaled by `baseDuration`. `role` is "low", "high" or "both", the last for a single pulse
-- that should feel full-bodied rather than textured to one motor.
--
-- Continuous shapes (`continuous = true`) carry a baked `low`/`high` target instead of
-- steps. The calling module drives them via Engine:Hold every tick its state is true — see
-- Modules/Combat.lua's cast texture for the reference shape.

local ADDON_NAME, Pulse = ...

Pulse.Modes = {

	-- ── Discrete, single or few pulses ──────────────────────────────────────────
	TAP = {
		label = "A soft, quick tick.",
		baseDuration = 0.055,
		steps = { { role = "high", relIntensity = 0.55, relDuration = 1.0 } },
	},
	DOUBLE_TAP = {
		label = "Two soft ticks.",
		baseDuration = 0.12,
		steps = {
			{ role = "low", relIntensity = 0.6, relDuration = 1.0 },
			{ gap = 0.12 },
			{ role = "low", relIntensity = 0.6, relDuration = 1.0 },
		},
	},
	TRIPLE_TAP = {
		label = "Three soft ticks.",
		baseDuration = 0.10,
		steps = {
			{ role = "low", relIntensity = 0.6, relDuration = 1.0 },
			{ gap = 0.10 },
			{ role = "low", relIntensity = 0.6, relDuration = 1.0 },
			{ gap = 0.10 },
			{ role = "low", relIntensity = 0.6, relDuration = 1.0 },
		},
	},
	LONG = {
		label = "One sustained pulse.",
		baseDuration = 0.45,
		steps = { { role = "low", relIntensity = 0.7, relDuration = 1.0 } },
	},
	-- The addon's most serious moments (ccStun, threatAggro, playerDead, resourceCapped),
	-- kept at max peak on purpose. It and THUD were once both high/1.0, separated by
	-- duration alone, which made them near-duplicates on hardware with any spin-up lag.
	-- THUD's peak was softened instead of this one's, so the strongest possible pulse stays
	-- reserved for HEAVY.
	HEAVY = {
		label = "One strong, sustained pulse.",
		baseDuration = 0.45,
		steps = { { role = "both", relIntensity = 1.0, relDuration = 1.0 } },
	},
	STUTTER = {
		label = "Four rapid, sharp ticks.",
		baseDuration = 0.040,
		steps = {
			{ role = "high", relIntensity = 0.9, relDuration = 1.0 },
			{ gap = 0.060 },
			{ role = "high", relIntensity = 0.9, relDuration = 1.0 },
			{ gap = 0.060 },
			{ role = "high", relIntensity = 0.9, relDuration = 1.0 },
			{ gap = 0.060 },
			{ role = "high", relIntensity = 0.9, relDuration = 1.0 },
		},
	},
	RISING = {
		label = "Builds from a low hum into a high pulse.",
		baseDuration = 0.4,
		steps = {
			{ role = "low", relIntensity = 0.5, relDuration = 0.4 },
			{ role = "high", relIntensity = 1.0, relDuration = 0.6 },
		},
	},
	FALLING = {
		label = "Starts high, fades into a low hum.",
		baseDuration = 0.45,
		steps = {
			{ role = "high", relIntensity = 1.0, relDuration = 0.35 },
			{ role = "low", relIntensity = 0.4, relDuration = 0.65 },
		},
	},
	THUD = {
		label = "One sharp, heavy impact — fast attack, fast decay.",
		baseDuration = 0.12,
		steps = {
			{ role = "both", relIntensity = 0.85, relDuration = 0.5 },
			{ role = "low", relIntensity = 0.75, relDuration = 0.8 },
		},
	},
	THUMP = {
		label = "One full-bodied hit on both motors.",
		baseDuration = 0.14,
		steps = { { role = "both", relIntensity = 0.85, relDuration = 1.0 } },
	},
	DEFLECT = {
		label = "A sharp metallic parry clang.",
		baseDuration = 0.050,
		steps = {
			{ role = "high", relIntensity = 0.95, relDuration = 0.6 },
			{ role = "high", relIntensity = 0.35, relDuration = 0.8 },
		},
	},
	TICK = {
		label = "A very light micro-pulse.",
		baseDuration = 0.040,
		steps = { { role = "high", relIntensity = 0.28, relDuration = 1.0 } },
	},
	CHIME = {
		label = "A soft tick followed by a brighter one.",
		baseDuration = 0.1,
		steps = {
			{ role = "low", relIntensity = 0.5, relDuration = 1.0 },
			{ gap = 0.08 },
			{ role = "high", relIntensity = 0.6, relDuration = 1.0 },
		},
	},
	KNOCK = {
		label = "Two heavier hits with a gap between them.",
		baseDuration = 0.16,
		steps = {
			{ role = "high", relIntensity = 0.65, relDuration = 1.0 },
			{ gap = 0.14 },
			{ role = "high", relIntensity = 0.9, relDuration = 1.0 },
		},
	},
	SURGE = {
		label = "Ramps up in three steps, then releases.",
		baseDuration = 0.2,
		steps = {
			{ role = "low", relIntensity = 0.3, relDuration = 1.0 },
			{ role = "low", relIntensity = 0.6, relDuration = 1.0 },
			{ role = "low", relIntensity = 1.0, relDuration = 1.0 },
			{ role = "high", relIntensity = 1.0, relDuration = 1.6 },
		},
	},
	PULSE_BEAT = {
		label = "Anatomical lub-dub cardiac rhythm.",
		baseDuration = 0.16,
		steps = {
			{ role = "low", relIntensity = 0.65, relDuration = 0.55 },
			{ gap = 0.075 },
			{ role = "both", relIntensity = 0.90, relDuration = 0.60 },
		},
	},

	-- ── Added 2026-09-21 from "Pulse — Proposed New Vibration Modes.md" ────────
	-- Seven of the eight proposed. RAMP was rejected on the proposal's own advice: a smooth
	-- linear build is what RISING already is, and a near-duplicate is worse than a missing
	-- mode. Every shape below is a starting point, UNFELT, and distinctness partly depends
	-- on breakaway floor and response time — judge them on a calibrated pad.
	BURST = {
		label = "A dense 3-pulse tactical flurry.",
		baseDuration = 0.050,
		steps = {
			{ role = "high", relIntensity = 0.95, relDuration = 0.8 },
			{ gap = 0.055 },
			{ role = "both", relIntensity = 0.80, relDuration = 0.8 },
			{ gap = 0.055 },
			{ role = "high", relIntensity = 1.00, relDuration = 1.0 },
		},
	},
	-- Deliberately shorter and harder than THUD: THUD is an impact you feel land, IMPACT
	-- is one that is over before you register it.
	IMPACT = {
		label = "A single very short, very hard hit.",
		baseDuration = 0.07,
		steps = { { role = "both", relIntensity = 1.0, relDuration = 1.0 } },
	},
	-- High motor only, near-instant, with a tiny low-motor tail so it reads as a snap
	-- rather than a click.
	CRACK = {
		label = "A sharp snap with a short tail.",
		baseDuration = 0.05,
		steps = {
			{ role = "high", relIntensity = 1.0, relDuration = 1.0 },
			{ role = "low", relIntensity = 0.25, relDuration = 1.4 },
		},
	},
	-- The lightest discrete shape in the vocabulary, for UI confirmation where TICK is
	-- still too much. Sits below TICK deliberately.
	CLICK = {
		label = "A single dry click, lighter than a tick.",
		baseDuration = 0.030,
		steps = { { role = "high", relIntensity = 0.38, relDuration = 1.0 } },
	},
	-- Starts firm and decays in two steps: deceleration, not impact.
	BRAKE = {
		label = "A firm hit that bleeds away — slowing to a stop.",
		baseDuration = 0.14,
		steps = {
			{ role = "both", relIntensity = 0.75, relDuration = 1.0 },
			{ role = "low", relIntensity = 0.40, relDuration = 1.6 },
			{ role = "low", relIntensity = 0.22, relDuration = 1.8 },
		},
	},
	-- One low blip. For high-frequency, low-importance signals where even TICK would
	-- accumulate into noise.
	BLIP = {
		label = "A tiny low blip, for things that happen often.",
		baseDuration = 0.050,
		steps = { { role = "low", relIntensity = 0.48, relDuration = 1.0 } },
	},
	-- Alternates motors so the sensation moves across the pad rather than sitting still.
	WOBBLE = {
		label = "Alternates between the motors — an unsteady, rolling feel.",
		baseDuration = 0.09,
		steps = {
			{ role = "low", relIntensity = 0.55, relDuration = 1.0 },
			{ role = "high", relIntensity = 0.55, relDuration = 1.0 },
			{ role = "low", relIntensity = 0.45, relDuration = 1.0 },
			{ role = "high", relIntensity = 0.35, relDuration = 1.0 },
		},
	},

	-- ── Punchy patterns and tactile transients (formerly trigger modes) ──────────
	-- Reprogrammed from phantom trigger channels to Low and High rumble motors.
	SNAP = {
		label = "A crisp mechanical snap on the high motor.",
		baseDuration = 0.04,
		steps = { { role = "high", relIntensity = 0.95, relDuration = 1.0 } },
	},
	DRAW = {
		label = "Progressive low build leading to a sharp high break.",
		baseDuration = 0.10,
		steps = {
			{ role = "low", relIntensity = 0.40, relDuration = 0.8 },
			{ role = "low", relIntensity = 0.75, relDuration = 1.0 },
			{ gap = 0.050 },
			{ role = "high", relIntensity = 1.00, relDuration = 0.6 },
		},
	},
	MICRO_TAP = {
		label = "A firm mechanical detent on the high motor.",
		baseDuration = 0.040,
		steps = { { role = "high", relIntensity = 0.65, relDuration = 1.0 } },
	},
	STACCATO = {
		label = "Rapid staccato triple-click on the high motor.",
		baseDuration = 0.050,
		steps = {
			{ role = "high", relIntensity = 0.80, relDuration = 0.7 },
			{ gap = 0.050 },
			{ role = "high", relIntensity = 0.90, relDuration = 0.7 },
			{ gap = 0.050 },
			{ role = "high", relIntensity = 1.00, relDuration = 0.8 },
		},
	},
	RECOIL = {
		label = "Sharp high kick layered with heavy low kick and rumble decay.",
		baseDuration = 0.10,
		steps = {
			{ role = "high", relIntensity = 1.00, relDuration = 0.7 },
			{ role = "both", relIntensity = 0.75, relDuration = 0.9 },
			{ role = "low", relIntensity = 0.30, relDuration = 1.0 },
		},
	},
	SHUTTLE = {
		label = "Alternating low thud and high snap across motors.",
		baseDuration = 0.08,
		steps = {
			{ role = "low", relIntensity = 0.80, relDuration = 1.0 },
			{ gap = 0.05 },
			{ role = "high", relIntensity = 0.80, relDuration = 1.0 },
		},
	},
	TENSION = {
		label = "Three-stage rising tension building on the low motor.",
		baseDuration = 0.08,
		steps = {
			{ role = "low", relIntensity = 0.30, relDuration = 0.8 },
			{ role = "low", relIntensity = 0.60, relDuration = 0.8 },
			{ role = "low", relIntensity = 0.95, relDuration = 1.0 },
		},
	},

	-- ── Continuous, held by the caller every tick it applies ───────────────────
	--
	-- None of these five is read by a real trigger: every continuous trigger in this addon
	-- (breathTexture, swimTexture, glideThrust, castTexture, taxiRide, lowHealthTexture)
	-- computes its own low/high in its own module. These exist as vocabulary for the
	-- panel's "Mode to test" preview.
	--
	-- That matters for PATTER and DRIFT, whose labels claim a time-varying quality
	-- ("irregular", "a fade") a flat {low, high} pair cannot express, so testing either
	-- demonstrated nothing the label promised. `previewPattern` tells Engine:PlayMode's
	-- continuous branch to schedule a real sequence for the preview button instead.
	-- HUM/THRUM/WAVE keep the flat-hold preview: "steady" and "oscillation, phase supplied
	-- by the caller" honestly describe what a real caller does with these numbers.
	PATTER = {
		label = "Low, irregular micro-pulses — rain, patter.",
		continuous = true,
		low = 0.15,
		high = 0.0,
		previewPattern = "jitter",
	},
	HUM = {
		label = "A steady, low ambient texture.",
		continuous = true,
		low = 0.25,
		high = 0.0,
	},
	THRUM = {
		label = "A steady, stronger texture — meant to be scaled by the caller (e.g. speed).",
		continuous = true,
		low = 0.0,
		high = 0.4,
	},
	WAVE = {
		label = "A slow low/high oscillation — the caller supplies the phase.",
		continuous = true,
		low = 0.2,
		high = 0.2,
	},
	DRIFT = {
		label = "A barely-there fade, for the quietest ambient onset.",
		continuous = true,
		low = 0.08,
		high = 0.0,
		previewPattern = "fade",
	},
}

-- Backward compatibility aliases: existing profiles or external callers requesting
-- legacy TRIGGER_* mode names seamlessly map to the reprogrammed Low/High shapes.
Pulse.Modes.TRIGGER_CLICK = Pulse.Modes.SNAP
Pulse.Modes.TRIGGER_PULL = Pulse.Modes.DRAW
Pulse.Modes.TRIGGER_TAP = Pulse.Modes.MICRO_TAP
Pulse.Modes.TRIGGER_BURST = Pulse.Modes.STACCATO
Pulse.Modes.TRIGGER_RECOIL = Pulse.Modes.RECOIL
Pulse.Modes.TRIGGER_ALTERNATE = Pulse.Modes.SHUTTLE
Pulse.Modes.TRIGGER_TENSION = Pulse.Modes.TENSION

-- Ordered list for the settings panel's "Test a mode" picker, not alphabetical — grouped
-- the way the comments above group them.
Pulse.ModeOrder = {
	"TAP",
	"DOUBLE_TAP",
	"TRIPLE_TAP",
	"LONG",
	"HEAVY",
	"STUTTER",
	"RISING",
	"FALLING",
	"THUD",
	"THUMP",
	"DEFLECT",
	"TICK",
	"CHIME",
	"KNOCK",
	"SURGE",
	"PULSE_BEAT",
	"BURST",
	"IMPACT",
	"CRACK",
	"CLICK",
	"BRAKE",
	"BLIP",
	"WOBBLE",
	"SNAP",
	"DRAW",
	"MICRO_TAP",
	"STACCATO",
	"RECOIL",
	"SHUTTLE",
	"TENSION",
	"PATTER",
	"HUM",
	"THRUM",
	"WAVE",
	"DRIFT",
}

-- Derived per-mode role usage and multiplier ceilings, computed once from the authored
-- steps above rather than hand-maintained — self-updating when a mode's shape changes, and
-- impossible to typo out of sync with it. Continuous modes are excluded: none is read by a
-- real trigger, so tuning them would only affect the preview button.
--
-- hasLow/hasHigh/hasTrigger: does ANY step use that role? A mode that never touches a motor
-- has nothing for that multiplier slider to scale, so the panel skips it rather than
-- showing a dead control.
--
-- lowCeiling/highCeiling/triggerCeiling: the highest sensible multiplier for that role, derived
-- as 1.0 / (that role's peak relIntensity across this mode's steps). Past that point
-- Engine:PlayMode's clamp01 caps the result at 1.0 anyway, so the slider's max is where it
-- stops doing anything rather than an arbitrary round number shared by every mode.
Pulse.ModeRoleInfo = {}
for modeID, mode in pairs(Pulse.Modes) do
	if not mode.continuous then
		local peakLow, peakHigh, peakTrigger = 0, 0, 0
		for _, step in ipairs(mode.steps) do
			if not step.gap then
				if step.role == "low" or step.role == "both" then
					peakLow = math.max(peakLow, step.relIntensity)
				end
				if step.role == "high" or step.role == "both" then
					peakHigh = math.max(peakHigh, step.relIntensity)
				end
				if step.role == "ltrigger" or step.role == "rtrigger" then
					peakTrigger = math.max(peakTrigger, step.relIntensity)
				end
			end
		end
		Pulse.ModeRoleInfo[modeID] = {
			hasLow = peakLow > 0,
			lowCeiling = peakLow > 0 and (1.0 / peakLow) or 1.0,
			hasHigh = peakHigh > 0,
			highCeiling = peakHigh > 0 and (1.0 / peakHigh) or 1.0,
			hasTrigger = peakTrigger > 0,
			triggerCeiling = peakTrigger > 0 and (1.0 / peakTrigger) or 1.0,
		}
	end
end

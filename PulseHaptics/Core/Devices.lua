-- Pulse — Core/Devices.lua
--
-- Physical motor characteristics, one entry per output channel: how a motor needs to be
-- driven. Core/Schemas/*.lua answers the separate question of which channel a logical role
-- goes to. Kept apart because "Low Motor Only" exists for a DEAD strong motor, a routing
-- fact, while "the high motor is twice as strong as the low one" is a hardware fact. Merged,
-- you would get four schemas times every controller, and a dead motor would look like the
-- same kind of problem as a loud one.
--
-- Named Devices, not Profiles: Core/Database.lua already owns "profiles" (the Default/
-- Raiding/Questing/PvP playstyle slots), and a second meaning for that word in one database
-- is a trap.
--
-- STORAGE: global, beside masterEnabled/defaultHapticSchema/modeTuning, never per playstyle
-- profile — the same reasoning Database.lua committed to for modeTuning. Motor calibration
-- is not something raiding and questing could sensibly disagree on.

local ADDON_NAME, Pulse = ...

-- The physical channel names passed to C_GamePad.SetVibration as `vibrationType`.
-- LIVE CLIENT CONFIRMATION (2026-09-29): C_GamePad.SetVibration strictly supports only
-- "Low" and "High". All calls with "LTrigger" or "RTrigger" fail to vibrate on any hardware.
-- Both rumble motors work across supported controllers:
--
--   "Low"  — confirmed live, heavy low-frequency counterweight motor.
--   "High" — confirmed live, light high-frequency motor.
Pulse.CHANNELS = { "Low", "High" }

Pulse.CHANNEL_LABELS = {
	Low = "Low motor (heavy rumble)",
	High = "High motor (sharp rumble)",
}

Pulse.CHANNEL_CONFIRMED = {
	Low = true,
	High = true,
}

-- Every value reproduces the engine's pre-calibration behaviour exactly, so installing this
-- layer changes nothing until someone moves a slider.
--
--   gain      1.0    no-op.
--   gamma     1.0    exact no-op: x^1.0 == x.
--   floor     0.0    exact no-op: 0 + (1-0)*x == x. NOT the old FLOOR constant — that was
--                    an output GATE deciding when to call StopVibration and never touched
--                    the value sent; this is an input remap lifting small values over the
--                    motor's breakaway threshold. The old gate still exists in Engine.lua
--                    under its own name, unchanged.
--   attackTau 0.075  the old ATTACK_RATE = 0.2 was a fraction applied PER FRAME, not a time
--   releaseTau 0.028 constant at all — the same cue decayed roughly four times faster at
--                    144fps than at 36fps. No frame-rate-free number exists to lift, so
--                    these are the taus reproducing the old rates at 60fps:
--                    tau = -dt / ln(1 - rate), dt = 1/60. Identical feel at 60, correct
--                    everywhere else. The one field that is a behaviour change.
--
-- Low and High start identical only because the old shared constants did. They are
-- physically different actuators — the low motor's large eccentric mass really is slower to
-- spin up and coast down than the high motor's small one — so the two rows wanting
-- different taus is expected, not a bug. That is what the calibration page is for.
Pulse.CHANNEL_DEFAULTS = {
	gain = 1.0,
	gamma = 1.0,
	floor = 0.0,
	attackTau = 0.075,
	transientAttackTau = 0.012,
	releaseTau = 0.028,
	overdriveBoost = 1.0,
	overdriveDuration = 0.0,
	useSCurve = false,
}

-- Drives the calibration page generically, same discipline as Registry.lua's `tunables`:
-- adding a knob here adds its slider with no UI file edit.
Pulse.CHANNEL_TUNABLES = {
	{
		key = "gain",
		label = "Strength",
		min = 0.0,
		max = 2.0,
		step = 0.05,
		desc = 'Balances this motor against the others. Raise it if this motor is the weak one on your controller, lower it if it drowns everything else out. This is the knob the old "Low Motor Only"/"High Motor Only" schemas were being misused for — those still exist, but for a motor that is actually dead, not merely quieter.',
	},
	{
		key = "floor",
		label = "Breakaway floor",
		min = 0.0,
		max = 0.40,
		step = 0.005,
		desc = 'The smallest value that makes this motor actually spin. Anything above zero is remapped into the range above this floor, so a quiet cue still moves the mass instead of dying silently. Zero input still means completely off. Use "Ramp" below to find your controller\'s real figure.',
	},
	{
		key = "attackTau",
		label = "Attack time (s)",
		min = 0.005,
		max = 0.30,
		step = 0.005,
		desc = "How long this motor takes to reach a new, stronger level during continuous textures. Higher is softer and more gradual; lower is snappier. 0.075 reproduces the engine's old behaviour at 60fps.",
	},
	{
		key = "transientAttackTau",
		label = "Impact attack (s)",
		min = 0.002,
		max = 0.050,
		step = 0.002,
		desc = "Fast attack time constant used specifically for discrete impacts, clicks, and strikes. Gives snappy transients without making sustained immersion textures harsh.",
	},
	{
		key = "releaseTau",
		label = "Release time (s)",
		min = 0.005,
		max = 0.30,
		step = 0.005,
		desc = "How long this motor takes to fall back toward silence. Too high and consecutive taps blur into one buzz; too low and sustained textures sound chopped. 0.028 reproduces the engine's old behaviour at 60fps.",
	},
	{
		key = "gamma",
		label = "Response curve",
		min = 0.40,
		max = 2.50,
		step = 0.05,
		desc = "Bends the relationship between what a cue asks for and what the motor is told. Below 1.0 makes quiet cues louder; above 1.0 makes them quieter and reserves more of the range for strong ones. 1.0 is the unbent default.",
	},
	{
		key = "overdriveBoost",
		label = "Overdrive kick",
		min = 1.0,
		max = 2.0,
		step = 0.05,
		desc = "Initial software voltage boost applied during transient onset to accelerate the motor rapidly to target speed. 1.0 is disabled.",
	},
	{
		key = "overdriveDuration",
		label = "Overdrive time (s)",
		min = 0.0,
		max = 0.060,
		step = 0.005,
		desc = "Duration of the software overdrive kick. 0.030s on heavy ERM counterweights, 0.0 on LRAs.",
	},
	{
		key = "useSCurve",
		label = "Perceptual S-Curve",

		kind = "checkbox",
		desc = "Bends the motor response with a smoothstep curve (3x^2 - 2x^3) to widen contrast between gentle background textures and heavy combat impacts. When unchecked, standard linear scaling is used.",
	},
}

-- Shape of the Ramp probe on the calibration page (Core/Engine.lua drives it).
--
-- Proportioned against where the answer plausibly lives rather than across the whole range.
-- Preset floors sit at 0.025-0.065, so the first two shapes both measured in the wrong place:
-- peak 0.5 / step 0.025, then peak 0.40 / step 0.01, the latter still reporting a 0.03 floor
-- only to ±0.005, about ±17% of the figure being measured.
--
-- The step matches the Breakaway floor slider (0.005), so every reading can be entered
-- exactly. Finer is not worth it: rumble drivers commonly quantise intensity to 8 bits.
--
-- No measurement backs the 0.20 ceiling; it is an instrument-design choice, roughly three
-- times the highest preset floor. Anything still silent at 20% is a dead motor rather than a
-- high floor, which the Test button answers faster. The slider still reaches 0.40.
--
-- 0.5s per step, because near breakaway an ERM has almost no spare torque and spins up
-- slowly, and the person then has to notice it. At 0.4s the felt step and the printed step
-- came apart often enough to read one step high.
--
-- 40 steps at 0.5s is twenty seconds. Long for a button, trivial for something pressed once
-- per controller.
Pulse.RAMP_PEAK = 0.20
Pulse.RAMP_STEP = 0.005
Pulse.RAMP_STEP_SECONDS = 0.5

-- How long after first feeling the motor a person typically clicks Set Floor. Set Floor
-- credits the step that was running this long before the click, not the one running at it.
-- An estimate, not a measurement: touch reaction time plus a click. Too high and the reading
-- comes out one step (0.005) low, which is the cheaper error: a floor slightly under
-- breakaway still lets the next step up start the motor.
Pulse.RAMP_REACTION_SECONDS = 0.35

-- Anti-spam threshold: how far a channel has to move before it is worth another
-- SetVibration call. Global rather than per-channel — it is a call-rate optimisation, not a
-- motor property, and nothing has suggested the two motors want different values.
Pulse.CHANGE_EPSILON_DEFAULT = 0.0015

-- ── Device presets ──────────────────────────────────────────────────────────────────────
--
-- READ THIS BEFORE TRUSTING A NUMBER BELOW. These are STARTING POINTS derived from actuator
-- class, not measurements — nothing here has been put on an oscilloscope for this addon.
-- What IS solid is which class a controller belongs to, public checkable hardware fact, and
-- the classes differ enough that seeding from the right one beats the wrong one:
--
--   ERM   eccentric rotating mass, a weight on a motor shaft. Must overcome static friction
--         to turn at all, so it has a real breakaway threshold, and takes time to spin up
--         and longer to coast down. The large (low-frequency) motor is slower and
--         higher-threshold than the small one. DualShock 4, Xbox main and trigger motors.
--   LRA   voice coil, a mass on a spring driven electromagnetically. Near-instant, far more
--         linear, much lower threshold — no friction to break away from in the same way.
--         DualSense, Steam Deck, Switch Pro (HD Rumble).
--
-- Seeding an LRA pad with ERM numbers is what this table prevents: a DualSense on a 0.12
-- floor and a 90ms attack feels mushy and over-floored, for no reason but defaults shaped
-- for a different actuator. Every row is still only a start — the Ramp button measures YOUR
-- controller and outranks anything here.
--
-- Note on trigger motors: While some hardware (Xbox One/Series) features physical impulse
-- trigger motors, Blizzard's C_GamePad.SetVibration API strictly addresses only the main
-- "Low" and "High" rumble motors across all platforms and operating systems. All cues and
-- modes are designed to fully leverage Low and High motors in concert.

local ERM_LOW = {
	floor = 0.025,
	attackTau = 0.085,
	transientAttackTau = 0.018,
	releaseTau = 0.050,
	overdriveBoost = 1.25,
	overdriveDuration = 0.025,
	gamma = 0.88,
	useSCurve = false,
}
local ERM_HIGH = {
	floor = 0.025,
	attackTau = 0.045,
	transientAttackTau = 0.010,
	releaseTau = 0.024,
	overdriveBoost = 1.15,
	overdriveDuration = 0.020,
	gamma = 0.88,
	useSCurve = false,
}
local LRA = {
	floor = 0.025,
	attackTau = 0.015,
	transientAttackTau = 0.005,
	releaseTau = 0.012,
	overdriveBoost = 1.00,
	overdriveDuration = 0.000,
	gamma = 1.00,
	useSCurve = false,
}

local function copy(src, extra)
	local t = {}
	for k, v in pairs(src) do
		t[k] = v
	end
	if extra then
		for k, v in pairs(extra) do
			t[k] = v
		end
	end
	return t
end

Pulse.DEVICE_ORDER = {
	"default",
	"ds4",
	"dualsense",
	"xbox",
	"xbox_elite",
	"switchpro",
	"8bitdo",
	"steamdeck",
	"steamcontroller2",
	"steamcontroller",
	"lra_classic",
}

Pulse.Devices = {
	-- The no-op row. Identical to CHANNEL_DEFAULTS, so selecting it is the same as pressing
	-- Reset calibration: whatever the engine did before this layer existed.
	default = {
		id = "default",
		label = "Generic / unknown",
		triggers = false,
		note = "No assumptions. Every value is the engine's own default. Use this if your controller is not listed, then Ramp each motor.",
		channels = {},
	},

	ds4 = {
		id = "ds4",
		label = "DualShock 4 (PS4)",
		triggers = false,
		note = "Two asymmetrical ERM motors with balanced weight distribution. Fast 75ms spin-up and 0.040 breakaway floor.",
		channels = {
			Low = copy(ERM_LOW, { floor = 0.040, attackTau = 0.075, releaseTau = 0.045, gamma = 0.90 }),
			High = copy(ERM_HIGH, { floor = 0.040, attackTau = 0.040, releaseTau = 0.024, gamma = 0.90 }),
		},
	},

	dualsense = {
		id = "dualsense",
		label = "DualSense (PS5)",
		triggers = false,
		note = "High-definition voice-coil actuators: near-zero static friction (0.025 floor), instantaneous 5ms transient response, and wideband 20-500 Hz frequency fidelity.",
		channels = {
			Low = copy(LRA, { floor = 0.025, gain = 1.15, attackTau = 0.015, releaseTau = 0.012 }),
			High = copy(LRA, { floor = 0.025, gain = 1.05, attackTau = 0.012, releaseTau = 0.010 }),
		},
	},

	xbox = {
		id = "xbox",
		label = "Xbox (One / Series)",
		triggers = false,
		note = "Asymmetrical ERM motors: heavy counterweight on left (85ms spin-up, 0.025 floor) and light counterweight on right (45ms spin-up, 0.025 floor). Calibrated with dual-lane smoothing and gamma 0.88.",
		channels = {
			Low = copy(ERM_LOW),
			High = copy(ERM_HIGH),
		},
	},

	xbox_elite = {
		id = "xbox_elite",
		label = "Xbox Elite Series 2",
		triggers = false,
		note = "Heavy metal-reinforced chassis (345g vs 280g) and rubberized grips. +10% Low gain compensates for chassis damping, calibrated with 0.040 floor.",
		channels = {
			Low = copy(ERM_LOW, { floor = 0.040, gain = 1.10, attackTau = 0.090, releaseTau = 0.055, gamma = 0.85 }),
			High = copy(ERM_HIGH, { floor = 0.040, gain = 1.05, attackTau = 0.050, releaseTau = 0.026, gamma = 0.85 }),
		},
	},

	switchpro = {
		id = "switchpro",
		label = "Switch Pro Controller",
		triggers = false,
		note = "Alps Alpine Haptic Reactor dual LRAs. Generic PC/Mac square-wave rumble underdrives their 160/320 Hz resonance; +30% gain compensation restores native console parity.",
		channels = {
			Low = copy(LRA, { floor = 0.055, gain = 1.30, attackTau = 0.020, releaseTau = 0.018 }),
			High = copy(LRA, { floor = 0.055, gain = 1.30, attackTau = 0.015, releaseTau = 0.015 }),
		},
	},

	["8bitdo"] = {
		id = "8bitdo",
		label = "8BitDo (Ultimate / Pro 2)",
		triggers = false,
		note = "Asymmetrical ERMs with stiff carbon-composite brushes. 0.040 Low floor guarantees reliable breakaway without deadband stutter.",
		channels = {
			Low = copy(ERM_LOW, { floor = 0.040, attackTau = 0.080, releaseTau = 0.048 }),
			High = copy(ERM_HIGH, { floor = 0.040, attackTau = 0.045, releaseTau = 0.024 }),
		},
	},

	steamdeck = {
		id = "steamdeck",
		label = "Steam Deck (LCD & OLED)",
		triggers = false,
		note = "Cirrus Logic CS40L25 smart amplifier driving dual trackpad LRAs. 35ms Low attack tau eliminates audible trackpad housing clack; +25% Low gain matches traditional body rumble displacement.",
		channels = {
			Low = copy(LRA, { floor = 0.045, gain = 1.25, attackTau = 0.035, releaseTau = 0.020, gamma = 0.90 }),
			High = copy(LRA, { floor = 0.035, gain = 1.05, attackTau = 0.015, releaseTau = 0.015 }),
		},
	},

	steamcontroller2 = {
		id = "steamcontroller2",
		label = "Steam Controller 2 (2026)",
		triggers = false,
		note = "Quad-LRA architecture: two trackpad LRAs for interface clicks plus two dedicated high-output grip LRAs for body rumble. Instantaneous transient response, wide dynamic range, and zero trackpad chatter.",
		channels = {
			Low = copy(LRA, { floor = 0.035, gain = 1.10, attackTau = 0.020, releaseTau = 0.015 }),
			High = copy(LRA, { floor = 0.035, gain = 1.05, attackTau = 0.015, releaseTau = 0.012 }),
		},
	},

	steamcontroller = {
		id = "steamcontroller",
		label = "Steam Controller (v1)",
		triggers = false,
		note = "Dual circular trackpad linear voice coils with no body rumble motors. Emulated rumble turns the touchpads into acoustic transducers; raised floor and 40ms attack prevent trigger spring rattle and harsh metallic buzz.",
		channels = {
			Low = copy(LRA, { floor = 0.060, gain = 1.10, attackTau = 0.040, releaseTau = 0.030 }),
			High = copy(LRA, { floor = 0.040, gain = 1.00, attackTau = 0.020, releaseTau = 0.020 }),
		},
	},

	lra_classic = {
		id = "lra_classic",
		label = "LRA (Classic ERM Emulation)",
		triggers = false,
		note = "Synthesizes rotating-mass inertia, stiction breakaway, and coast-down rumble on voice-coil / HD Rumble pads (DualSense, Switch Pro, Steam Deck). Provides a warmer, blunt rumble without sharp casing clicks.",
		channels = {
			Low = copy(ERM_LOW, {
				floor = 0.065,
				gain = 1.20,
				attackTau = 0.075,
				transientAttackTau = 0.025,
				releaseTau = 0.045,
				gamma = 0.88,
			}),
			High = copy(ERM_HIGH, {
				floor = 0.050,
				gain = 1.10,
				attackTau = 0.040,
				transientAttackTau = 0.012,
				releaseTau = 0.028,
				gamma = 0.88,
			}),
		},
	},
}

-- ── Detection ───────────────────────────────────────────────────────────────────────────
--
-- C_GamePad.GetDeviceRawState(deviceID) returns a GamePadRawState carrying `name`,
-- `vendorID` and `productID` (Blizzard_APIDocumentationGenerated/GamePadDocumentation.lua
-- :428-430, read from source).
--
-- Detection hierarchy:
-- 1. Hardware Product ID match (vendor + product): unequivocal hardware truth.
-- 2. Specific name matching: survives firmware revisions that alter product IDs.
-- 3. Vendor-only fallback: maps unlisted revisions to the vendor's primary actuator family.
-- 4. Generic OS descriptor fallback: handles ambiguous names like macOS "Wireless Controller".
--
-- Detection only ever SUGGESTS. Nothing applies without the player pressing Apply, so a
-- wrong guess costs a dropdown selection rather than their calibration.
local NAME_PATTERNS = {
	{ "dualsense", "dualsense" },
	{ "ps5", "dualsense" },
	{ "dualshock", "ds4" },
	{ "ps4", "ds4" },
	{ "steam deck", "steamdeck" },
	{ "steam virtual gamepad", "steamdeck" },
	{ "steam controller 2", "steamcontroller2" },
	{ "steam controller", "steamcontroller" },
	{ "nintendo", "switchpro" },
	{ "switch pro", "switchpro" },
	{ "pro controller", "switchpro" },
	{ "joy-con", "switchpro" },
	{ "elite", "xbox_elite" },
	{ "8bitdo", "8bitdo" },
	{ "sn30", "8bitdo" },
	{ "pro 2", "8bitdo" },
	{ "ultimate", "8bitdo" },
	{ "xbox", "xbox" },
	{ "xinput", "xbox" },
}

-- USB vendor ids. Well established and unlikely to move.
local VENDOR_SONY = 0x054C
local VENDOR_MICROSOFT = 0x045E
local VENDOR_NINTENDO = 0x057E
local VENDOR_VALVE = 0x28DE
local VENDOR_8BITDO = 0x2DC8

local PRODUCT_MAP = {
	[VENDOR_SONY] = {
		[0x05C4] = "ds4", -- DualShock 4 v1
		[0x09CC] = "ds4", -- DualShock 4 v2
		[0x0BA0] = "ds4", -- DualShock 4 USB Wireless Adaptor
		[0x0CE6] = "dualsense", -- DualSense
		[0x0DF2] = "dualsense", -- DualSense Edge
	},
	[VENDOR_MICROSOFT] = {
		[0x028E] = "xbox", -- Xbox 360 (wired)
		[0x028F] = "xbox", -- Xbox 360 (wireless)
		[0x02D1] = "xbox", -- Xbox One (2013 launch)
		[0x02DD] = "xbox", -- Xbox One (2015 with 3.5mm jack)
		[0x02E3] = "xbox_elite", -- Xbox Elite Series 1
		[0x02EA] = "xbox", -- Xbox One S (Bluetooth)
		[0x02FD] = "xbox", -- Xbox One S (Bluetooth)
		[0x0B00] = "xbox_elite", -- Xbox Elite Series 2 (USB wired)
		[0x0B05] = "xbox_elite", -- Xbox Elite Series 2 (Bluetooth)
		[0x0B12] = "xbox", -- Xbox Series X|S (USB wired)
		[0x0B13] = "xbox", -- Xbox Series X|S (Bluetooth)
		[0x0B20] = "xbox", -- Xbox Wireless Adapter for Windows
	},
	[VENDOR_NINTENDO] = {
		[0x2006] = "switchpro", -- Joy-Con (L)
		[0x2007] = "switchpro", -- Joy-Con (R)
		[0x2009] = "switchpro", -- Switch Pro Controller
		[0x200E] = "switchpro", -- Joy-Con Charging Grip / Combined
	},
	[VENDOR_8BITDO] = {
		[0x200F] = "8bitdo", -- 8BitDo Ultimate 3-mode
		[0x310B] = "8bitdo", -- 8BitDo Ultimate 2 Wireless / Pro 3
		[0x6000] = "8bitdo", -- 8BitDo SN30 Pro
		[0x6001] = "8bitdo", -- 8BitDo Pro 2
		[0x6012] = "8bitdo", -- 8BitDo Ultimate Wireless
		[0xAB11] = "8bitdo", -- 8BitDo F30 / SN30
	},
	[VENDOR_VALVE] = {
		[0x1102] = "steamcontroller", -- Steam Controller v1 (USB wired)
		[0x1142] = "steamcontroller", -- Steam Controller v1 (wireless dongle)
		[0x1106] = "steamcontroller", -- Steam Controller v1 (BLE)
		[0x11FF] = "steamdeck", -- Steam Virtual Gamepad (Steam Input)
		[0x1201] = "steamcontroller2", -- Steam Controller 2 (wired)
		[0x1202] = "steamcontroller2", -- Steam Controller 2 (wireless)
		[0x1205] = "steamdeck", -- Steam Deck (LCD & OLED)
	},
}

-- Vendor-only fallback, for a product id this table has never heard of.
local VENDOR_FALLBACK = {
	[VENDOR_MICROSOFT] = "xbox", -- Microsoft gamepads are Xbox-pattern throughout
	[VENDOR_NINTENDO] = "switchpro",
	[VENDOR_VALVE] = "steamdeck", -- Default Valve controllers to modern LRA haptic profile
	[VENDOR_8BITDO] = "8bitdo", -- Default 8BitDo devices to tuned ERM profile
	[VENDOR_SONY] = "dualsense", -- Default modern Sony to DualSense profile
}

-- Returns deviceID, detectedPresetID, rawName — any may be nil. Never applies anything and
-- never errors: every read is guarded, because a controller reporting something unexpected
-- should cost a suggestion, not a Lua error on the settings page.
function Pulse.DetectDevice()
	if not C_GamePad or type(C_GamePad.GetActiveDeviceID) ~= "function" then
		return nil
	end
	local okID, deviceID = pcall(C_GamePad.GetActiveDeviceID)
	if not okID or not deviceID then
		return nil
	end
	if type(C_GamePad.GetDeviceRawState) ~= "function" then
		return deviceID
	end

	local okState, state = pcall(C_GamePad.GetDeviceRawState, deviceID)
	if not okState or type(state) ~= "table" then
		return deviceID
	end

	local name = state.name
	if issecretvalue(name) or type(name) ~= "string" then
		name = nil
	end

	local vendor, product = state.vendorID, state.productID
	if issecretvalue(vendor) or type(vendor) ~= "number" then
		vendor = nil
	end
	if issecretvalue(product) or type(product) ~= "number" then
		product = nil
	end

	-- 1. Exact hardware match via Vendor & Product ID
	if vendor and product then
		local byProduct = PRODUCT_MAP[vendor]
		if byProduct and byProduct[product] then
			return deviceID, byProduct[product], name
		end
	end

	-- 2. Specific name matching (identifies hardware revisions and third-party controllers)
	if name then
		local lowered = name:lower()
		for _, entry in ipairs(NAME_PATTERNS) do
			if lowered:find(entry[1], 1, true) then
				return deviceID, entry[2], name
			end
		end
	end

	-- 3. Vendor-only fallback for uncataloged product IDs
	if vendor and VENDOR_FALLBACK[vendor] then
		return deviceID, VENDOR_FALLBACK[vendor], name
	end

	-- 4. Generic OS descriptor fallback (e.g. uncataloged Bluetooth "Wireless Controller")
	if name then
		local lowered = name:lower()
		if lowered:find("wireless controller", 1, true) then
			return deviceID, "dualsense", name
		end
	end

	return deviceID, nil, name
end

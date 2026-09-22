-- Pulse — Core/Registry.lua
--
-- The trigger table: one source of truth, driving both event registration and the settings
-- panel, with no hand-duplicated list anywhere else. G-numbers reference alphafeatures.md.
-- G8 (melee swing) and G11 (terrain footsteps) are deliberately absent — the former is a
-- guessed metronome wearing a combat cue's clothing, the latter has no confirmed API.
--
-- `mode` names one of the 21 Core/Modes.lua shapes for a discrete trigger. A `continuous`
-- trigger has no `mode` here — its module calls Pulse:HoldIfEnabled directly every tick,
-- since a held texture's low/high mix is usually computed live (scaled by speed, by
-- depletion, …), not a fixed lookup.

local ADDON_NAME, Pulse = ...

local Registry = {}
Pulse.Registry = Registry

-- Two blocks — native game-feel, then accessibility imported from Tremor — each sorted
-- alphabetically by label within the block (2026-09-15). Deliberately not flattened into
-- one global list: the settings sidebar cannot show a sub-header within a flat tab list, so
-- the block split is the only thing keeping the accessibility tabs grouped rather than
-- scattered wherever their labels fall.
--
-- ENCOUNTER folded into COMBAT the same day (bossAbilityWarning was its only member).
-- ALERT_EXPERIMENTAL removed 2026-09-16: it grouped by provenance rather than by subject,
-- so its three cues moved to where they belong — resourceCapped into COMBAT,
-- targetCastStopped into ALERT_UNIT_WATCH, actionFailed into ALERT_SELF_CAST — keeping the
-- "untested, default-off, say so in the caveat" treatment instead of a segregated tab.
local CATEGORY_ORDER = {
	"COMBAT",
	"ENVIRONMENT",
	"HEALTH",
	"FLIGHT",
	"MOVEMENT",
	"WORLD",
	"ALERT_STATE",
	"ALERT_DEVICE",
	"ALERT_SOCIAL",
	"ALERT_CC",
	"ALERT_UNIT_WATCH",
	"ALERT_THREAT",
	"ALERT_WORLD",
	"ALERT_SELF_CAST",
	"CONTROLLER_UI",
	"GAMEPAD_INTERACT",
}
local CATEGORY_LABELS = {
	MOVEMENT = "Movement",
	FLIGHT = "Flight and mounts",
	COMBAT = "Combat texture",
	ENVIRONMENT = "Environment",
	-- Disambiguated from ALERT_WORLD below. Both are about "the world" from different
	-- provenances and shared the bare word "World" despite having little to do with each
	-- other: 6 loot/gear/flavour cues here, 17 vendor/quest/UI-window cues there.
	WORLD = "World (game-feel)",
	-- Shortened 2026-09-15: the full "(may not work, may change without notice)" wording
	-- made this title collide with Blizzard's "Defaults" button in the same top-right
	-- corner — CONFIRMED from a screenshot, not guessed. The warning is not lost, only moved
	-- off the title; every cue here carries it on its own tooltip.
	HEALTH = "Experimental (game-feel)",

	ALERT_SELF_CAST = "Your casting",
	ALERT_CC = "Loss of control",
	ALERT_THREAT = "Threat",
	ALERT_UNIT_WATCH = "Target and focus",
	ALERT_STATE = "Combat and life state",
	ALERT_SOCIAL = "Group and social",
	ALERT_WORLD = "World (accessibility)",
	ALERT_DEVICE = "Controller",

	-- Forever's native controller-UI interaction cues (Modules/ControllerUI.lua). Its own
	-- category rather than folded into ALERT_DEVICE: that is device state (battery, connect,
	-- disconnect), this is the player driving the interface. A category as well as a page so
	-- PulseDebug and PulseChecklist, which group by category, list them sensibly.
	CONTROLLER_UI = "Controller UI",

	-- The other half of the native controller story. CONTROLLER_UI is the player moving
	-- through the interface; this is the controller acting on the WORLD — what is under the
	-- reticle, on the cursor, which bar is live, which input device drives. Separate
	-- category so PulseDebug and PulseChecklist list the two apart.
	GAMEPAD_INTERACT = "Gamepad Controller Interactions",
}

-- Every trigger from ALERT_CC parents to this gate in the settings panel — the only
-- category left that genuinely shares one frame and one event registration across all its
-- sub-cues, unlike ALERT_EXPERIMENTAL's old experimentalMaster, which gated three
-- independent watchers for no shared-registration reason (removed 2026-09-16).
Registry.ALERT_CATEGORY_MASTER = {
	ALERT_CC = "ccMaster",
	CONTROLLER_UI = "controllerUIMaster",
}

Pulse.Triggers = {

	-- ── Movement (alphafeatures.md G1, G3, G16) ────────────────────────────────
	{
		id = "landingSoft",
		category = "MOVEMENT",
		mode = "TICK",
		default = true,
		label = "Landed",
		desc = "A light tick when you land after a short fall or jump.",
		caveat = "Scored by how long you were airborne, not by fall damage — that number is unreadable. A short hop stays silent below the threshold.",
	},
	{
		id = "landingHard",
		category = "MOVEMENT",
		mode = "THUD",
		default = true,
		label = "Hard landing",
		desc = "A sharp impact when you land after a long fall.",
		caveat = 'Same fall-duration proxy as "Landed", just a higher threshold and a heavier mode.',
	},
	-- combat-detection.md §3, added 2026-09-15. Reuses the JumpOrAscendStart hook
	-- Movement.lua already runs, so no new API risk — that hook is confirmed live.
	-- UNVERIFIED: JumpOrAscendStart also fires for a Skyriding ascend, which glideThrust
	-- already textures continuously, and whether this reads as a clean "liftoff, then
	-- flight" or as a double-hit on top of it has not been felt. Off by default until it is.
	{
		id = "jumped",
		category = "MOVEMENT",
		mode = "TAP",
		default = false,
		label = "Jumped",
		desc = "A light tick the instant you jump or start a Skyriding ascend.",
		caveat = 'Untested: this fires for a Skyriding ascend too, on top of glideThrust\'s own continuous texture easing in right after — may read as a clean "liftoff, then flight" or as a double-hit. Try it before assuming either.',
	},
	-- continuous.md §3: motor balance and the idle-vs-moving split. `devTuning = true`
	-- routes these tunables off this cue's own page and onto the Continuous textures page
	-- (UI/Panel/Spec.lua).
	--
	-- Split from one cue into two, 2026-09-21. swimTexture is EFFORT only — working against
	-- the water — and waterTexture below is the ambient presence of being in it. Separate
	-- layers the engine max-blends, not two branches of one formula, so floating gives
	-- ambient alone and swimming lets effort rise past it without anything swapping over.
	{
		id = "swimTexture",
		category = "MOVEMENT",
		continuous = true,
		default = false,
		label = "Swimming resistance",
		desc = "The effort of pulling yourself through water — a stroke rhythm that quickens and hardens with how fast you are actually moving.",
		caveat = 'Effort only, and it drives the SHARP motor while "In water" drives the slow one, so the two are felt as separate sensations rather than max-blended into one. Enable both. Scales on your speed relative to your own swim speed, so it is silent while floating. Goes quiet rather than erroring if speed comes back as a secret value (RULE B — this cue caused a real 766-repeat live error before that guard existed).',
		devTuning = true,
		tunables = {
			{
				key = "separateMotors",
				label = "Own motor",
				default = true,
				boolean = true,
				desc = 'Puts the stroke on the sharp motor and leaves the slow one to "In water", so the two layers are felt separately instead of colliding on one motor. Turn off to put both back on the slow motor together — which is what the combined cue used to do, and why it read as choppy: a slow swell and a fast stroke max-blended onto one actuator beat against each other.',
			},
			{
				key = "peak",
				label = "Effort peak",
				default = 0.10,
				min = 0.0,
				max = 0.5,
				step = 0.01,
				desc = "Strength at full swimming speed. Slightly lower than the old default because the stroke now drives the sharp motor, which is the physically stronger one under the Standard schema — trim it further with that channel's Strength slider on the Controller calibration page if it shouts. Replaces the old swimLowPeak/swimHighPeak pair, which were blended with max() and were therefore algebraically one knob: the smaller never did anything.",
			},
			{
				key = "strokeRateMin",
				label = "Stroke rate, slow (Hz)",
				default = 0.45,
				min = 0.1,
				max = 2.0,
				step = 0.05,
				desc = "Strokes per second at barely-moving speed.",
			},
			{
				key = "strokeRateMax",
				label = "Stroke rate, fast (Hz)",
				default = 0.95,
				min = 0.1,
				max = 3.0,
				step = 0.05,
				desc = "Strokes per second at full speed. Swimming faster strokes faster, not merely harder — the old version only ever changed amplitude.",
			},
			{
				key = "strokeDepth",
				label = "Stroke depth",
				default = 0.55,
				min = 0.0,
				max = 1.0,
				step = 0.05,
				desc = "How pronounced each stroke is against its own baseline. 0 is a flat drag with no rhythm at all.",
			},
			{
				key = "strokeAsymmetry",
				label = "Pull / glide balance",
				default = 0.35,
				min = 0.0,
				max = 0.5,
				step = 0.05,
				desc = 'Second-harmonic content, which is what makes a stroke feel like pull-then-glide rather than a symmetric swell. Six earlier tuning rounds all felt "rough" because they modulated the amplitude of a constant; a pure sine cannot express this asymmetry and that is most likely why. 0 reverts to a plain swell.',
			},
		},
	},

	{
		id = "waterTexture",
		category = "MOVEMENT",
		continuous = true,
		default = false,
		label = "In water",
		desc = "A near-subliminal sense of being in water, for as long as you are — buoyancy rather than effort.",
		caveat = 'Present whether or not you are moving, and it does not read your speed at all, so it keeps working while speed comes back as a secret value. Drives the SLOW motor, whose large mass is what buoyancy actually feels like, leaving the sharp one to "Swimming resistance" — so the two never collide. Floating gives you this alone.',
		devTuning = true,
		tunables = {
			{
				key = "baseline",
				label = "Water presence",
				default = 0.04,
				min = 0.0,
				max = 0.30,
				step = 0.01,
				desc = "Overall strength. Meant to sit at the edge of perception — if you notice it as a vibration rather than as being submerged, it is too high. Inherits the old idleFloatAmplitude, which was live-tuned to 0.04.",
			},
			{
				key = "waveRate",
				label = "Swell rate (Hz)",
				default = 0.15,
				min = 0.02,
				max = 1.0,
				step = 0.01,
				desc = "Cycles per second, if you turn the swell on below. 0.15 is roughly one slow rise and fall every seven seconds. Deliberately far slower than the stroke rate above — two layers sharing a frequency read as one sensation instead of two.",
			},
			{
				key = "waveDepth",
				label = "Swell depth",
				default = 0.0,
				min = 0.0,
				max = 1.0,
				step = 0.05,
				desc = "OFF BY DEFAULT, and that is deliberate. A rolling swell suggests ocean, and this cue fires in rivers, lakes and canals too, where it would read as wrong rather than as atmosphere — Classic has no wave physics for it to be tracking, so it would be inventing something the world is not doing. Flat presence is the honest default. Raise it if you want a swell anyway; it is a good sensation, just not a true one.",
			},
			{
				key = "submergedBoost",
				label = "Underwater boost",
				default = 1.5,
				min = 1.0,
				max = 3.0,
				step = 0.1,
				desc = "Multiplies the baseline while fully submerged rather than bobbing at the surface, via IsSubmerged(). Set to 1.0 to feel the same either way. UNVERIFIED: IsSubmerged is confirmed present in the client API list, but whether it really distinguishes the two cases here has not been checked live.",
			},
		},
	},

	-- continuous.md §2: sine-oscillator wingbeat texture, both knobs tunable on the
	-- dev-only tuning page.
	{
		id = "taxiRide",
		category = "MOVEMENT",
		continuous = true,
		default = false,
		label = "Riding a flight path",
		desc = "A gentle, steady texture for the duration of a taxi flight.",
		caveat = "Bracketed by PLAYER_CONTROL_LOST/GAINED filtered to UnitOnTaxi — those events also fire for other control-loss cases (e.g. fear), filtered out here.",
		devTuning = true,
		tunables = {
			{
				key = "windAmplitude",
				label = "Wind amplitude",
				default = 0.1,
				min = 0.0,
				max = 0.5,
				step = 0.02,
				desc = 'Only audible if "Riding a flight path" is also enabled on its own tab.',
			},
			{
				key = "waveCycleSeconds",
				label = "Wave cycle (seconds)",
				default = 1.75,
				min = 0.5,
				max = 4.0,
				step = 0.25,
				desc = "How fast the wingbeat-style undulation cycles.",
			},
		},
	},
	{
		id = "taxiTakeoff",
		category = "MOVEMENT",
		mode = "HEAVY",
		throttle = 2.0,
		default = true,
		label = "Flight path takeoff",
		desc = "A strong impulse of thrust as your flight path mount launches into the air.",
		caveat = "Fires on taxi takeoff when control is lost to the flight master mount.",
	},
	{
		id = "taxiLanding",
		category = "MOVEMENT",
		mode = "THUD",
		throttle = 2.0,
		default = true,
		label = "Flight path landing",
		desc = "A firm impact as your flight path mount touches down at your destination.",
		caveat = "Fires upon arrival at destination when player control is restored.",
	},
	{
		id = "formChanged",
		category = "MOVEMENT",
		mode = "CHIME",
		default = false,
		label = "Shapeshift form changed",
		desc = "A pleasant chime whenever your shapeshift form changes.",
		caveat = "Reads GetShapeshiftForm()/UPDATE_SHAPESHIFT_FORM, the player's own state — one generic cue for any change, not split by direction, since forms chain (e.g. Bear -> Cat -> Moonkin) without necessarily passing back through no-form in between.",
	},

	-- ── Flight and mounts (alphafeatures.md G4, G5) ────────────────────────────
	{
		id = "mountUp",
		category = "FLIGHT",
		mode = "KNOCK",
		default = true,
		label = "Mounted up",
		desc = "Two solid hits when you mount.",
	},
	{
		id = "dismount",
		category = "FLIGHT",
		mode = "TAP",
		default = false,
		label = "Dismounted",
		desc = "A soft tick when you dismount.",
	},
	-- continuous.md §5: low = steady "you are flying" presence, high = speed thrill. Two
	-- channels doing different jobs rather than one signal at two frequencies.
	--
	-- Vigor Burst (a sharp pulse on Surge Forward / Skyward Ascent) deliberately NOT
	-- implemented: their spell IDs drift across patches (checked 2026-09-16, at least three
	-- per ability, one conflated with an unrelated Dracthyr racial of the same name) and
	-- were never confirmed live. A guessed ID binds silently to the wrong spell, which is
	-- worse than not having the feature.
	{
		id = "glideThrust",
		category = "FLIGHT",
		continuous = true,
		default = true,
		label = "Dragonriding / Skyriding thrust",
		desc = "A texture that builds as your gliding speed climbs toward a boost.",
		caveat = "Low motor holds a steady presence, floored so it's never silent while gliding; high motor eases in from near-silent toward thrillPeak as speed climbs, shaped by thrillCurve.",
		devTuning = true,
		tunables = {
			{
				key = "presenceFloor",
				label = "Presence floor (low)",
				default = 0.15,
				min = 0.0,
				max = 0.5,
				step = 0.02,
				desc = "How steady the low motor stays regardless of speed. Only audible while actually gliding.",
			},
			{
				key = "thrillPeak",
				label = "Thrill peak (high)",
				default = 0.7,
				min = 0.0,
				max = 1.0,
				step = 0.05,
				desc = "High-motor ceiling at full gliding speed. Only audible while actually gliding.",
			},
			{
				key = "thrillCurve",
				label = "Thrill curve (high)",
				default = 2.0,
				min = 1.0,
				max = 4.0,
				step = 0.5,
				desc = "How sharply the high motor ramps in with speed. 1 = linear, higher = holds back more until near max speed. Only audible while actually gliding.",
			},
		},
	},

	-- ── Combat texture (alphafeatures.md G6, G7, G12, G15, G13) ────────────────
	-- Renamed from gcdHeartbeat 2026-09-17. The detection is still "the global cooldown
	-- ticked" (spell 61304, below), but the point of the cue is confirming you pressed an
	-- ability, not the GCD as a concept. The caveat still says how it works.
	{
		id = "abilityPulse",
		category = "COMBAT",
		mode = "TICK",
		default = false,
		label = "Ability pulse",
		desc = "A very light tick every time you use an ability, while in combat.",
		caveat = "Detected via the global cooldown (spell 61304 ticking), not a per-ability read — so it only fires for abilities that trigger the GCD, and fires once per GCD even if what you pressed doesn't share a name with it. Off by default — this is the one idea in the whole catalogue that genuinely competes for channel time during a pull. Try it, but it's not for everyone.",
	},
	{
		id = "critLanded",
		category = "COMBAT",
		mode = "THUD",
		default = true,
		label = "Hit with a critical strike",
		desc = "A sharp thump when an attack against you crits.",
		caveat = "Confirmed live, 2026-09-15: COMBAT_TEXT_UPDATE's DAMAGE_CRIT/SPELL_DAMAGE_CRIT fires when you are crit, not when you land one — the reverse of this cue's original name and description. The `critLanded` id and COMBAT category are kept as-is rather than renamed, so this stays the same saved preference for anyone who already toggled it.",
	},
	-- continuous.md §1: a regular cast swells toward completion (UnitCastingInfo's
	-- startTimeMs/endTimeMs, field names and units CONFIRMED against Blizzard's own
	-- UnitDocumentation.lua), a channel holds a steady hum instead — two states where this
	-- used to track one shared isCasting bool.
	{
		id = "castTexture",
		category = "COMBAT",
		continuous = true,
		default = false,
		label = "Casting texture",
		desc = "A faint continuous hum for as long as you're casting or channelling.",
		caveat = "Off by default — a continuous texture, not a notification.",
		devTuning = true,
		tunables = {
			-- 2026-09-22. Was a bare 0.1 passed as the low role at both Modules/Combat.lua
			-- call sites, with no tunable, default or comment — helpdocs/
			-- CodeReview-2026-09-22.md finding 4 flagged it as possibly a stray edit. It is
			-- not: a faint constant on the slow motor with the swell on the fast one is what
			-- makes a cast feel present rather than only feel like it is ending. Set it to
			-- zero for the swell alone.
			{
				key = "castPresence",
				label = "Cast presence (low)",
				default = 0.1,
				min = 0.0,
				max = 0.5,
				step = 0.01,
				desc = 'A faint constant on the slow motor for as long as a cast or channel lasts, underneath the swell. This is the part that says "something is happening"; the swell is the part that says "it is nearly done". Zero leaves only the swell.',
			},
			{
				key = "castSwellPeak",
				label = "Cast swell peak (high)",
				default = 0.7,
				min = 0.0,
				max = 1.0,
				step = 0.05,
				desc = 'How strong the hum gets by the moment a regular cast completes. Only audible if "Casting texture" is also enabled on its own tab.',
			},
			{
				key = "channelHum",
				label = "Channel hum (high)",
				default = 0.2,
				min = 0.0,
				max = 1.0,
				step = 0.05,
				desc = "Flat sustained level while channelling, distinct from a regular cast's swell.",
			},
		},
	},
	-- The craft texture. In COMBAT beside castTexture because it is the same kind of thing,
	-- a continuous cast-shaped texture, even though it renders on the Crafting page. Its
	-- per-profession toggles and strengths are stored as trigger settings keyed by
	-- Enum.Profession (Modules/Crafting.lua's Professions.EnabledKey/GainKey) rather than
	-- declared here: fourteen professions times two would be twenty-eight tunables in this
	-- table, and their own page renders them from the profession list instead.
	{
		id = "craftTexture",
		category = "COMBAT",
		continuous = true,
		default = false,
		label = "Crafting texture",
		desc = "The work itself while you craft — a bed for the length of it, with the profession's own rhythm struck on top. A hammer for blacksmithing, a pick for mining, nothing percussive for tailoring or enchanting.",
		caveat = 'Off by default. Suppresses "Casting texture" for the length of a craft so the two do not layer into one lumpy sensation. The profession is read by id from the recipe (C_TradeSkillUI.GetProfessionInfoByRecipeID), so no name matching and no localisation problem — but that field is documented nilable, and anything that does not resolve falls back to a generic work rhythm rather than going quiet. Gathering is NOT covered: swinging a pick at an ore node is not a recipe and has no recipe id. Per-profession toggles and strengths are on the Crafting page. Entirely untested.',
		tunables = {
			{
				key = "bedGain",
				label = "Bed strength",
				default = 1.0,
				min = 0.0,
				max = 2.0,
				step = 0.05,
				desc = "Multiplies the continuous layer under every craft, on top of each profession's own weight. This is the part you feel for the whole craft rather than the individual blows.",
			},
			{
				key = "strikeGain",
				label = "Strike strength",
				default = 1.0,
				min = 0.0,
				max = 2.0,
				step = 0.05,
				desc = "Multiplies every impact, on top of each profession's own weight. Set to zero for a craft you feel but never get hit by.",
			},
		},
	},
	{
		id = "deflect",
		category = "COMBAT",
		mode = "DEFLECT",
		default = true,
		label = "You parried, dodged, or blocked",
		desc = "A very short, sharp tick when you avoid an incoming attack.",
	},
	{
		id = "honorGained",
		category = "COMBAT",
		mode = "CHIME",
		throttle = 0.5,
		default = false,
		label = "Honor gained",
		desc = "A pleasant chime when you gain honor — a PvP kill or objective.",
		caveat = "Reads COMBAT_TEXT_UPDATE's HONOR_GAINED messageType — same personal combat-text feed critLanded/damageTaken already use, occurrence-only, no amount read.",
	},
	{
		id = "factionGained",
		category = "COMBAT",
		mode = "CHIME",
		throttle = 0.5,
		default = false,
		label = "Reputation gained",
		desc = "A pleasant chime when you gain reputation with a faction.",
		caveat = "Reads COMBAT_TEXT_UPDATE's FACTION messageType — same personal combat-text feed critLanded/damageTaken already use, occurrence-only, no amount or faction name read.",
	},
	{
		id = "comboPoint",
		category = "COMBAT",
		mode = "TICK",
		default = false,
		label = "Combo point gained",
		desc = "A very light tick per combo point, building toward a full resource.",
		caveat = 'Complements rather than duplicates a "resource full" cue — this ticks on every point, not just the cap. Reads UnitPower("player", Enum.PowerType.ComboPoints) via UNIT_POWER_UPDATE, firing only when the count increases — confirmed live 2026-09-16 that this event also fires on the drop back to 0 after a finisher, so an unfiltered version would tick on that reset too. An ability that grants more than one point in a single event ticks once, not once per point — a simplification, not confirmed against every point-granting ability.',
	},
	{
		id = "damageTaken",
		category = "COMBAT",
		mode = "TICK",
		throttle = 0.2,
		default = false,
		defaultIntensity = 0.3,
		label = "Damage taken",
		desc = "A very light tap for an ordinary hit — deliberately gentle, distinct from the sharper critLanded pulse.",
		caveat = "Reads COMBAT_TEXT_UPDATE's DAMAGE/SPELL_DAMAGE/DAMAGE_CRIT/SPELL_DAMAGE_CRIT messageTypes rather than UNIT_COMBAT, for no-churn reasons rather than necessity — UNIT_COMBAT's \"WOUND\" mechanism was believed dead (reported not firing 2026-09-15) but was confirmed live and firing on 2026-09-16 after all; this cue already worked on COMBAT_TEXT_UPDATE by then, so it wasn't switched back. The suspicion that UNIT_COMBAT has been non-functional since Cataclysm-era patches should not be trusted as settled. Deliberately TICK, not THUD — a routine hit should read as noticeably gentler than critLanded's own pulse, not the same weight repeated constantly. Its own Intensity slider (the generic per-cue one every trigger gets) defaults to 0.3 rather than 1.0, same reasoning: it fires far more often than a crit or a dodge, so it needs to stay in the background rather than compete with them.",
	},
	{
		id = "healCrit",
		category = "COMBAT",
		mode = "CHIME",
		default = false,
		label = "Landed a critical heal",
		desc = "A pleasant chime when you receive a critical heal.",
		caveat = 'Mirrors critLanded\'s split exactly: HEAL_CRIT on the same personal COMBAT_TEXT_UPDATE feed. critLanded\'s incoming-vs-outgoing direction was independently confirmed live (2026-09-15) for damage; the same direction for heals is inferred by analogy (same feed, same self-scoped design), not separately re-tested — worth confirming live before trusting it\'s "you were healed" rather than "you landed a heal" if that distinction matters to you.',
	},
	{
		id = "healReceived",
		category = "COMBAT",
		mode = "TICK",
		throttle = 0.2,
		default = false,
		defaultIntensity = 0.3,
		label = "Healing received",
		desc = "A very light tap for an ordinary heal — deliberately gentle, distinct from the sharper healCrit pulse.",
		caveat = "Reads HEAL/PERIODIC_HEAL/HEAL_CRIT — same feed and direction caveat as healCrit above. Same TICK/0.3-intensity treatment as damageTaken, for the same reason: this fires far more often than a crit heal, especially under any HoT, so it stays in the background rather than competing with it.",
	},
	-- heavyDamageTaken (magnitude-thresholded "heavy hit") was built, CONFIRMED working
	-- live, then pulled 2026-09-17: its amount came back secret in at least one fight, for a
	-- reason never pinned down. Code and findings kept in deprecatedbutfuturecode.md.
	{
		id = "cooldownReady",
		category = "COMBAT",
		mode = "DOUBLE_TAP",
		default = false,
		label = "Tracked cooldown ready",
		desc = "Two crisp ticks when a cooldown the built-in Cooldown Manager is tracking comes off cooldown.",
		caveat = 'Experimental: watches whichever spells the Cooldown Manager\'s Essential category shows, not a hardcoded list. The exact live "just became ready" signal was never independently confirmed before this shipped — built on the same C_Spell.GetSpellCooldown transition-tracking this file already uses for the GCD heartbeat.',
	},
	{
		id = "procGlow",
		category = "COMBAT",
		mode = "BURST",
		throttle = 0.3,
		default = true,
		label = "Spell activation proc",
		desc = "An electric burst when a reactive spell or talent lights up on your action bar.",
		caveat = "Fires on SPELL_ACTIVATION_OVERLAY_GLOW_SHOW for procs such as Clearcasting, Nightfall, Overpower, Revenge, Riposte, or Art of War.",
	},
	{
		id = "meleeRangeIn",
		category = "COMBAT",
		mode = "TICK",
		throttle = 0.5,
		default = false,
		label = "Entered melee range",
		desc = "A subtle tick when stepping within auto-attack melee range of your target.",
		caveat = "Uses WoW Forever's native C_SwingTimer range checking.",
	},
	{
		id = "meleeRangeOut",
		category = "COMBAT",
		mode = "TICK",
		throttle = 0.5,
		default = false,
		label = "Left melee range",
		desc = "A soft release tick when stepping out of auto-attack melee range of your target.",
		caveat = "Uses WoW Forever's native C_SwingTimer range checking.",
	},
	{
		id = "autoRepeatStart",
		category = "COMBAT",
		mode = "TAP",
		default = false,
		label = "Ranged auto-repeat started",
		desc = "A soft tick when you start auto-attacking with a ranged weapon (Auto Shot, Shoot, wands).",
		caveat = "Confirmed live 2026-09-17: START_AUTOREPEAT_SPELL/STOP_AUTOREPEAT_SPELL fire reliably on this client. See meleeAttackStart for the separate melee equivalent.",
	},
	{
		id = "autoRepeatStop",
		category = "COMBAT",
		mode = "TAP",
		default = false,
		label = "Ranged auto-repeat stopped",
		desc = "A soft tick when your ranged auto-attack stops — catches walking out of range or getting interrupted without noticing.",
	},
	{
		id = "meleeAttackStart",
		category = "COMBAT",
		mode = "TAP",
		default = false,
		label = "Melee auto-attack started",
		desc = "A soft tick when you start meleeing.",
		caveat = "Confirmed live 2026-09-17: PLAYER_ENTER_COMBAT/PLAYER_LEAVE_COMBAT specifically track the auto-attack toggle, not the broader in-combat state combatEnter/combatLeave already cover — kept as its own cue pair rather than merged with autoRepeatStart/Stop, since melee and ranged are a different event pair on a different frame.",
	},
	{
		id = "meleeAttackStop",
		category = "COMBAT",
		mode = "TAP",
		default = false,
		label = "Melee auto-attack stopped",
		desc = "A soft tick when your melee auto-attack stops — catches walking out of range or a target dying without noticing.",
	},
	{
		id = "autoShotFired",
		category = "COMBAT",
		mode = "TRIGGER_RECOIL",
		default = false,
		label = "Auto Shot fired",
		desc = "A tactile trigger recoil kick on every Auto Shot arrow, timed to the real shot, not estimated.",
		caveat = "Confirmed live 2026-09-17: UNIT_SPELLCAST_SUCCEEDED fires with spellID 75 once per arrow — a genuine per-shot signal, not a prediction. Melee auto-attack has no equivalent: the traditional swing-timer technique reads the combat log, and this same session confirmed COMBAT_LOG_EVENT_UNFILTERED errors on registration for an addon frame under Midnight, full stop. See weaponSwingMain/weaponSwingOff below for the estimated (not measured) melee equivalent, built anyway with that limitation stated plainly. Hunter-specific; other classes' ranged auto-repeat (Shoot, wands) untested.",
	},
	{
		id = "weaponSwingMain",
		category = "COMBAT",
		mode = "TAP",
		default = false,
		label = "Weapon swing (main hand)",
		desc = "A distinct physical tap to land with each main-hand weapon swing.",
		tunables = {
			{
				key = "forceEstimator",
				label = "Use the old estimator",
				default = false,
				boolean = true,
				desc = "Off means swings come from Forever's own PLAYER_SWING event — a real per-swing signal, confirmed non-secret and proven live. On forces the old prediction built from weapon speed instead. You should not need this: if Blizzard ever removes the event, Pulse detects that and falls back on its own. It exists so a patch that changes the event's BEHAVIOUR rather than removing it still leaves you a working cue.",
			},
			{
				key = "parryHasteEnabled",
				label = "Apply parry haste",
				default = 1,
				boolean = true,
				desc = "Estimator only, and ignored while the real event is in use. Recalculates the predicted next swing when you parry an incoming attack (real formula: reduces remaining time by 40% of weapon speed, floored at 20%).",
			},
		},
		caveat = "MEASURED as of 2026-09-21, not estimated. Driven by Forever's PLAYER_SWING event, which carries swingDuration and a MainHand/OffHand/Ranged type, both confirmed non-secret, and which Blizzard's own swing timer consumes. Note this is a SWING, not necessarily a connection — whether it also fires on a miss, dodge or parry is untested, and a \"successful hit\" cue would need a different source. The old weapon-speed estimator is kept as a fallback and engages automatically if the event ever disappears; it predicted swing times from UnitAttackSpeed with a haste cache, range and stun gating and a parry-haste correction, and drifted with nothing to correct against.",
	},
	{
		id = "weaponSwingOff",
		category = "COMBAT",
		mode = "DEFLECT",
		default = false,
		label = "Weapon swing (off hand)",
		desc = "A light tick estimated to land with each off-hand weapon swing, while dual-wielding.",
		caveat = "Same source as weaponSwingMain above — PLAYER_SWING, filtered to the OffHand swing type. Silent if you're not dual-wielding. Parry haste has never affected off-hand timing, so that correction does not apply here even on the fallback estimator.",
	},
	-- Moved out of the removed ALERT_EXPERIMENTAL category 2026-09-16, grouped by subject
	-- with comboPoint/cooldownReady. UNTESTED: rests on Modules/AlertExperimental.lua's
	-- resolveSecondaryPower probing UnitPowerMax across seven candidate power types, most
	-- never independently confirmed.
	{
		id = "resourceCapped",
		category = "COMBAT",
		mode = "HEAVY",
		throttle = 2.0,
		default = false,
		label = "Secondary resource full",
		desc = "Fires when your class's secondary resource fills up — combo points, holy power, soul shards, chi, arcane charges, essence or runes, whichever your specialisation uses.",
		events = { "UNIT_POWER_UPDATE" },
		unit = "player",
		caveat = 'Does nothing on a specialisation with no secondary resource. Expect it to fire often on a class that refills constantly, such as a rogue rebuilding combo points. Not a duplicate of this addon\'s own "Combo point gained" above — that ticks per point, this fires once on reaching the cap for any of the seven candidate resources.',
	},
	-- Moved into COMBAT 2026-09-15 from its own ENCOUNTER category, once it was the only
	-- member left (see CATEGORY_ORDER above).
	{
		id = "bossAbilityWarning",
		category = "COMBAT",
		mode = "RISING",
		default = false,
		label = "Boss ability warning",
		desc = "A short warning before a significant scripted boss ability, using Blizzard's own built-in Boss Warnings timeline.",
		tunables = {
			{
				key = "warningLead",
				label = "Warning lead time",
				min = 0.5,
				max = 5.0,
				step = 0.5,
				default = 2.0,
				desc = "How many seconds before the scripted moment this fires.",
			},
			{
				key = "minSeverity",
				label = "Minimum severity",
				min = 1,
				max = 3,
				step = 1,
				default = 2,
				desc = "1 = every scripted event, 3 = only the most severe. Higher means rarer, more significant warnings.",
			},
		},
		caveat = "Reads Blizzard's own pre-scripted encounter timeline (C_EncounterEvents), not real-time combat data — pre-computed metadata, not something Secret Values blocks. No confirmed \"targeted at you\" flag: this can say something big is coming, not that it's coming for you specifically.",
	},
	-- Sister cue to bossAbilityWarning (Modules/Encounter.lua): a text-channel fallback
	-- depending on no C_EncounterEvents at all, so it works whether or not that namespace
	-- behaves as documented. Occurrence-only, no per-ability text matching (that file's
	-- header says why), throttled because some fights spam yells and emotes in bursts.
	{
		id = "bossChatWarning",
		category = "COMBAT",
		mode = "TAP",
		throttle = 1.0,
		default = false,
		label = "Boss chat warning",
		desc = "A quick tap when a boss raid-warns, yells, emotes, or whispers during a fight — a text-channel fallback for bossAbilityWarning above.",
		caveat = "Reads CHAT_MSG_RAID_WARNING/MONSTER_YELL/MONSTER_EMOTE/MONSTER_WHISPER, gated on being inside an active encounter (ENCOUNTER_START/END) — never on C_EncounterEvents, so this works even if that namespace's data turns out unreliable. Occurrence-only: says a boss communicated something, not what or whether it's aimed at you. Known false-positive: a player manually using the raid-warning channel during a live pull also fires this — not filtered, since telling a boss-sent raid warning from a player-sent one isn't reliable.",
	},

	-- ── Environment (alphafeatures.md G2, G14) ─────────────────────────────────
	{
		id = "breathWarning",
		category = "ENVIRONMENT",
		mode = "PULSE_BEAT",
		default = true,
		label = "Low on breath",
		desc = "A heartbeat-like warning when your breath meter drops below a quarter, underwater.",
	},
	-- continuous.md §4: dual-motor stutter/gasp, deliberately not lowHealthWarning's clean
	-- lub-dub — two different survival cues should feel different.
	{
		id = "breathTexture",
		category = "ENVIRONMENT",
		continuous = true,
		default = false,
		label = "Underwater breath texture",
		desc = "A continuous texture underwater that intensifies as your breath depletes.",
		caveat = 'Off by default, layers with "Low on breath" rather than replacing it.',
		devTuning = true,
		tunables = {
			{
				key = "gaspPeak",
				label = "Gasp peak",
				default = 0.6,
				min = 0.0,
				max = 1.0,
				step = 0.05,
				desc = 'Overall gasp-knock strength — fixed per beat, not scaled by danger (2026-09-16: a danger-scaled lub/dub risked landing under the controller motor\'s own minimum activation threshold at low danger, causing missing "dub" knocks live). Urgency comes from heartRateCalm/heartRateCritical instead. Only audible if "Underwater breath texture" is also enabled on its own tab.',
			},
			{
				key = "heartRateCalm",
				label = "Heart rate (calm), BPM",
				default = 30,
				min = 20,
				max = 80,
				step = 5,
				desc = "Tempo from dangerStartThreshold down to midBreathThreshold — a real bradycardic rate (the diving reflex actually slows the heart at first, requested live 2026-09-16), not an elevated one.",
			},
			{
				key = "heartRateCritical",
				label = "Heart rate (critical), BPM",
				default = 100,
				min = 60,
				max = 180,
				step = 5,
				desc = "Tempo at zero breath remaining — the panic end of the climb, reached only in the final stretch below lateBreathThreshold.",
			},
			{
				key = "dangerStartThreshold",
				label = "Danger start threshold",
				default = 0.70,
				min = 0.4,
				max = 0.85,
				step = 0.025,
				desc = "Breath texture stays completely silent (no ambient, no gasps) while breath remaining is above this — requested live 2026-09-16 as ~70% breath remaining, well before real danger, so the calm bradycardic heartbeat has room to establish before anything steepens.",
			},
			{
				key = "midBreathThreshold",
				label = "Mid breath threshold",
				default = 0.40,
				min = 0.2,
				max = 0.6,
				step = 0.025,
				desc = "First steepening point — heart rate climbs faster below this than it did between dangerStartThreshold and here. Requested live 2026-09-16 as ~40% breath remaining.",
			},
			{
				key = "lateBreathThreshold",
				label = "Late breath threshold",
				default = 0.15,
				min = 0.05,
				max = 0.3,
				step = 0.025,
				desc = "Second steepening point — the steepest segment of all, climbing to heartRateCritical by zero breath. Requested live 2026-09-16 as ~15% breath remaining.",
			},
			{
				key = "drownPeak",
				label = "Drowning panic peak",
				default = 0.85,
				min = 0.4,
				max = 1.0,
				step = 0.05,
				desc = "Intensity of choking pulses when breath runs out underwater and suffocation damage begins.",
			},
			{
				key = "drownInterval",
				label = "Drowning heartbeat interval",
				default = 1.5,
				min = 0.5,
				max = 3.0,
				step = 0.1,
				desc = "Seconds between drowning damage pulses while submerged with zero breath.",
			},
		},
	},
	{
		id = "drowningDamage",
		category = "ENVIRONMENT",
		mode = "HEAVY",
		throttle = 1.0,
		default = true,
		label = "Drowning damage",
		desc = "A heavy, suffocating thud each time you take damage from drowning underwater.",
		caveat = 'Layers with "Underwater breath texture" when breath runs out. Fires on suffocation damage while submerged.',
	},
	{
		id = "weatherChanged",
		category = "ENVIRONMENT",
		mode = "CHIME",
		default = false,
		label = "Weather changed",
		desc = "A bright tick when the weather changes.",
		caveat = "C_Weather/WEATHER_CHANGED is new as of Patch 12.1.5 and its exact return shape hasn't been verified in-game here — this fires on any change, not filtered to storm-type weather yet.",
	},
	{
		id = "weatherTexture",
		category = "ENVIRONMENT",
		continuous = true,
		default = false,
		label = "Weather texture",
		desc = "Continuous atmospheric vibration matching the current weather (rain, snow, sandstorm) and its intensity.",
		caveat = "Reads C_Weather.GetCurrentWeather() in WoW Forever. Modulates micro-flutter for rain, slow crystalline drift for snow, and dual rumble for sandstorms, scaled by weather intensity.",
		devTuning = true,
	},

	-- ── World (alphafeatures.md G9, G10, G17, G18) ─────────────────────────────
	{
		id = "resting",
		category = "WORLD",
		mode = "TAP",
		default = true,
		label = "Resting",
		desc = "A soft tick when you start resting in an inn or major city.",
	},
	{
		id = "lootGold",
		category = "WORLD",
		mode = "TICK",
		default = false,
		label = "Gold looted",
		desc = "A very light tick when you loot money.",
	},
	{
		id = "itemObtained",
		category = "WORLD",
		mode = "CHIME",
		default = false,
		label = "Item obtained",
		desc = "A bright tick when an item enters your bags — looted, crafted, or mailed.",
		caveat = "Not filtered by rarity yet — fires for anything, common items included.",
	},
	{
		id = "bagItemAdded",
		category = "WORLD",
		mode = "TICK",
		throttle = 0.2,
		default = true,
		label = "Item placed in bag",
		desc = "A light tick when an item enters your bag and occupies a slot.",
		caveat = "Fires on BAG_UPDATE_DELAYED when total free bag slots decrease. Complements Item obtained (which tracks ITEM_PUSH fly-in loot animations).",
	},
	{
		id = "bagItemUsed",
		category = "WORLD",
		mode = "THUD",
		throttle = 0.3,
		default = false,
		label = "Item consumed from bag",
		desc = "A subtle thud when a consumable or item is used and empties a bag slot.",
		caveat = "Fires on BAG_UPDATE_DELAYED when total free bag slots increase while not interacting with a merchant, bank, or mail.",
	},
	{
		id = "bagFull",
		category = "WORLD",
		mode = "STUTTER",
		throttle = 1.0,
		default = true,
		label = "Inventory full warning",
		desc = "An urgent stutter vibration when your bags become full or when you attempt an action with a full inventory.",
		caveat = "Fires on BAG_OVERFLOW_WITH_FULL_INVENTORY, UI_ERROR_MESSAGE (inventory full error) and when free bag slots drop to zero.",
	},
	{
		id = "harvestComplete",
		category = "WORLD",
		mode = "CHIME",
		throttle = 1.0,
		default = false,
		label = "Harvest complete",
		desc = "A bright chime when gathering an herb node, mineral vein, or skinning loot completes.",
		caveat = "Fires on LOOT_READY when gathering loot is ready.",
	},
	{
		id = "durabilityLow",
		category = "WORLD",
		mode = "TAP",
		default = true,
		label = "Gear needs repair",
		desc = "A tick when a piece of your gear's durability drops into the low or broken range.",
	},
	{
		id = "equipChanged",
		category = "WORLD",
		mode = "TICK",
		default = false,
		label = "Weapon or gear swapped",
		desc = "A very light tick when your equipped gear changes.",
	},
	{
		id = "emote",
		category = "WORLD",
		mode = "CHIME",
		default = false,
		label = "Performed an emote",
		desc = "A playful tick on some of your own emotes.",
		caveat = "Pure novelty. Off by default forever, basically — nobody asked for this one.",
	},
	{
		id = "npcEmote",
		category = "WORLD",
		mode = "CHIME",
		default = false,
		label = "NPC emote nearby",
		desc = "A playful tick when an NPC emotes, yells, or whispers near you.",
		caveat = 'Pure flavor, sibling to "Performed an emote" above. Fires often in busy areas with lots of ambient NPCs — this is opt-in noise, not a curated signal, same as its sibling. Off by default.',
	},

	-- ── Experimental (alphafeatures.md AF4) ────────────────────────────────────
	{
		id = "lowHealthWarning",
		category = "HEALTH",
		continuous = true,
		default = false,
		label = "Low health",
		desc = "A sharp double-knock ('lub-dub') repeating at its own independent rate while Blizzard's own low-health screen flash is active.",
		tunables = {
			{
				key = "heartRate",
				label = "Heart rate (BPM)",
				min = 50,
				max = 140,
				step = 1,
				default = 56,
				desc = "How often the lub-dub repeats while the warning stays active. Higher is more urgent; lower is less annoying. Independent of the screen flash's own (fixed, ~57 BPM) rate — this is a separate timer, not synced to it.",
			},
			{
				key = "distinctiveness",
				label = "Distinctiveness",
				min = 0,
				max = 1.0,
				step = 0.05,
				default = 0.7,
				desc = "0 = one soft pulse. 1 = a sharp lub, then a clearly separate softer dub. Derives the knock timing and intensity split automatically — see lowHealthTexture if you want those set by hand instead.",
			},
		},
		caveat = "Reads Blizzard's own default-UI LowHealthFrame (:IsShown()), not UnitHealth — that read is unconditionally secret, and the earlier color-curve attempt was confirmed dead too. LowHealthFrame's widget state is confirmed non-secret in-game instead. Very rarely can also fire for an unrelated reason (a fullscreen UI panel open in combat) — narrow enough to document rather than guard against. No `mode` field: this no longer plays a Core/Modes.lua shape, it drives Engine:Hold directly, same mechanism as lowHealthTexture.",
	},
	{
		id = "lowHealthTexture",
		category = "HEALTH",
		continuous = true,
		default = false,
		label = "Low health texture",
		desc = "A sharp double-knock ('lub-dub') timed to each pulse of Blizzard's own low-health screen flash, rather than a single beat.",
		caveat = "Off by default, layers with \"Low health\" rather than replacing it — same relationship as breathWarning/breathTexture. Same mechanism and same fullscreen-panel caveat as lowHealthWarning above. The shape itself is a code-level switch (Modules/Health.lua's HEARTBEAT_STYLE: smooth glow, flash-synced lub-dub, or an independently-timed lub-dub), not exposed here — flash-synced won out by feel. The knock's own gap/duration/intensity used to be four sliders here; fixed as plain constants in Modules/Health.lua once this exact combination was confirmed to feel right (2026-09-15).",
	},

	-- Accessibility, imported from Tremor. Ids kept identical to Tremor's, and none
	-- collides with an id above, so the cues stay recognisable across the two addons.
	-- `priority` and combat/instance suppression are dropped: Pulse blends rather than
	-- preempts (Core/Engine.lua), so a CRITICAL cue gets no special treatment over a LOW one
	-- — they layer. That is a real behavioural difference from Tremor. `throttle` is kept,
	-- enforced by Pulse:FireIfEnabled (Core/Init.lua).
	--
	-- Deliberately NOT imported: lowHealth35 / lowHealth20. Both read UnitHealth directly,
	-- CONFIRMED unconditionally secret and permanently dead on Tremor, and lowHealthWarning
	-- above already covers the purpose through the colour-curve approach.

	-- ── Accessibility: Your casting ─────────────────────────────────────────────
	{
		id = "selfCastSent",
		category = "ALERT_SELF_CAST",
		mode = "TAP",
		throttle = 0.2,
		default = false,
		label = "Cast sent",
		desc = "Fires the instant you press a cast, before the server has confirmed it.",
		events = { "UNIT_SPELLCAST_SENT" },
		unit = "player",
		caveat = "Fires on input, so it also fires for casts that then fail. That is intentional: this is an input-acknowledgement cue, not a success cue.",
	},
	{
		id = "selfCastStart",
		category = "ALERT_SELF_CAST",
		mode = "TAP",
		throttle = 0.2,
		default = false,
		label = "Your cast started",
		desc = "Fires when one of your own casts begins.",
		events = { "UNIT_SPELLCAST_START" },
		unit = "player",
	},
	{
		id = "selfCastStop",
		category = "ALERT_SELF_CAST",
		mode = "TAP",
		throttle = 0.2,
		default = false,
		label = "Your cast ended",
		desc = "Fires when one of your own casts ends, whether or not it completed.",
		events = { "UNIT_SPELLCAST_STOP" },
		unit = "player",
	},
	{
		id = "selfCastInterrupted",
		category = "ALERT_SELF_CAST",
		mode = "STUTTER",
		throttle = 0.5,
		default = true,
		label = "Your cast interrupted",
		desc = "Fires when one of your own casts is interrupted or cancelled before completion.",
		events = { "UNIT_SPELLCAST_INTERRUPTED" },
		unit = "player",
		caveat = 'Also fires when you cancel a cast yourself, or move out of range — it means "your cast did not finish", not specifically "you were kicked".',
	},
	{
		id = "selfCastFailed",
		category = "ALERT_SELF_CAST",
		mode = "DEFLECT",
		throttle = 0.4,
		default = false,
		label = "Your cast failed",
		desc = "A sharp deflection tick when a cast of yours is rejected outright — out of range, not facing the target, still on cooldown.",
		events = { "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_FAILED_QUIET" },
		unit = "player",
		caveat = "The _QUIET variant covers failures the game prints no error for, so this can fire with nothing visible on screen.",
	},
	-- Moved out of the removed ALERT_EXPERIMENTAL category 2026-09-16, next to
	-- selfCastFailed. Broader than it: any refused action via UI_ERROR_MESSAGE, not just a
	-- rejected cast.
	{
		id = "actionFailed",
		category = "ALERT_SELF_CAST",
		mode = "DEFLECT",
		throttle = 0.5,
		default = false,
		label = "Action failed",
		desc = "A sharp deflection tick when the game refuses an action — out of range, facing the wrong way, not enough resource, still on cooldown.",
		events = { "UI_ERROR_MESSAGE" },
		unit = nil,
		caveat = "One pattern for every kind of refusal. May also do nothing inside dungeons and raids.",
	},
	{
		id = "selfChannelStart",
		category = "ALERT_SELF_CAST",
		mode = "TAP",
		throttle = 0.2,
		default = false,
		label = "Your channel started",
		desc = "Fires when you begin channelling a spell.",
		events = { "UNIT_SPELLCAST_CHANNEL_START" },
		unit = "player",
	},
	{
		id = "selfChannelStop",
		category = "ALERT_SELF_CAST",
		mode = "TAP",
		throttle = 0.2,
		default = false,
		label = "Your channel ended",
		desc = "Fires when a channelled spell of yours ends, whether it ran to completion or was cut short.",
		events = { "UNIT_SPELLCAST_CHANNEL_STOP" },
		unit = "player",
	},
	-- Added 2026-09-15 from Blizzard's CastingBarFrame.lua: UNIT_SPELLCAST_INTERRUPTED is
	-- the non-channelled cast's interrupt signal (selfCastInterrupted above) and never
	-- doubles as a channel one. A channel cut short is signalled entirely through
	-- CHANNEL_STOP's 4th argument, interruptedBy — nil means it ran to completion, a real
	-- GUID means interrupted, CONFIRMED from that file's own
	-- `complete = interruptedBy == nil`. Custom-watched rather than generic, because the
	-- generic WatchCategory path fires on the event alone and this cue must NOT fire on the
	-- completed case.
	{
		id = "selfChannelInterrupted",
		category = "ALERT_SELF_CAST",
		mode = "THUD",
		default = false,
		label = "Your channel interrupted",
		desc = "Fires specifically when a channelled spell of yours is cut short by an interrupt, not when it simply ends.",
		events = { "UNIT_SPELLCAST_CHANNEL_STOP" },
		unit = "player",
		caveat = "Untested — the interruptedBy value itself is confirmed against Blizzard's own casting-bar code, not live. What's NOT confirmed: whether interruptedBy comes back secret for your own channel (the event is flagged SecretWhenUnitSpellCastRestricted in Blizzard's API docs). If this never fires, that's the first thing to check, not a sign the logic above is wrong.",
	},
	{
		id = "selfEmpowerStage",
		category = "ALERT_SELF_CAST",
		mode = "TAP",
		throttle = 0.15,
		default = false,
		label = "Empowered cast stage",
		desc = "Fires as an empowered cast of yours begins and ends.",
		events = { "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP" },
		unit = "player",
		caveat = "Evoker-only in practice. It stays registered for every class and simply never fires for the others.",
	},
	-- combat-detection.md §4, added 2026-09-15. Distinct from selfCastStop, which fires on
	-- ANY ending; this is the completed case. Needs no module code — AlertGeneric.lua's
	-- WatchCategory("ALERT_SELF_CAST") picks up any entry with an `events` array.
	-- UNVERIFIED whether it fires only on a genuine completion or on every instant-cast
	-- press too, which would be far too often to read as "that landed". Off by default.
	{
		id = "selfCastSucceeded",
		category = "ALERT_SELF_CAST",
		mode = "CHIME",
		throttle = 0.2,
		default = false,
		label = "Your cast succeeded",
		desc = "Fires when one of your own casts completes successfully — distinct from a cast simply ending.",
		events = { "UNIT_SPELLCAST_SUCCEEDED" },
		unit = "player",
		caveat = 'Untested whether this also fires on every instant-cast press rather than only real cast-bar completions — if so, it\'ll feel far too frequent to read as "that landed" specifically. Check before relying on it.',
	},

	-- ── Accessibility: Loss of control ──────────────────────────────────────────
	{
		id = "ccMaster",
		category = "ALERT_CC",
		mode = "DOUBLE_TAP",
		throttle = 0.3,
		default = true,
		label = "Loss of control cues",
		desc = "Master switch for every loss-of-control cue below. With this off, none of them fire and no loss-of-control events are registered at all.",
		events = { "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE" },
		unit = nil,
		caveat = "Doubles as the catch-all: a loss-of-control type this addon does not recognise — a new one added by a patch — fires this generic cue instead of being silently dropped.",
	},
	{
		id = "ccStun",
		category = "ALERT_CC",
		mode = "HEAVY",
		throttle = 0.3,
		default = true,
		label = "Stunned",
		desc = "Fires when you are stunned (STUN, STUN_MECHANIC).",
		events = { "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE" },
		unit = nil,
	},
	{
		id = "ccFear",
		category = "ALERT_CC",
		mode = "STUTTER",
		throttle = 0.3,
		default = true,
		label = "Feared or charmed",
		desc = "Fires when you are feared or charmed (FEAR, FEAR_MECHANIC, CHARM).",
		events = { "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE" },
		unit = nil,
	},
	{
		id = "ccSilence",
		category = "ALERT_CC",
		mode = "RISING",
		throttle = 0.3,
		default = true,
		label = "Silenced",
		desc = "Fires when you are silenced (SILENCE).",
		events = { "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE" },
		unit = nil,
	},
	{
		id = "ccRoot",
		category = "ALERT_CC",
		mode = "LONG",
		throttle = 0.3,
		default = true,
		label = "Rooted",
		desc = "Fires when you are rooted in place (ROOT). You can still act, so this is a rung below the cues that stop you entirely.",
		events = { "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE" },
		unit = nil,
	},
	{
		id = "ccDisarm",
		category = "ALERT_CC",
		mode = "DOUBLE_TAP",
		throttle = 0.3,
		default = false,
		label = "Disarmed",
		desc = "Fires when you are disarmed (DISARM).",
		events = { "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE" },
		unit = nil,
	},
	{
		id = "ccPacify",
		category = "ALERT_CC",
		mode = "DOUBLE_TAP",
		throttle = 0.3,
		default = false,
		label = "Pacified or school-locked",
		desc = "Fires when you are pacified or a spell school is locked out (PACIFY, PACIFYSILENCE, SCHOOL_INTERRUPT).",
		events = { "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE" },
		unit = nil,
		caveat = "School lockouts are frequent in melee-heavy content. Off by default because a cue every kick you eat can crowd out the ones that mean you cannot act at all.",
	},
	{
		id = "ccConfuse",
		category = "ALERT_CC",
		mode = "STUTTER",
		throttle = 0.3,
		default = true,
		label = "Confused or possessed",
		desc = "Fires when you are confused or possessed (CONFUSE, POSSESS).",
		events = { "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE" },
		unit = nil,
	},

	-- ── Accessibility: Threat ───────────────────────────────────────────────────
	{
		id = "threatRising",
		category = "ALERT_THREAT",
		mode = "RISING",
		throttle = 1.0,
		default = true,
		label = "Threat rising",
		desc = "Fires when your threat on your target rises to high-but-not-tanking (status 1).",
		events = { "UNIT_THREAT_SITUATION_UPDATE" },
		unit = "player",
		caveat = "When mobs are pulled socially — aggroing because a neighbour was pulled — the game often reports status 0 even though you have aggro.",
	},
	{
		id = "threatAggro",
		category = "ALERT_THREAT",
		mode = "HEAVY",
		throttle = 1.0,
		default = true,
		label = "You have aggro",
		desc = "Fires when you take over threat on your target (status 2 or 3).",
		events = { "UNIT_THREAT_SITUATION_UPDATE" },
		unit = "player",
		caveat = "Shares the social-pull limitation of the threat-rising cue.",
	},
	{
		id = "threatLost",
		category = "ALERT_THREAT",
		mode = "LONG",
		throttle = 1.0,
		default = false,
		label = "Threat lost",
		desc = "Fires when you drop off the top of your target's threat table.",
		events = { "UNIT_THREAT_SITUATION_UPDATE" },
		unit = "player",
		caveat = "A tank-facing cue. Off by default because for anyone else losing threat is the normal, desirable state.",
	},

	-- ── Accessibility: Target and focus ─────────────────────────────────────────
	{
		id = "targetCastStart",
		category = "ALERT_UNIT_WATCH",
		mode = "DOUBLE_TAP",
		throttle = 0.35,
		default = true,
		label = "Target started casting",
		desc = "Fires when your current target begins casting. The cue is the occurrence only — which spell it is cannot be read.",
		events = { "UNIT_SPELLCAST_START" },
		unit = "target",
		caveat = "Also fires when you switch to a target that is already mid-cast.",
	},
	{
		id = "targetChannelStart",
		category = "ALERT_UNIT_WATCH",
		mode = "DOUBLE_TAP",
		throttle = 0.35,
		default = true,
		label = "Target started channelling",
		desc = "Fires when your current target begins channelling.",
		events = { "UNIT_SPELLCAST_CHANNEL_START" },
		unit = "target",
	},
	{
		id = "focusCastStart",
		category = "ALERT_UNIT_WATCH",
		mode = "DOUBLE_TAP",
		throttle = 0.35,
		default = false,
		label = "Focus started casting",
		desc = "Fires when your focus target begins casting.",
		events = { "UNIT_SPELLCAST_START" },
		unit = "focus",
		caveat = "Shares its pulse pattern with the target cue. If your focus is also your target, you get one cue rather than two.",
	},
	{
		id = "focusChannelStart",
		category = "ALERT_UNIT_WATCH",
		mode = "DOUBLE_TAP",
		throttle = 0.35,
		default = false,
		label = "Focus started channelling",
		desc = "Fires when your focus target begins channelling.",
		events = { "UNIT_SPELLCAST_CHANNEL_START" },
		unit = "focus",
	},
	-- Moved out of the removed ALERT_EXPERIMENTAL category 2026-09-16, grouped with the
	-- other target-cast cues above.
	{
		id = "targetCastStopped",
		category = "ALERT_UNIT_WATCH",
		mode = "DOUBLE_TAP",
		throttle = 0.5,
		default = false,
		label = "Target's cast stopped",
		desc = "Fires when your target's spellcast stops before it finishes.",
		events = { "UNIT_SPELLCAST_INTERRUPTED" },
		unit = "target",
		caveat = "Not an interrupt confirmation. Fires when the cast stops for any reason — you interrupted it, they moved, they lost line of sight, they died.",
	},
	{
		id = "targetChanged",
		category = "ALERT_UNIT_WATCH",
		mode = "TAP",
		throttle = 0.15,
		default = false,
		label = "Target changed",
		desc = "Fires when you change target, including when you clear it.",
		events = { "PLAYER_TARGET_CHANGED" },
		unit = nil,
	},
	{
		id = "focusChanged",
		category = "ALERT_UNIT_WATCH",
		mode = "TAP",
		throttle = 0.15,
		default = false,
		label = "Focus changed",
		desc = "Fires when you set or clear your focus target.",
		events = { "PLAYER_FOCUS_CHANGED" },
		unit = nil,
	},
	{
		id = "targetDied",
		category = "ALERT_UNIT_WATCH",
		mode = "IMPACT",
		throttle = 0.5,
		default = true,
		label = "Target died",
		desc = "A heavy, decisive impact when your current target dies.",
		caveat = "Fires on PLAYER_TARGET_DIED.",
	},
	{
		id = "targetedByEnemy",
		category = "ALERT_UNIT_WATCH",
		mode = "STUTTER",
		throttle = 1.5,
		default = false,
		label = "Targeted by enemy",
		desc = "A sharp alert pulse when your hostile target or focus turns to target you.",
		caveat = "Watches UNIT_TARGET and target swaps for hostile units whose target is the player. Uses UnitIsUnit('targettarget', 'player') with defensive secrecy guards.",
	},
	{
		id = "targetBigDefensive",
		category = "ALERT_UNIT_WATCH",
		mode = "THUD",
		throttle = 1.0,
		default = true,
		label = "Target used major defensive",
		desc = "A heavy thud when your target activates a major defensive cooldown (e.g. Shield Wall, Ice Block, Divine Shield, Turtle, Cloak).",
		caveat = "Checked via C_UnitAuras.AuraIsBigDefensive. Occurrence only.",
		unit = "target",
	},

	-- ── Accessibility: Combat and life state (fully generic) ───────────────────
	{
		id = "combatEnter",
		category = "ALERT_STATE",
		mode = "LONG",
		throttle = 1.0,
		default = true,
		label = "Entering combat",
		desc = "Fires when you enter combat.",
		events = { "PLAYER_REGEN_DISABLED" },
		unit = nil,
	},
	{
		id = "combatLeave",
		category = "ALERT_STATE",
		mode = "TAP",
		throttle = 1.0,
		default = false,
		label = "Leaving combat",
		desc = "Fires when you drop out of combat.",
		events = { "PLAYER_REGEN_ENABLED" },
		unit = nil,
	},
	{
		id = "playerDead",
		category = "ALERT_STATE",
		mode = "HEAVY",
		throttle = 2.0,
		default = true,
		label = "You died",
		desc = "Fires when you die.",
		events = { "PLAYER_DEAD" },
		unit = nil,
	},
	{
		id = "playerAlive",
		category = "ALERT_STATE",
		mode = "DOUBLE_TAP",
		throttle = 2.0,
		default = false,
		label = "You are alive again",
		desc = "Fires when you are resurrected or leave ghost form.",
		events = { "PLAYER_ALIVE", "PLAYER_UNGHOST" },
		unit = nil,
		caveat = "PLAYER_ALIVE also fires when you release to a graveyard, so this can fire while you are still a ghost.",
	},
	{
		id = "resurrectRequest",
		category = "ALERT_STATE",
		mode = "DOUBLE_TAP",
		throttle = 1.0,
		default = true,
		label = "Resurrection offered",
		desc = "Fires when someone offers you a resurrection and the accept dialog appears.",
		events = { "RESURRECT_REQUEST" },
		unit = nil,
	},
	{
		id = "encounterStart",
		category = "ALERT_STATE",
		mode = "RISING",
		throttle = 2.0,
		default = false,
		label = "Boss encounter started",
		desc = "Fires when a boss encounter begins.",
		events = { "ENCOUNTER_START" },
		unit = nil,
	},
	{
		id = "encounterEnd",
		category = "ALERT_STATE",
		mode = "LONG",
		throttle = 2.0,
		default = false,
		label = "Boss encounter ended",
		desc = "Fires when a boss encounter ends, in victory or in a wipe.",
		events = { "ENCOUNTER_END" },
		unit = nil,
	},
	{
		id = "vehicleEnter",
		category = "ALERT_STATE",
		mode = "LONG",
		throttle = 1.0,
		default = false,
		label = "Entered a vehicle",
		desc = "Fires when you enter a vehicle and your action bar is replaced.",
		events = { "UNIT_ENTERED_VEHICLE" },
		unit = "player",
	},
	{
		id = "vehicleExit",
		category = "ALERT_STATE",
		mode = "LONG",
		throttle = 1.0,
		default = false,
		label = "Left a vehicle",
		desc = "Fires when you leave a vehicle and your own action bar returns.",
		events = { "UNIT_EXITED_VEHICLE" },
		unit = "player",
	},

	-- ── Accessibility: Group and social (generic except bgQueue) ───────────────
	{
		id = "readyCheck",
		category = "ALERT_SOCIAL",
		mode = "DOUBLE_TAP",
		throttle = 1.0,
		default = true,
		label = "Ready check",
		desc = "Fires when a ready check starts.",
		events = { "READY_CHECK" },
		unit = nil,
	},
	{
		id = "readyCheckDone",
		category = "ALERT_SOCIAL",
		mode = "TAP",
		throttle = 1.0,
		default = false,
		label = "Ready check finished",
		desc = "Fires when a ready check completes or times out.",
		events = { "READY_CHECK_FINISHED" },
		unit = nil,
	},
	{
		id = "rolePoll",
		category = "ALERT_SOCIAL",
		mode = "DOUBLE_TAP",
		throttle = 1.0,
		default = false,
		label = "Role poll",
		desc = "Fires when a role check starts.",
		events = { "ROLE_POLL_BEGIN" },
		unit = nil,
	},
	{
		id = "queuePop",
		category = "ALERT_SOCIAL",
		mode = "DOUBLE_TAP",
		throttle = 1.0,
		default = true,
		label = "Dungeon queue popped",
		desc = "Fires when a dungeon or raid finder queue pops and the accept dialog appears.",
		events = { "LFG_PROPOSAL_SHOW" },
		unit = nil,
	},
	{
		id = "bgQueue",
		category = "ALERT_SOCIAL",
		mode = "DOUBLE_TAP",
		throttle = 2.0,
		default = true,
		label = "Battleground queue ready",
		desc = "Fires when a battleground or arena queue is ready to enter.",
		events = { "UPDATE_BATTLEFIELD_STATUS" },
		unit = nil,
		caveat = "Fires only when a queue enters the ready-to-enter state, not on every status update.",
	},
	{
		id = "partyInvite",
		category = "ALERT_SOCIAL",
		mode = "DOUBLE_TAP",
		throttle = 1.0,
		default = false,
		label = "Party invite",
		desc = "Fires when someone invites you to a group.",
		events = { "PARTY_INVITE_REQUEST" },
		unit = nil,
	},
	{
		id = "guildInvite",
		category = "ALERT_SOCIAL",
		mode = "DOUBLE_TAP",
		throttle = 1.0,
		default = false,
		label = "Guild invite",
		desc = "Fires when someone invites you to a guild.",
		events = { "GUILD_INVITE_REQUEST" },
		unit = nil,
	},
	{
		id = "duelRequest",
		category = "ALERT_SOCIAL",
		mode = "DOUBLE_TAP",
		throttle = 1.0,
		default = false,
		label = "Duel request",
		desc = "Fires when someone challenges you to a duel.",
		events = { "DUEL_REQUESTED" },
		unit = nil,
	},
	{
		id = "tradeRequest",
		category = "ALERT_SOCIAL",
		mode = "DOUBLE_TAP",
		throttle = 1.0,
		default = false,
		label = "Trade opened",
		desc = "Fires when a trade window opens.",
		events = { "TRADE_SHOW" },
		unit = nil,
	},
	{
		id = "summonRequest",
		category = "ALERT_SOCIAL",
		mode = "DOUBLE_TAP",
		throttle = 1.0,
		default = false,
		label = "Summon offered",
		desc = "Fires when someone summons you and the accept dialog appears.",
		events = { "CONFIRM_SUMMON" },
		unit = nil,
		caveat = "Fires for any summon confirmation dialog, not only a player summoning you.",
	},
	{
		id = "groupRoster",
		category = "ALERT_SOCIAL",
		mode = "TAP",
		throttle = 2.0,
		default = false,
		label = "Group roster changed",
		desc = "Fires when someone joins or leaves your group.",
		events = { "GROUP_ROSTER_UPDATE" },
		unit = nil,
		caveat = "Noisy. In a raid this event fires very frequently. Kept for completeness and defaulted off.",
	},
	{
		id = "partyLeader",
		category = "ALERT_SOCIAL",
		mode = "TAP",
		throttle = 2.0,
		default = false,
		label = "Party leader changed",
		desc = "Fires when group leadership changes hands.",
		events = { "PARTY_LEADER_CHANGED" },
		unit = nil,
	},
	{
		id = "raidTarget",
		category = "ALERT_SOCIAL",
		mode = "TAP",
		throttle = 1.0,
		default = false,
		label = "Raid marker changed",
		desc = "Fires when raid target markers are set or cleared.",
		events = { "RAID_TARGET_UPDATE" },
		unit = nil,
	},
	{
		id = "whisper",
		category = "ALERT_SOCIAL",
		mode = "DOUBLE_TAP",
		throttle = 1.0,
		default = false,
		label = "Whisper received",
		desc = "Fires when you receive a whisper.",
		events = { "CHAT_MSG_WHISPER" },
		unit = nil,
	},
	{
		id = "bnWhisper",
		category = "ALERT_SOCIAL",
		mode = "DOUBLE_TAP",
		throttle = 1.0,
		default = false,
		label = "Battle.net whisper received",
		desc = "Fires when you receive a Battle.net whisper.",
		events = { "CHAT_MSG_BN_WHISPER" },
		unit = nil,
	},
	{
		id = "pingPinAdded",
		category = "ALERT_SOCIAL",
		mode = "CHIME",
		throttle = 0.5,
		default = true,
		label = "Ping placed",
		desc = "A clear tactical chime when a waypoint ping pin is placed on the terrain or map.",
		caveat = "Fires on UNIT_PING_PIN_ADDED.",
		events = { "UNIT_PING_PIN_ADDED" },
		unit = nil,
	},

	-- ── Accessibility: World and interface (generic except afkToggle) ──────────
	{
		id = "uiInfoMessage",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 0.5,
		default = false,
		label = "Interface message",
		desc = "Fires on the yellow informational messages the game shows in the top centre of the screen.",
		events = { "UI_INFO_MESSAGE" },
		unit = nil,
	},
	{
		id = "lootOpened",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 0.5,
		default = false,
		label = "Loot window opened",
		desc = "Fires when a loot window opens.",
		events = { "LOOT_OPENED" },
		unit = nil,
	},
	{
		id = "lootRoll",
		category = "ALERT_WORLD",
		mode = "DOUBLE_TAP",
		throttle = 0.5,
		default = false,
		label = "Loot roll started",
		desc = "Fires when a group loot roll opens and the roll buttons appear.",
		events = { "START_LOOT_ROLL" },
		unit = nil,
	},
	{
		id = "lootConfirm",
		category = "ALERT_WORLD",
		mode = "DOUBLE_TAP",
		throttle = 0.5,
		default = false,
		label = "Loot roll confirmation",
		desc = "Fires when the game asks you to confirm a loot roll.",
		events = { "CONFIRM_LOOT_ROLL" },
		unit = nil,
	},
	{
		id = "lootReceived",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 0.5,
		default = false,
		label = "Loot received",
		desc = "Fires when loot is awarded to you.",
		events = { "CHAT_MSG_LOOT" },
		unit = nil,
		caveat = 'Distinct from this addon\'s own "Gold looted"/"Item obtained" (World category) — this is Tremor\'s original item-award cue, kept alongside rather than merged, since the underlying events differ.',
	},
	{
		id = "merchantShow",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 1.0,
		default = false,
		label = "Vendor window opened",
		desc = "Fires when a vendor window opens.",
		events = { "MERCHANT_SHOW" },
		unit = nil,
	},
	{
		id = "merchantBuy",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 0.2,
		default = false,
		label = "Purchased item from vendor",
		desc = "A solid tap when buying an item from a merchant.",
		caveat = "Fires when spending money with an open vendor window.",
	},
	{
		id = "merchantSell",
		category = "ALERT_WORLD",
		mode = "TICK",
		throttle = 0.2,
		default = false,
		label = "Sold item to vendor",
		desc = "A light coin-like tick when selling an item to a merchant.",
		caveat = "Fires when gaining money with an open vendor window.",
	},
	{
		id = "merchantRepair",
		category = "ALERT_WORLD",
		mode = "THUD",
		throttle = 0.5,
		default = true,
		label = "Repaired equipment",
		desc = "A ringing anvil strike when repairing armor and weapons at a vendor.",
		caveat = "Fires when repairing durability at a merchant.",
	},
	-- The gaps, 2026-09-22. Each carries its legacy event where one exists, so
	-- Pulse:WatchCategory covers that path for free while Modules/Interaction.lua covers the
	-- Enum.PlayerInteractionType path. Both may fire; throttle = 1.0 means one is felt.
	{
		id = "guildBankOpened",
		category = "ALERT_WORLD",
		mode = "DOUBLE_TAP",
		throttle = 1.0,
		default = false,
		label = "Guild bank opened",
		desc = "Two taps when the guild bank opens — heavier than the personal bank, because it is a bigger door.",
		caveat = "Fires from GUILDBANKFRAME_OPENED or from the interaction manager's GuildBanker type, whichever this client sends. Untested.",
		events = { "GUILDBANKFRAME_OPENED" },
		unit = nil,
	},
	{
		id = "auctionHouseShow",
		category = "ALERT_WORLD",
		mode = "CHIME",
		throttle = 1.0,
		default = false,
		label = "Auction house opened",
		desc = "A chime when the auction house opens.",
		caveat = "Untested.",
		events = { "AUCTION_HOUSE_SHOW" },
		unit = nil,
	},
	{
		id = "stableShow",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 1.0,
		default = false,
		label = "Stable opened",
		desc = "Fires when the stable master's window opens.",
		caveat = "Untested.",
		events = { "PET_STABLE_SHOW" },
		unit = nil,
	},
	{
		id = "binderShow",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 1.0,
		default = false,
		label = "Innkeeper hearth prompt",
		desc = "Fires when an innkeeper asks to make this your home.",
		caveat = "Untested.",
		events = { "CONFIRM_BINDER" },
		unit = nil,
	},
	{
		id = "spiritHealerShow",
		category = "ALERT_WORLD",
		mode = "LONG",
		throttle = 1.0,
		default = false,
		label = "Spirit healer",
		desc = "One long, sombre pulse when a spirit healer's window opens.",
		caveat = "No legacy event for this one — it arrives only through the interaction manager, so it is silent if this client does not send that. Untested.",
		unit = nil,
	},
	{
		id = "gossipShow",
		category = "ALERT_WORLD",
		mode = "TICK",
		throttle = 1.0,
		default = false,
		label = "Talking to someone",
		desc = "The lightest possible tick when a conversation window opens with any NPC.",
		caveat = "Off by default and deliberately the faintest cue in the addon: this fires for EVERY NPC you talk to, which in a city is constantly. Try it before leaving it on. Untested.",
		events = { "GOSSIP_SHOW" },
		unit = nil,
	},
	{
		id = "itemTextBegin",
		category = "ALERT_WORLD",
		mode = "TICK",
		throttle = 1.0,
		default = false,
		label = "Reading something",
		desc = "A tick when a book, plaque, gravestone or signpost opens to be read.",
		caveat = "Pure flavour — nothing depends on it. Untested.",
		events = { "ITEM_TEXT_BEGIN" },
		unit = nil,
	},
	{
		id = "interactionWindow",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 1.0,
		default = false,
		label = "Any other window",
		desc = "A tap when an NPC or world object opens a window nothing else here covers.",
		caveat = "The catch-all. Enum.PlayerInteractionType has 81 values and most are retail systems a classic-shaped roster never meets; anything unmapped lands here rather than being silent, which also means a window type added to the client later is covered with no change to Pulse. Turn it on with /pulse debug to find out which types your client actually sends. Untested.",
		unit = nil,
	},
	{
		id = "interactionWindowClosed",
		category = "ALERT_WORLD",
		mode = "TICK",
		throttle = 1.0,
		default = false,
		label = "Interaction window closed",
		desc = "A light tick when you step away from an NPC or close its window.",
		caveat = "Fires for every interaction window, including the ones with their own opening cue. Untested.",
		unit = nil,
	},
	{
		id = "mailShow",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 1.0,
		default = false,
		label = "Mailbox opened",
		desc = "Fires when the mailbox opens.",
		events = { "MAIL_SHOW" },
		unit = nil,
	},
	{
		id = "bankOpened",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 1.0,
		default = false,
		label = "Bank opened",
		desc = "Fires when the bank window opens.",
		events = { "BANKFRAME_OPENED" },
		unit = nil,
	},
	{
		id = "bankClosed",
		category = "ALERT_WORLD",
		mode = "THUD",
		throttle = 0.5,
		default = false,
		label = "Vault door closed",
		desc = "A heavy latch thud when closing a personal bank or guild bank vault.",
		caveat = "Fires on BANKFRAME_CLOSED, GUILDBANKFRAME_CLOSED, or interaction manager banker hide.",
	},
	{
		id = "bankGold",
		category = "ALERT_WORLD",
		mode = "TICK",
		throttle = 0.2,
		default = false,
		label = "Bank gold transfer",
		desc = "A light coin clink when depositing or withdrawing money from a bank or guild bank.",
		caveat = "Fires on money changes with an open bank frame or guild bank money update.",
	},
	{
		id = "stackSplit",
		category = "ALERT_WORLD",
		mode = "TICK",
		throttle = 0.05,
		default = true,
		label = "Stack split ratchet",
		desc = "A tactile micro-tick each time the stack splitter quantity slider changes.",
		caveat = "Hooks StackSplitFrame:UpdateStackText.",
	},
	{
		id = "taxiOpened",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 1.0,
		default = false,
		label = "Flight map opened",
		desc = "Fires when a flight master's map opens.",
		events = { "TAXIMAP_OPENED" },
		unit = nil,
	},
	{
		id = "questDetail",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 0.5,
		default = false,
		label = "Quest offered",
		desc = "Fires when a quest's detail page opens, ready to accept.",
		events = { "QUEST_DETAIL" },
		unit = nil,
	},
	{
		id = "questAccepted",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 0.5,
		default = false,
		label = "Quest accepted",
		desc = "Fires when you accept a quest.",
		events = { "QUEST_ACCEPTED" },
		unit = nil,
	},
	{
		id = "questComplete",
		category = "ALERT_WORLD",
		mode = "DOUBLE_TAP",
		throttle = 0.5,
		default = false,
		label = "Quest ready to hand in",
		desc = "Fires when a quest's completion page opens, ready to hand in.",
		events = { "QUEST_COMPLETE" },
		unit = nil,
	},
	{
		id = "questTurnedIn",
		category = "ALERT_WORLD",
		mode = "DOUBLE_TAP",
		throttle = 0.5,
		default = false,
		label = "Quest turned in",
		desc = "Fires when a quest is handed in and its reward is taken.",
		events = { "QUEST_TURNED_IN" },
		unit = nil,
	},
	{
		id = "zoneChanged",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 2.0,
		default = false,
		label = "Zone changed",
		desc = "Fires when you enter a new zone.",
		events = { "ZONE_CHANGED_NEW_AREA" },
		unit = nil,
	},
	{
		id = "enteringWorld",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 5.0,
		default = false,
		label = "Loading screen finished",
		desc = "Fires when a loading screen ends and the world is back.",
		events = { "PLAYER_ENTERING_WORLD" },
		unit = nil,
	},
	{
		id = "levelUp",
		category = "ALERT_WORLD",
		mode = "SURGE",
		throttle = 2.0,
		default = true,
		label = "Level up",
		desc = "A rising celebratory surge when you gain a level.",
		events = { "PLAYER_LEVEL_UP" },
		unit = nil,
	},
	{
		id = "achievement",
		category = "ALERT_WORLD",
		mode = "CHIME",
		throttle = 2.0,
		default = false,
		label = "Achievement earned",
		desc = "A triumphant dual-tone chime when you earn an achievement.",
		events = { "ACHIEVEMENT_EARNED" },
		unit = nil,
	},
	{
		id = "afkToggle",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 1.0,
		default = false,
		label = "AFK or DND toggled",
		desc = "Fires when your own away or do-not-disturb flag actually changes.",
		events = { "PLAYER_FLAGS_CHANGED" },
		unit = "player",
		caveat = "Fires on the change itself, not on every flag update.",
	},

	-- Added 2026-09-21. Vendor and bank deliberately NOT added: merchantShow and bankOpened
	-- cover those, and a second cue on the same event doubles up. In ALERT_WORLD purely so
	-- AlertWorld.lua's generic WatchCategory pass picks them up; no module code exists for
	-- any of them. All five are plain events, so none carries the radial taint risk.
	{
		id = "trainerShow",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 1.0,
		default = false,
		defaultIntensity = 0.6,
		label = "Trainer window opened",
		desc = "Fires when a class or profession trainer's window opens.",
		events = { "TRAINER_SHOW" },
		unit = nil,
		caveat = 'Same weight and shape as the vendor, mailbox and bank cues alongside it — all four are "a window you walked up to has opened", and they deliberately feel alike rather than each inventing a signature.',
	},
	{
		id = "tradeSkillShow",
		category = "ALERT_WORLD",
		mode = "TAP",
		throttle = 1.0,
		default = false,
		defaultIntensity = 0.6,
		label = "Profession window opened",
		desc = "Fires when a profession or crafting window opens.",
		events = { "TRADE_SKILL_SHOW" },
		unit = nil,
	},
	{
		id = "spellLearned",
		category = "ALERT_WORLD",
		mode = "CHIME",
		throttle = 0.5,
		default = false,
		defaultIntensity = 0.8,
		label = "Learned a new spell",
		desc = "A bright tick when you learn a new ability.",
		events = { "LEARNED_SPELL_IN_SKILL_LINE" },
		unit = nil,
		caveat = "Note the event name: Forever uses LEARNED_SPELL_IN_SKILL_LINE, not the older LEARNED_SPELL_IN_TAB, which is absent from this client's documentation entirely. Can fire more than once for a single visit to a trainer if you buy several ranks.",
	},
	{
		id = "skillUp",
		category = "ALERT_WORLD",
		mode = "TICK",
		throttle = 0.5,
		default = false,
		defaultIntensity = 0.5,
		label = "Profession skill increased",
		desc = "A light tick when a profession or weapon skill goes up a point.",
		events = { "CHAT_MSG_SKILL" },
		unit = nil,
		caveat = "Reads the skill-up chat feed rather than SKILL_LINES_CHANGED, which also fires for unrelated skill-list changes. Occurrence-only, no text parsing — this says a skill went up, not which one or to what. Deliberately light: early profession levelling fires this constantly.",
	},
	{
		id = "recipeLearned",
		category = "ALERT_WORLD",
		mode = "CHIME",
		throttle = 0.5,
		default = false,
		defaultIntensity = 0.8,
		label = "Learned a new recipe",
		desc = "A bright tick when you learn a new recipe or pattern.",
		events = { "NEW_RECIPE_LEARNED" },
		unit = nil,
		caveat = 'Shares its shape with "Learned a new spell" on purpose — both are the same moment to a player, just in different systems.',
	},

	-- ── Accessibility: Controller ────────────────────────────────────────────────
	{
		id = "padBattery",
		category = "ALERT_DEVICE",
		mode = "DOUBLE_TAP",
		throttle = 60,
		default = true,
		label = "Controller battery low",
		desc = "Fires once when the controller's battery drops into its low or critical range.",
		events = { "GAME_PAD_POWER_CHANGED" },
		unit = nil,
		caveat = "Fires on the crossing into low, not repeatedly while low.",
	},
	{
		id = "padConnected",
		category = "ALERT_DEVICE",
		mode = "DOUBLE_TAP",
		throttle = 2.0,
		default = false,
		label = "Controller connected",
		desc = "Fires when a controller connects.",
		events = { "GAME_PAD_CONNECTED" },
		unit = nil,
	},
	{
		id = "padDisconnected",
		category = "ALERT_DEVICE",
		mode = nil,
		silent = true,
		throttle = 0,
		default = true,
		label = "Controller disconnected",
		desc = "Clears any vibration still in flight when the controller disconnects.",
		events = { "GAME_PAD_DISCONNECTED" },
		unit = nil,
		caveat = "Produces no vibration — the controller is gone. Turning it off changes nothing you can feel: the engine clears in-flight vibration whenever it loses the device, because it has to.",
	},

	-- Controller UI — WoW Forever's own gamepad interface, observed rather than recreated
	-- (Modules/ControllerUI.lua). Every cue below reads a native Blizzard signal whose name,
	-- file and line were CHECKED against the Forever source; none is guessed. None has
	-- `events`, because none is a plain Lua event — they arrive through passive polling
	-- of Blizzard state (SmartNavigation, GamepadRadial, UIParent panels, GroupTargeting),
	-- or hooksecurefunc on safe Blizzard methods (radial selection lifecycle, tab changes).
	--
	-- All shipped OFF by default and all UNTESTED: the source says these fire, but nothing
	-- here has observed one land in-game. The SmartNavigation POC was written and never run,
	-- and the radial QA probe could never have run — it keys off a global
	-- (`GamepadMainMenuFrame`) that does not exist in Forever; the real frame is
	-- `GamepadRadial`. Treat every caveat below as sourced, not witnessed.
	--
	-- Modes are reused from the existing 16, never extended: the research proposes its own
	-- primitive names (TICK/CLICK/CONFIRM/REJECT/EDGE…) and every one maps onto a shape
	-- Core/Modes.lua already has.

	-- ── Controller UI: category master ─────────────────────────────────────────
	{
		id = "controllerUIMaster",
		category = "CONTROLLER_UI",
		silent = true,
		default = true,
		label = "Menu & controller UI haptics",
		desc = "Master switch for all menu, window, tab, and radial controller haptics. Turn off to silence all UI navigation haptics at once while keeping combat and world rumble active.",
		caveat = "With this turned off, navigation, edge bumps, radial wheels, tab switches, and popups produce no haptics and unhook from the interface to save processing.",
	},

	-- ── Controller UI: navigation ───────────────────────────────────────────────
	{
		id = "uiNavigate",
		category = "CONTROLLER_UI",
		mode = "TICK",
		throttle = 0.03,
		default = true,
		defaultIntensity = 0.35,
		label = "UI focus moved",
		desc = "A very light tick each time controller focus moves to a different interface element.",
		caveat = "Passively polled from SmartNavigation's currentButton every 0.05s to eliminate execution taint when gamepad mode is toggled. Fires on real focus changes rather than stick motion. Gated on gamepad UI being active.",
	},
	{
		id = "uiNavigateEdge",
		category = "CONTROLLER_UI",
		mode = "DEFLECT",
		throttle = 0.1,
		default = true,
		defaultIntensity = 0.5,
		label = "UI navigation hit an edge",
		desc = "A short, sharp tick when controller focus runs into the edge of a list or grid and can't go further.",
		caveat = "Dormant: SmartNavigation edge callbacks were retired to eliminate client execution taint when gamepad mode is toggled. Retained in registry for future native engine support.",
	},
	{
		id = "uiSelectionDisabled",
		category = "CONTROLLER_UI",
		mode = "DOUBLE_TAP",
		throttle = 0.2,
		default = false,
		defaultIntensity = 0.5,
		label = "Focused element became unavailable",
		desc = "Fires when the element controller focus is currently on becomes disabled.",
		caveat = "Passively polled by observing IsEnabled() on the currently focused element. Fires if the element becomes disabled while focused.",
	},

	-- ── Controller UI: focus ────────────────────────────────────────────────────
	{
		id = "uiFocusIn",
		category = "CONTROLLER_UI",
		mode = "TAP",
		throttle = 0.2,
		default = false,
		defaultIntensity = 0.5,
		label = "Interface took controller focus",
		desc = "A rising pulse when the controller starts driving a UI panel instead of your character.",
		caveat = "Passively polled from SmartNavigation focus state. Fires when controller navigation gains focus on a UI element.",
	},
	{
		id = "uiFocusOut",
		category = "CONTROLLER_UI",
		mode = "TICK",
		throttle = 0.2,
		default = false,
		defaultIntensity = 0.5,
		label = "Interface released controller focus",
		desc = "A falling pulse when the controller hands control back to your character.",
		caveat = "Passively polled from SmartNavigation focus state. Fires when controller navigation releases focus back to world control.",
	},

	-- ── Controller UI: menus and tabs ───────────────────────────────────────────
	{
		id = "uiTabChanged",
		category = "CONTROLLER_UI",
		mode = "DEFLECT",
		throttle = 0.15,
		default = true,
		defaultIntensity = 0.6,
		label = "Interface tab changed",
		desc = "Two soft ticks when you switch tabs inside a panel — Character, Spellbook, the map's zone tabs, and so on.",
		caveat = "Hooks Blizzard's shared tab plumbing (TabSystemMixin:SetTab, TabSystemOwnerMixin:SetTab, PanelTemplates_SetTab). Filtered on those functions' own `isUserAction` argument where they provide one, so a panel setting its own tab as it opens stays silent and only a tab YOU changed fires. Two known gaps: PanelTemplates_SetTab is the legacy path and has no such flag, so a few older panels may still fire on open; and the two mixin hooks only reach panels created AFTER Pulse loads, because Mixin() copies function references onto a frame at creation. Most big tabbed panels are load-on-demand and so are covered, but anything built before this addon isn't. Expect this one to be patchy.",
	},

	-- ── Controller UI: radial menu ──────────────────────────────────────────────
	-- The best-instrumented surface in the whole native controller stack: open, per-segment
	-- movement, commit, cancel and paging are all separately observable, which is why it
	-- gets seven cues where navigation gets three.
	{
		id = "radialOpen",
		category = "CONTROLLER_UI",
		mode = "TAP",
		throttle = 0.2,
		default = true,
		defaultIntensity = 0.6,
		label = "Radial menu opened",
		desc = "A rising pulse when the controller radial menu opens.",
		caveat = "Passively polled from GamepadRadial:IsShown() to eliminate EventRegistry callback taint during radial menu activation.",
	},
	{
		id = "radialClose",
		category = "CONTROLLER_UI",
		mode = "TICK",
		throttle = 0.2,
		default = true,
		defaultIntensity = 0.5,
		label = "Radial menu closed",
		desc = "A falling pulse when the radial menu closes.",
		caveat = "Passively polled from GamepadRadial:IsShown(). Picking a segment that opens a panel also closes the radial.",
	},
	{
		id = "radialTick",
		category = "CONTROLLER_UI",
		mode = "TICK",
		throttle = 0.03,
		default = true,
		defaultIntensity = 0.3,
		label = "Radial segment changed",
		desc = "A very light tick per segment as you sweep the stick around the radial — the wheel gets detents you can feel.",
		caveat = "The most promising cue here: a radial is an analog sweep through discrete stops, which is exactly what haptics are good at, and it's the one that could let you pick a segment without looking. Blizzard already change-gates this and applies its own stick hysteresis, so it should not fire continuously while you hold a direction. Untested whether the rate still feels like too much.",
	},
	{
		id = "radialBlocked",
		category = "CONTROLLER_UI",
		mode = "DEFLECT",
		throttle = 0.15,
		default = false,
		defaultIntensity = 0.6,
		label = "Radial segment unavailable",
		desc = "A short, sharp tick instead of the normal one when the segment you land on can't be used.",
		caveat = 'Reads the segment\'s own IsEnabled() — the same value Blizzard reads to grey the highlight out, so this matches what you see on screen. Fires in place of "Radial segment changed", not alongside it.',
	},
	{
		id = "radialSelect",
		category = "CONTROLLER_UI",
		mode = "CHIME",
		throttle = 0.2,
		default = true,
		defaultIntensity = 0.7,
		label = "Radial segment chosen",
		desc = "A bright tick when you commit to a radial segment by letting the stick return to centre.",
		caveat = "Distinguished from cancelling by Blizzard's own `isCancelled` flag, which it sets before ending the selection — so a cancel never counts as a choice.",
	},
	{
		id = "radialCancel",
		category = "CONTROLLER_UI",
		mode = "TAP",
		throttle = 0.2,
		default = false,
		defaultIntensity = 0.5,
		label = "Radial selection cancelled",
		desc = "A soft tick when you cancel a radial selection instead of committing to it.",
		caveat = "Bound to the right-stick press in Blizzard's own radial.",
	},
	{
		id = "radialPage",
		category = "CONTROLLER_UI",
		mode = "DOUBLE_TAP",
		throttle = 0.15,
		default = true,
		defaultIntensity = 0.5,
		label = "Radial page changed",
		desc = "Two soft ticks when you page the radial left or right with the shoulder buttons.",
		caveat = "One cue for both directions, same reasoning as the navigation edge cue — a motor can't tell you which way you went.",
	},

	-- Gamepad Controller Interactions — the controller acting on the WORLD rather than on
	-- the interface (Modules/ControllerUI.lua's second half).
	--
	-- Every cue below is driven by a PLAIN LUA EVENT, deliberately. The radial cues above
	-- needed hooksecurefunc, which cost a real taint bug on 2026-09-21 ("blocked from an
	-- action only available to the Blizzard UI"): a hook runs inside its caller's execution,
	-- so hooking anything whose caller later touches a protected frame poisons that call. An
	-- event dispatched to our own frame cannot — nothing of Blizzard's runs after us in the
	-- same stack. Where a choice existed, the event won.
	--
	-- Sourced against the Forever client, not yet witnessed.

	-- ── Gamepad interactions: targeting ─────────────────────────────────────────
	-- Forever's reticle marks what you are pointing at BEFORE you commit — the soft target.
	-- A different moment from targetChanged (the hard target, PLAYER_TARGET_CHANGED), and
	-- the pair is the closest thing the game has to hover-then-click.
	{
		id = "softEnemyChanged",
		category = "GAMEPAD_INTERACT",
		mode = "TICK",
		throttle = 0.1,
		default = false,
		defaultIntensity = 0.3,
		label = "Hostile target under reticle",
		desc = "A very light tick when something you could attack comes under your reticle.",
		caveat = 'PLAYER_SOFT_ENEMY_CHANGED, an occurrence-only event with no payload at all — there is nothing here to come back secret. Fires on the soft target changing, which is not the same as actually targeting something; that\'s still "Target changed" on the Target & Focus page. Expect this to fire often while sweeping the camera through a crowd.',
	},
	{
		id = "softFriendChanged",
		category = "GAMEPAD_INTERACT",
		mode = "TICK",
		throttle = 0.1,
		default = false,
		defaultIntensity = 0.3,
		label = "Friendly target under reticle",
		desc = "A very light tick when a friendly unit comes under your reticle.",
		caveat = 'PLAYER_SOFT_FRIEND_CHANGED, occurrence-only, no payload. Worth pairing with the hostile cue above only if you can tell two TICKs apart — if not, give one of them a different shape with its own "Feels like" dropdown.',
	},
	{
		id = "softInteractChanged",
		category = "GAMEPAD_INTERACT",
		mode = "TAP",
		throttle = 0.1,
		default = false,
		defaultIntensity = 0.45,
		label = "Interactable under reticle",
		desc = "A bright tick when something you could interact with — an NPC, a node, a door — comes under your reticle.",
		caveat = "PLAYER_SOFT_INTERACT_CHANGED. Unlike its two siblings this one DOES carry a payload (oldTarget/newTarget GUIDs) and is flagged SecretWhenUnitIdentityRestricted in Blizzard's own docs, so this cue deliberately reads none of it and fires on the occurrence alone. Probably the most useful of the three: it's the one that says \"there is something here\" while you're looking around.",
	},
	{
		id = "softTargetInteraction",
		category = "GAMEPAD_INTERACT",
		mode = "CLICK",
		throttle = 0.2,
		default = false,
		defaultIntensity = 0.45,
		label = "Soft target interact",
		desc = "A tactile click when native gamepad or action targeting triggers an interaction with the soft target.",
		caveat = "PLAYER_SOFT_TARGET_INTERACTION. Fires when native gamepad/action interact executes on the current soft target.",
	},

	-- ── Gamepad interactions: item cursor ───────────────────────────────────────
	{
		id = "cursorPickup",
		category = "GAMEPAD_INTERACT",
		mode = "TAP",
		throttle = 0.1,
		default = false,
		defaultIntensity = 0.6,
		label = "Picked up an item",
		desc = "Two solid hits when an item attaches to the cursor.",
		caveat = "CURSOR_CHANGED, with C_Cursor.GetCursorItem() checked only for presence — never read, never compared, so a secret item can't break it (truthiness on a non-secret-boolean is legal). Distinct from this addon's own \"Item obtained\": that's loot arriving in your bags, this is you physically holding something.",
	},
	{
		id = "cursorDrop",
		category = "GAMEPAD_INTERACT",
		mode = "TAP",
		throttle = 0.1,
		default = false,
		defaultIntensity = 0.5,
		label = "Put down an item",
		desc = "A soft tick when the item leaves the cursor.",
		caveat = "The other edge of the same CURSOR_CHANGED transition. Fires whether the item was placed somewhere or the drag was simply cancelled — the event doesn't distinguish, and nothing readable does.",
	},

	-- ── Gamepad interactions: action bars ───────────────────────────────────────
	{
		id = "actionBarPage",
		category = "GAMEPAD_INTERACT",
		mode = "DOUBLE_TAP",
		throttle = 0.15,
		default = false,
		defaultIntensity = 0.5,
		label = "Action bar page changed",
		desc = "Two soft ticks when the action bar pages to a different set of abilities.",
		caveat = "ACTIONBAR_PAGE_CHANGED. Useful on a controller specifically, where the bar you're on isn't always where your eyes are. Does not cover the vehicle/override/possess bar swaps, which are their own events and would want their own cue if they turn out to matter.",
	},

	-- ── Gamepad interactions: input mode ────────────────────────────────────────
	{
		id = "inputModeChanged",
		category = "GAMEPAD_INTERACT",
		mode = "CHIME",
		throttle = 1.0,
		default = false,
		defaultIntensity = 0.7,
		label = "Input device changed",
		desc = "A bright tick when the game switches between controller and mouse-and-keyboard.",
		caveat = "INPUT_DEVICE_INTERFACE_TRANSITION, carrying newMode/oldMode. This event is FOREVER-ONLY — it was not found anywhere in the retail Midnight archive used for comparison, so don't expect this cue to do anything on retail. Fires on any transition in either direction; the payload would let it be split into separate entered/left cues later if that's worth having.",
	},
	-- ── Added 2026-09-21 ───────────────────────────────────────────────────────
	-- Crafting, via Core/CastActivity.lua. A craft is a small ritual with a start, a
	-- duration and an outcome, which is the shape haptics are best at. All three off by
	-- default and UNFELT.
	{
		id = "craftStart",
		category = "ALERT_SELF_CAST",
		mode = "CHIME",
		throttle = 0.3,
		default = false,
		defaultIntensity = 0.6,
		label = "Craft started",
		desc = "A soft chime when a crafting cast begins.",
		caveat = "TRADE_SKILL_CRAFT_BEGIN via Core/CastActivity.lua. Untested — no crafting cue has ever existed in this addon, so nothing here has been felt. Off by default.",
	},
	{
		id = "craftComplete",
		category = "ALERT_SELF_CAST",
		mode = "CHIME",
		throttle = 0.3,
		default = false,
		label = "Craft finished",
		desc = "A chime when a craft completes successfully.",
		caveat = "Distinguished from craftStopped by whether the cast actually succeeded, which Core/CastActivity.lua tracks across the cast lifecycle rather than guessing from one event. Untested.",
	},
	{
		id = "craftStopped",
		category = "ALERT_SELF_CAST",
		mode = "DEFLECT",
		throttle = 0.3,
		default = false,
		defaultIntensity = 0.7,
		label = "Craft interrupted",
		desc = "A short deflecting tick when a craft is abandoned or interrupted.",
		caveat = "Fires for a craft that stopped without succeeding — moving, being interrupted, or cancelling. Untested.",
	},
	-- The half of UNIT_SPELLCAST_SUCCEEDED that was previously unreachable.
	{
		id = "selfCastInstant",
		category = "ALERT_SELF_CAST",
		mode = "CLICK",
		throttle = 0.1,
		default = false,
		defaultIntensity = 0.5,
		label = "Instant ability used",
		desc = "A dry click when you use an ability that has no cast time.",
		caveat = 'Instants and completed casts arrive on the same event, so "Cast succeeded" has always fired for both. Core/CastActivity.lua tells them apart by whether a START was seen first; this is the instant half. Leave "Cast succeeded" off if you want only one of the two. Untested.',
	},

	{
		id = "debuffReceived",
		category = "COMBAT",
		mode = "CRACK",
		throttle = 0.4,
		default = false,
		defaultIntensity = 0.6,
		label = "Debuff received",
		desc = "A sharp snap when a harmful effect lands on you.",
		caveat = "COMBAT_TEXT_UPDATE's SPELL_AURA_START_HARMFUL messageType, ruling out EXTRA_ATTACKS. Occurrence only — the amount on this feed is a secret value. Not confirmed to fire; off by default.",
	},

	{
		id = "xpGained",
		category = "ALERT_WORLD",
		mode = "BLIP",
		throttle = 0.5,
		default = false,
		defaultIntensity = 0.4,
		label = "Experience gained",
		desc = "A tiny blip when you gain experience.",
		caveat = "Occurrence only, deliberately near-subliminal so it doesn't compete with \"Levelled up\". No size scaling: the amount would need UnitXP diffing and isn't worth the bookkeeping for a cue this quiet.",
	},

	{
		id = "stealthTexture",
		category = "MOVEMENT",
		continuous = true,
		default = false,
		label = "Stealth texture",
		desc = "A near-silent breathing wave while stealthed or invisible.",
		caveat = "Reads IsStealthed(), the player's own boolean state — not an aura scan, which would be both expensive and liable to return secret values. First cue built on Core/Waves.lua. Untested.",
		devTuning = true,
		tunables = {
			{
				key = "baseline",
				label = "Stealth baseline",
				default = 0.06,
				min = 0.0,
				max = 0.30,
				step = 0.01,
				desc = "How strong the stealth hum is overall. Meant to sit just at the edge of perception — if you notice it as a vibration rather than a presence, it is too high.",
			},
			{
				key = "breathRate",
				label = "Breath rate (Hz)",
				default = 0.30,
				min = 0.05,
				max = 2.0,
				step = 0.05,
				desc = "How often the hum swells, in cycles per second. 0.30 is roughly one slow breath every three seconds.",
			},
			{
				key = "breathDepth",
				label = "Breath depth",
				default = 0.35,
				min = 0.0,
				max = 1.0,
				step = 0.05,
				desc = "How far the hum swells either side of its baseline. 0 is a flat hold.",
			},
		},
	},

	-- Locomotion. Modules/Locomotion.lua's header says what was taken from the Cooking/
	-- prototype: the gait mechanism was kept, its 68 invented race/mount constants were not.
	{
		id = "locomotion",
		category = "MOVEMENT",
		continuous = true,
		default = false,
		label = "Footfalls and gait",
		desc = "A continuous gait texture while moving — footfalls on foot, hoofbeats mounted.",
		caveat = "Off by default and mounted-only by default, on purpose: a texture that plays whenever you move is the most fatiguing thing in this addon and the most likely to make you switch it off wholesale. Left and right footfalls drive separate roles, so on a controller with working trigger actuators the gait moves across the pad. Race, racial mount and boot weight all shape it — on WoW Forever every race rides its own mount, so race genuinely determines the gait. Speed is read out of combat only and held through a fight; snares and boosts are not tracked there, which is a deliberate trade for never touching a secret value. Goes quiet while swimming, flying, gliding, riding a flight path, or airborne after a jump — each of those has its own cue and footfalls have nothing to add to them. Entirely untested.",
		devTuning = true,
		tunables = {
			{
				key = "mountedOnly",
				label = "Only while mounted",
				default = true,
				boolean = true,
				desc = "Restricts the gait to mounted travel, where a sustained texture is most welcome. Turn off to feel your own footsteps too — try it before leaving it on.",
			},
			{
				key = "splitFeet",
				label = "Split left and right",
				default = true,
				boolean = true,
				desc = "Sends left and right footfalls to the two trigger actuators so the stride walks across your hands. IGNORED unless the controller you picked on the Controller calibration page actually has trigger motors — of the listed hardware only Xbox and DualSense do. On anything else the split would land left on the weak rumble motor and right on the strong one, which reads as a limp rather than a gait, so both feet share one motor instead.",
			},
			{
				key = "gaitIntensity",
				label = "Gait strength",
				default = 0.35,
				min = 0.0,
				max = 1.0,
				step = 0.05,
				desc = "Overall strength of each footfall before speed and state scaling.",
			},
			{
				key = "runCadence",
				label = "Run cadence (steps/s)",
				default = 2.8,
				min = 0.5,
				max = 6.0,
				step = 0.1,
				desc = "Steps per second at full running speed. Scaled by how fast you are actually moving.",
			},
			{
				key = "walkCadence",
				label = "Walk cadence (steps/s)",
				default = 1.8,
				min = 0.5,
				max = 4.0,
				step = 0.1,
				desc = "Steps per second at normal walking speed.",
			},
			{
				key = "mountIntensity",
				label = "Mount weight",
				default = 1.2,
				min = 0.0,
				max = 2.0,
				step = 0.05,
				desc = "Multiplies gait strength while mounted, on top of the racial mount's own weight. A kodo is already heavier than a hawkstrider before this touches it.",
			},
		},
	},

	{
		id = "popupShown",
		category = "CONTROLLER_UI",
		mode = "TAP",
		throttle = 0.3,
		default = true,
		defaultIntensity = 0.7,
		label = "Confirmation popup appeared",
		desc = "A tap when a confirmation dialog opens.",
		caveat = "Polled from StaticPopup1..4's IsShown() four times a second rather than hooked. StaticPopup_Show is called from all over Blizzard's UI by code that then touches protected frames, and this addon already has one taint incident from exactly that shape (Modules/ControllerUI.lua's ActivateRadial note). Untested.",
	},
	{
		id = "popupHidden",
		category = "CONTROLLER_UI",
		mode = "CLICK",
		throttle = 0.3,
		default = true,
		defaultIntensity = 0.5,
		label = "Confirmation popup closed",
		desc = "A light click when the last confirmation dialog closes.",
		caveat = 'Same polled mechanism as "Confirmation popup appeared". Untested.',
	},
	{
		id = "panelOpen",
		category = "CONTROLLER_UI",
		mode = "TAP",
		throttle = 0.2,
		default = true,
		defaultIntensity = 0.6,
		label = "UI panel opened",
		desc = "A crisp tap when a major full-screen or side UI panel opens (character sheet, spellbook, quest log, etc.).",
		caveat = "Passively polled via GetUIPanel every 0.05s to eliminate UIParentPanelManager execution taint on protected frames.",
	},
	{
		id = "panelClose",
		category = "CONTROLLER_UI",
		mode = "CLICK",
		throttle = 0.2,
		default = true,
		defaultIntensity = 0.5,
		label = "UI panel closed",
		desc = "A light click when a major UI panel is dismissed.",
		caveat = "Passively polled via GetUIPanel every 0.05s. Detects when major UI panels are dismissed without callback taint.",
	},
	{
		id = "groupTargetingStart",
		category = "CONTROLLER_UI",
		mode = "TAP",
		throttle = 0.2,
		default = true,
		defaultIntensity = 0.6,
		label = "Group targeting active",
		desc = "A distinct tap when holding the controller modifier to target party or raid members.",
		caveat = "Passively polled via GroupTargeting.isTargetingActive to eliminate execution taint when targeting stops or gamepad mode is toggled.",
	},
	{
		id = "groupTargetingStop",
		category = "CONTROLLER_UI",
		mode = "TICK",
		throttle = 0.2,
		default = true,
		defaultIntensity = 0.5,
		label = "Group targeting released",
		desc = "A soft tick when releasing the group targeting modifier back to normal navigation.",
		caveat = "Passively polled via GroupTargeting.isTargetingActive. Fires when the group targeting modifier is released.",
	},
}

-- Presentation layout (2026-09-21) — which settings page and section each cue renders
-- under, and in what order. Data only: nothing here is read by event registration, nothing
-- reaches SavedVariables, nothing changes what a cue does or how it feels.
--
-- `category` on every entry above stays the FUNCTIONAL key, untouched. Pulse:WatchCategory
-- (Core/Init.lua), ALERT_CATEGORY_MASTER below and both companion addons (PulseDebug,
-- PulseChecklist) read it, so re-keying it to match these page names would silently
-- unregister whole categories of events and break two addons. A parallel presentation key
-- lets the panel reorganise while behaviour stays frozen.
--
-- One table rather than a `page` field on each of the 116 entries: the taxonomy is readable
-- in one screen, reordering a page is a line move rather than twenty scattered edits, and a
-- cue added to Pulse.Triggers without being placed here is caught by the orphan pass below
-- rather than silently vanishing from the panel.
--
-- No "Experimental" page, despite the UI proposal listing one: grouping by provenance
-- instead of by subject is what stranded three cues in a tab nobody opened. An untested cue
-- stays on the page a player would look for it on and says so in its own caveat.
local PAGE_LAYOUT = {
	{
		id = "COMBAT",
		label = "Combat",
		sections = {
			{
				label = "Offensive",
				cues = {
					"abilityPulse",
					"meleeAttackStart",
					"meleeAttackStop",
					"meleeRangeIn",
					"meleeRangeOut",
					"autoRepeatStart",
					"autoRepeatStop",
					"autoShotFired",
					"weaponSwingMain",
					"weaponSwingOff",
				},
			},
			{
				label = "Defensive",
				cues = {
					"critLanded",
					"damageTaken",
					"deflect",
					"healCrit",
					"healReceived",
					"debuffReceived",
				},
			},
			{ label = "Resources", cues = { "comboPoint", "resourceCapped", "cooldownReady", "procGlow" } },
			{ label = "Rewards", cues = { "honorGained", "factionGained" } },
			{
				label = "Encounter",
				cues = {
					"encounterStart",
					"encounterEnd",
					"bossAbilityWarning",
					"bossChatWarning",
				},
			},
		},
	},

	-- Casting gets its own page: it has a real semantic lifecycle, and separating the
	-- continuous state from the discrete outcomes is the point. The five plain lifecycle
	-- transitions are grouped last under their own heading rather than removed — all are
	-- default-off, so they cost nothing, and castTexture is default-off too, so the claim
	-- that it replaces them is not yet testable.
	{
		id = "CASTING",
		label = "Casting",
		sections = {
			{ label = "Casting texture", cues = { "castTexture", "craftTexture" } },
			{
				label = "Cast outcomes",
				cues = {
					"selfCastSucceeded",
					"selfCastInstant",
					"selfCastInterrupted",
					"selfCastFailed",
					"selfChannelInterrupted",
				},
			},
			{ label = "Crafting", cues = { "craftStart", "craftComplete", "craftStopped" } },
			{ label = "Special casting", cues = { "selfEmpowerStage" } },
			{ label = "Action feedback", cues = { "actionFailed" } },
			{
				label = "Lifecycle (advanced)",
				cues = {
					"selfCastSent",
					"selfCastStart",
					"selfCastStop",
					"selfChannelStart",
					"selfChannelStop",
				},
			},
		},
	},

	{
		id = "MOVEMENT",
		label = "Movement & Travel",
		sections = {
			{
				label = "Movement",
				cues = {
					"landingSoft",
					"landingHard",
					"jumped",
					"waterTexture",
					"swimTexture",
					"formChanged",
					"locomotion",
					"stealthTexture",
				},
			},
			{
				label = "Mounts & travel",
				cues = {
					"mountUp",
					"dismount",
					"glideThrust",
					"taxiRide",
					"taxiTakeoff",
					"taxiLanding",
					"vehicleEnter",
					"vehicleExit",
				},
			},
		},
	},

	{
		id = "CHARACTER",
		label = "Character & Status",
		sections = {
			{
				label = "Life & combat state",
				cues = {
					"combatEnter",
					"combatLeave",
					"playerDead",
					"playerAlive",
					"resurrectRequest",
				},
			},
			{
				label = "Health & survival",
				cues = {
					"lowHealthWarning",
					"lowHealthTexture",
					"breathWarning",
					"breathTexture",
					"drowningDamage",
				},
			},
			{ label = "Equipment", cues = { "durabilityLow", "equipChanged" } },
			{ label = "Character state", cues = { "resting" } },
		},
	},

	-- Loss of control and Threat share a page but NOT a gate: ccMaster is keyed by category
	-- (ALERT_CATEGORY_MASTER), so it governs only the eight ALERT_CC cues and leaves the
	-- three threat cues alone. Two labelled sections is what makes that split visible.
	{
		id = "CONTROL",
		label = "Control & Threat",
		sections = {
			{
				label = "Loss of control",
				cues = {
					"ccStun",
					"ccFear",
					"ccSilence",
					"ccRoot",
					"ccDisarm",
					"ccPacify",
					"ccConfuse",
				},
			},
			{ label = "Threat", cues = { "threatRising", "threatAggro", "threatLost" } },
		},
	},

	{
		id = "TARGET",
		label = "Target & Focus",
		sections = {
			{
				label = "Target",
				cues = {
					"targetCastStart",
					"targetChannelStart",
					"targetCastStopped",
					"targetBigDefensive",
					"targetChanged",
					"targetedByEnemy",
					"targetDied",
				},
			},
			{
				label = "Focus",
				cues = {
					"focusCastStart",
					"focusChannelStart",
					"focusChanged",
				},
			},
		},
	},

	{
		id = "WORLD",
		label = "World & Environment",
		sections = {
			{ label = "Environment", cues = { "weatherChanged", "weatherTexture" } },
			{
				label = "World",
				cues = {
					"zoneChanged",
					"enteringWorld",
					"emote",
					"npcEmote",
				},
			},
			{
				label = "Loot & inventory",
				cues = {
					"lootGold",
					"itemObtained",
					"bagItemAdded",
					"bagItemUsed",
					"bagFull",
					"harvestComplete",
					"lootOpened",
					"lootRoll",
					"lootConfirm",
					"lootReceived",
				},
			},
			{
				label = "Quests",
				cues = {
					"questDetail",
					"questAccepted",
					"questComplete",
					"questTurnedIn",
				},
			},
			{
				label = "Progression",
				cues = {
					"levelUp",
					"xpGained",
					"achievement",
					"spellLearned",
					"recipeLearned",
					"skillUp",
				},
			},
		},
	},

	{
		id = "SOCIAL",
		label = "Social & Group",
		sections = {
			{
				label = "Group readiness",
				cues = {
					"readyCheck",
					"readyCheckDone",
					"rolePoll",
					"queuePop",
					"bgQueue",
				},
			},
			{ label = "Group changes", cues = { "groupRoster", "partyLeader", "raidTarget", "pingPinAdded" } },
			{
				label = "Invites & requests",
				cues = {
					"partyInvite",
					"guildInvite",
					"duelRequest",
					"tradeRequest",
					"summonRequest",
				},
			},
			{ label = "Messages", cues = { "whisper", "bnWhisper" } },
		},
	},

	{
		id = "INTERFACE",
		label = "Interface & Accessibility",
		sections = {
			{ label = "Interface", cues = { "uiInfoMessage", "afkToggle", "stackSplit" } },
			-- One shape at one weight: a window you walked up to has opened. Uniformity is what
			-- makes these distinguishable from Controller UI's focus and tab cues, which are
			-- about moving *within* an open window. Three families, three feels: TAP for a
			-- window arriving, lighter TAP/TICK for focus entering or leaving it, DEFLECT for
			-- changing tab inside it.
			{
				label = "Windows",
				cues = {
					"merchantShow",
					"merchantBuy",
					"merchantSell",
					"merchantRepair",
					"mailShow",
					"bankOpened",
					"guildBankOpened",
					"bankClosed",
					"bankGold",
					"taxiOpened",
					"trainerShow",
					"tradeSkillShow",
					"auctionHouseShow",
					"stableShow",
					"binderShow",
					"spiritHealerShow",
				},
			},
			-- Separate from Windows: these two are about being spoken to and reading, which
			-- happen constantly and want their own place to be switched off.
			{ label = "Conversation & reading", cues = { "gossipShow", "itemTextBegin" } },
			-- The catch-all pair. Last, because they are what you reach for when something
			-- you wanted a cue for turned out not to have one.
			{ label = "Anything else", cues = { "interactionWindow", "interactionWindowClosed" } },
		},
	},

	{
		id = "CONTROLLER",
		label = "Controller",
		sections = {
			{ label = "Device", cues = { "padBattery", "padConnected", "padDisconnected" } },
		},
	},

	-- Forever's native controller-UI haptics get their own page rather than a section on
	-- Interface & Accessibility: that page is the GAME's interface reacting (a vendor window
	-- opened, a quest offered), this one is the CONTROLLER moving through it. Different
	-- subjects, and IntegrationofHapticforWOWforever.md §13 maps out enough interaction
	-- groups — navigation, focus, targeting, radial, items, action bars, popups — that
	-- folding them in would swamp the six cues already there.
	--
	-- Sections are declared empty so the taxonomy is settled before the cues arrive; the
	-- panel skips empty sections and pages, so nothing renders until the first one lands.
	-- Section names follow the source-verified callback groups, not invented ones:
	-- SmartNavigation supplies SelectedButtonUpdated and the four Hit*Edge events
	-- (Navigation), FocusedFrame/UnfocusedFrame and FrameControlsManager supply Focus.
	{
		id = "CONTROLLER_UI",
		label = "Controller UI",
		sections = {
			{
				label = "Navigation",
				cues = {
					"uiNavigate",
					"uiNavigateEdge",
					"uiSelectionDisabled",
					"groupTargetingStart",
					"groupTargetingStop",
				},
			},
			{ label = "Focus", cues = { "uiFocusIn", "uiFocusOut" } },
			-- Separate from Navigation: stepping focus between two buttons and swapping tab or
			-- panel page are different gestures wanting different cues. Sources:
			-- TabSystemOwnerMixin:SetTab, TabSystemMixin:SetTab and PanelTemplates_SetTab
			-- (WoWForeverGamepadQA's TabDetector), plus the
			-- UIParentPanelManager.ShowUIPanel/HideUIPanel EventRegistry callbacks.
			{
				label = "Menus & tabs",
				cues = {
					"panelOpen",
					"panelClose",
					"uiTabChanged",
					"popupShown",
					"popupHidden",
				},
			},
			-- Lifecycle order rather than alphabetical: open, page, sweep, commit or cancel, close.
			{
				label = "Radial menu",
				cues = {
					"radialOpen",
					"radialPage",
					"radialTick",
					"radialBlocked",
					"radialSelect",
					"radialCancel",
					"radialClose",
				},
			},
		},
	},

	-- Split out from Controller UI rather than sharing it: that page is the player moving
	-- through the interface, this is the controller acting on the world. The Targeting,
	-- Items and Action bars sections moved here, being world-facing once they had cues.
	{
		id = "GAMEPAD_INTERACT",
		label = "Gamepad Controller Interactions",
		sections = {
			{
				label = "Targeting",
				cues = {
					"softInteractChanged",
					"softTargetInteraction",
					"softEnemyChanged",
					"softFriendChanged",
				},
			},
			{ label = "Item cursor", cues = { "cursorPickup", "cursorDrop" } },
			{ label = "Action bars", cues = { "actionBarPage" } },
			{ label = "Input mode", cues = { "inputModeChanged" } },
		},
	},
}

local byID, byCategory, categoriesInUse = {}, {}, {}
for _, trigger in ipairs(Pulse.Triggers) do
	byID[trigger.id] = trigger
	local list = byCategory[trigger.category]
	if not list then
		list = {}
		byCategory[trigger.category] = list
		categoriesInUse[trigger.category] = true
	end
	list[#list + 1] = trigger
end

-- Resolve PAGE_LAYOUT's cue-id lists into trigger objects, once, at load. Resolving this
-- direction rather than stamping `page`/`section` onto the shared trigger tables keeps
-- PulseDebug and PulseChecklist's tables unmutated, and hands the panel a plain array of
-- triggers per section — no id lookups at render time, no dead fields, and `category` stays
-- the untouched functional key.
--
-- `page.hasCues` is precomputed because a page whose sections are all empty would register a
-- sidebar tab opening onto blank space; the panel skips it.
for _, page in ipairs(PAGE_LAYOUT) do
	page.hasCues = false
	for _, section in ipairs(page.sections) do
		section.triggers = {}
		for _, cueID in ipairs(section.cues) do
			local trigger = byID[cueID]
			if trigger then
				section.triggers[#section.triggers + 1] = trigger
				page.hasCues = true
			else
				-- Names a cue absent from Pulse.Triggers: a typo, or a rename that missed
				-- its placement. Loud on purpose — only ever an authoring mistake.
				print(("Pulse: PAGE_LAYOUT lists unknown cue %q (Core/Registry.lua)"):format(cueID))
			end
		end
	end
end

-- A category master (currently only ccMaster) deliberately has no page: it renders on the
-- root page next to "Enable Pulse", not inside the section it gates.
local isCategoryMaster = {}
for _, masterTriggerID in pairs(Registry.ALERT_CATEGORY_MASTER) do
	isCategoryMaster[masterTriggerID] = true
end

local placed = {}
for _, page in ipairs(PAGE_LAYOUT) do
	for _, section in ipairs(page.sections) do
		for _, trigger in ipairs(section.triggers) do
			placed[trigger.id] = true
		end
	end
end

for _, trigger in ipairs(Pulse.Triggers) do
	if not placed[trigger.id] and not isCategoryMaster[trigger.id] then
		print(("Pulse: cue %q has no settings page — add it to PAGE_LAYOUT (Core/Registry.lua)"):format(trigger.id))
	end
end

function Registry:GetTrigger(id)
	return byID[id]
end
function Registry:GetTriggersByCategory(category)
	return byCategory[category] or {}
end

-- Settings-panel layout: pages in sidebar order, each with its sections in render order.
-- UI/Panel/ is the only caller; nothing functional reads this.
function Registry:GetPages()
	return PAGE_LAYOUT
end

function Registry:GetCategories()
	local result = {}
	for _, category in ipairs(CATEGORY_ORDER) do
		if categoriesInUse[category] then
			result[#result + 1] = category
		end
	end
	return result
end

function Registry:GetCategoryLabel(category)
	return CATEGORY_LABELS[category] or category
end

function Registry:GetSchemaOptions()
	local list = {}
	for _, schema in pairs(Pulse.HapticSchemas) do
		list[#list + 1] = schema
	end
	table.sort(list, function(a, b)
		return (a.order or 0) < (b.order or 0)
	end)
	return list
end

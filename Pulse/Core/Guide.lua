-- Pulse — Core/Guide.lua
--
-- The beginner's guide, in plain English. Data only, same discipline as Tremor's file of
-- the same name: no game API, no formatting, no frames, so it stays loadable outside the
-- client and stays honest by never naming an individual trigger, mode, default, or number
-- that lives in Core/Registry.lua or Core/Modes.lua — those drift, concepts don't.
--
-- UI/Panel/Spec.lua renders this as the settings window's Guide page. One authored source.

local ADDON_NAME, Pulse = ...

Pulse.Guide = {
    {
        heading = "What this does",
        body = "Pulse turns what's happening in the game into controller vibration — "
            .. "landing hard, gliding fast, taking a critical hit, a storm rolling in. "
            .. "It's texture for ordinary play, closer to what a console game's rumble "
            .. "does than to a notification.\n\n"
            .. "It also carries a second, separate set of controls: a full accessibility "
            .. "toggle set imported from Tremor, this addon's sibling project. Those work "
            .. "the same way Tremor's own cues do — an event happens, one pulse tells you "
            .. "about it — but they share Pulse's channel with everything else here, which "
            .. 'is a real difference worth understanding. See "The Accessibility '
            .. 'section" below.',
    },
    {
        heading = "First: switch controller support on",
        body = "World of Warcraft ignores controllers entirely until you turn them on, and "
            .. "this is off by default. Pairing the controller to your computer is not "
            .. "enough — the game has to be told separately.\n\n"
            .. "Type this into chat, then restart the game:\n\n"
            .. "    /console GamePadEnable 1\n\n"
            .. "Until that is done nothing here can work, and nothing will warn you. If "
            .. "Pulse seems completely dead, check this first.",
    },
    {
        heading = "Second: find out what your controller can do",
        body = "Controllers differ in which motors they have, and the game never reports "
            .. "whether a vibration actually happened. Nothing can detect this for you, so "
            .. "you have to feel it.\n\n"
            .. "Pick a mode from the **Mode to test** dropdown near the top of the panel "
            .. "and press **Play it**. Try a few — sharp ones, sustained ones, textures. "
            .. "Pay attention to which ones you can feel clearly, which are faint, and "
            .. "which do not arrive at all.\n\n"
            .. "If some were missing or silent, check two places:\n\n"
            .. "The **Vibration schema** dropdown near the top of the panel. A schema "
            .. "decides which motor each pulse drives, and swapping it works around a "
            .. "controller that only drives one of them.\n\n"
            .. "The **Controller calibration** page. Real motors need a minimum amount "
            .. "of power just to start spinning (their breakaway floor). If quiet cues "
            .. "vanish entirely, use the **Ramp** tool there to calibrate your motor floors "
            .. "and balance their strength.",
    },
    {
        heading = "Triggers, modes, and motor tuning",
        body = "A **trigger** is an occasion — something happening that you want to feel. "
            .. "A **mode** is a feeling — the shape of the vibration itself.\n\n"
            .. "Every trigger plays one mode, and many triggers share one. You can customize "
            .. "this relationship at two levels:\n\n"
            .. "**Per-cue customization**: Enable advanced controls to change what a "
            .. 'specific cue "Feels like" from its dropdown, or adjust its individual '
            .. "intensity slider without affecting other cues.\n\n"
            .. "**Motor & Timing page**: Reshape any vibration mode across the entire "
            .. "addon — adjust its low motor, high motor, or trigger actuator balance, "
            .. "and speed up or slow down its duration envelope.",
    },
    {
        heading = "Adaptive triggers & controller fallback",
        body = "Pulse includes dedicated trigger vibration modes designed specifically for "
            .. "controllers with independent trigger actuators (such as the PlayStation "
            .. "DualSense).\n\n"
            .. "On controllers with trigger actuators, selecting the **Rumble + Triggers** "
            .. "schema routes trigger pulses straight to the physical trigger actuators, "
            .. "delivering mechanical snaps and pulls directly under your index fingers "
            .. "while body vibrations stay on the palm motors.\n\n"
            .. "On standard gamepads (Xbox, Nintendo Switch, generic pads), trigger cues "
            .. "automatically fall back onto your regular rumble motors (left trigger to "
            .. "low motor, right trigger to high motor). You will always feel every cue, "
            .. "regardless of what controller you hold.",
    },
    {
        heading = "Two kinds of trigger: pulses and textures",
        body = "Most triggers are a **pulse** — something happens, you feel one short "
            .. "burst, then it's gone.\n\n"
            .. "Some are a **texture** instead — a faint, continuous feeling for as long "
            .. "as something is true. Swimming, gliding, casting, riding a flight path, "
            .. "weathering a storm: these fade in in the moment they start and fade out the "
            .. "instant they stop, rather than announcing themselves once. They're built "
            .. "to layer underneath pulses rather than compete with them — a critical hit "
            .. "still lands as a distinct thump even while a casting texture is quietly "
            .. "running underneath it.\n\n"
            .. "Most textures ship switched off, on purpose: a constant hum is a bigger "
            .. "ask than an occasional pulse, and it's worth trying deliberately rather "
            .. "than discovering by accident.",
    },
    {
        heading = "Profiles and automatic rules",
        body = "Pulse provides purpose-built default profiles engineered for specific "
            .. "roles and activities — browse them on the dedicated **Default profiles** page:\n\n"
            .. "• **Dungeon & Raid Roles** (Tank, Healer, Melee DPS, Caster DPS, Hunter) "
            .. "prioritize high signal-to-noise: threat loss, mitigations, kick windows, and "
            .. "spell completion ticks take priority over ambient clutter.\n"
            .. "• **World Immersion** (Melee, Caster, Ranged) maximizes atmospheric game-feel: "
            .. "footstep weight by armor type, mount strides, swimming resistance, weather, "
            .. "and exploration.\n"
            .. "• **PvP** delivers pure tactical radar with zero ambient distraction.\n\n"
            .. "On the **Profiles** page, you can configure automatic rules that switch "
            .. "profiles on the fly when you change talent specializations, or create custom "
            .. "copies of any default profile. To protect combat performance, any profile "
            .. "switch requested while fighting is safely deferred until combat ends.",
    },
    {
        heading = "The Cue Index directory",
        body = "With dozens of cues across movement, combat, environment, and interface "
            .. "systems, you might know what you want to adjust without knowing which tab "
            .. "owns it.\n\n"
            .. "The **Cue index** page lists every cue in Pulse alphabetically, grouped "
            .. "under clean letter headers with real-time status dots showing whether "
            .. "each cue is currently enabled. Clicking any line jumps directly to that "
            .. "cue's page and settings.\n\n"
            .. "Searching the Cue Index searches all cue names, descriptions, and "
            .. "locations simultaneously, serving as an instant directory across the "
            .. "entire addon.",
    },
    {
        heading = "The Accessibility section",
        body = "Everything under the Accessibility headings is imported from Tremor, this "
            .. "addon's sibling — the same events, the same triggers, built for telling "
            .. "you about things you'd otherwise have to see, like a stun landing or your "
            .. "cast breaking.\n\n"
            .. "One thing did not carry over: Tremor plays one cue at a time and makes the "
            .. "most urgent one win, on the reasoning that a late or blended signal is "
            .. "worse than none. Pulse doesn't work that way — everything here can layer "
            .. "together, which is what makes the movement and combat textures feel good, "
            .. "but it means an accessibility cue can arrive blended with something else "
            .. "rather than standing alone the way it would in Tremor.\n\n"
            .. "If precise, unambiguous accessibility signals matter more to you than "
            .. "game-feel texture, Tremor on its own is built specifically for that and "
            .. "doesn't have this tradeoff. The two are not meant to run at the same time.",
    },
    {
        heading = "The experimental section",
        body = "A few triggers, in both the game-feel and Accessibility parts of the "
            .. "panel, rest on questions about the game that have no settled answer yet.\n\n"
            .. "When one of them fails it does not produce an error. It simply never "
            .. "fires, and there is nothing to fix. They may also change or stop working "
            .. "after any game update.\n\n"
            .. "Try them if you're curious. Don't build a habit on one.",
    },
    {
        heading = "Companion tools",
        body = "Two separate addons exist alongside Pulse, each with its own slash "
            .. "command — neither is required, and neither changes anything Pulse "
            .. "itself does.\n\n"
            .. "**PulseChecklist** (/pulsecheck or /pcheck) opens a standalone "
            .. "checklist window listing every trigger, for tracking which ones you've "
            .. "actually confirmed feel right on your own hardware.\n\n"
            .. "**PulseDebug** (/pdebug or /pd) opens an interactive diagnostic window "
            .. "with live telemetry — inspect currently blended layers, monitor "
            .. "real-time channel output, review a timestamped event log, and inspect "
            .. "module states.",
    },
    {
        heading = "If nothing is happening",
        body = "Work down this list in order.\n\n"
            .. "Is controller support on? See the first section — this is by far the most "
            .. "common cause.\n\n"
            .. "Does the controller vibrate at all? Test a mode from the panel. If that's "
            .. "silent, the problem is the controller or the game, not your settings.\n\n"
            .. "Is Pulse switched on, and is the trigger you're waiting for switched on? "
            .. "Both have to be — and for an Accessibility trigger, check the section's "
            .. "master switch too, if it has one.\n\n"
            .. "Is it a texture rather than a pulse? Textures only run while their cause "
            .. "is actually happening — nothing to feel while standing still.\n\n"
            .. "Is the motor's breakaway floor too low? Some gamepads require a higher "
            .. "minimum floor to overcome mechanical inertia. Check the **Controller "
            .. "calibration** page and test the motor ramp.",
    },
}

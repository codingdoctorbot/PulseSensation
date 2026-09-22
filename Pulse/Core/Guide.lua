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
        body = "Pulse turns what's happening in the game into controller vibration — " ..
               "landing hard, gliding fast, taking a critical hit, a storm rolling in. " ..
               "It's texture for ordinary play, closer to what a console game's rumble " ..
               "does than to a notification.\n\n" ..
               "It also carries a second, separate set of controls: a full accessibility " ..
               "toggle set imported from Tremor, this addon's sibling project. Those work " ..
               "the same way Tremor's own cues do — an event happens, one pulse tells you " ..
               "about it — but they share Pulse's channel with everything else here, which " ..
               "is a real difference worth understanding. See \"The Accessibility " ..
               "section\" below.",
    },
    {
        heading = "First: switch controller support on",
        body = "World of Warcraft ignores controllers entirely until you turn them on, and " ..
               "this is off by default. Pairing the controller to your computer is not " ..
               "enough — the game has to be told separately.\n\n" ..
               "Type this into chat, then restart the game:\n\n" ..
               "    /console GamePadEnable 1\n\n" ..
               "Until that is done nothing here can work, and nothing will warn you. If " ..
               "Pulse seems completely dead, check this first.",
    },
    {
        heading = "Second: find out what your controller can do",
        body = "Controllers differ in which motors they have, and the game never reports " ..
               "whether a vibration actually happened. Nothing can detect this for you, so " ..
               "you have to feel it.\n\n" ..
               "Pick a mode from the **Mode to test** dropdown near the top of the panel " ..
               "and press **Play it**. Try a few — sharp ones, sustained ones, textures. " ..
               "Pay attention to which ones you can feel clearly, which are faint, and " ..
               "which do not arrive at all.\n\n" ..
               "If some were missing, change the vibration schema above it and try again. " ..
               "A schema decides which motor each pulse drives, and swapping it is how you " ..
               "work around a controller that only drives one of them.",
    },
    {
        heading = "Triggers and modes are different things",
        body = "A **trigger** is an occasion — something happening that you want to feel. " ..
               "A **mode** is a feeling — the shape of the vibration itself.\n\n" ..
               "Every trigger plays one mode, and many triggers share one. Unlike some " ..
               "haptic addons, the modes here aren't individually tunable — there are a " ..
               "lot of them, precisely so that different moments can feel different from " ..
               "each other, and giving each one its own strength-and-length sliders would " ..
               "mean dozens of controls for something that's supposed to stay simple. " ..
               "What you tune instead is the overall intensity, and a separate intensity " ..
               "per section of the panel — turn combat texture down without touching " ..
               "movement, for instance.",
    },
    {
        heading = "Two kinds of trigger: pulses and textures",
        body = "Most triggers are a **pulse** — something happens, you feel one short " ..
               "burst, then it's gone.\n\n" ..
               "Some are a **texture** instead — a faint, continuous feeling for as long " ..
               "as something is true. Swimming, gliding, casting, riding a flight path: " ..
               "these fade in in the moment they start and fade out the instant they " ..
               "stop, rather than announcing themselves once. They're built to layer " ..
               "underneath pulses rather than compete with them — a critical hit still " ..
               "lands as a distinct thump even while a casting texture is quietly running " ..
               "underneath it.\n\n" ..
               "Most textures ship switched off, on purpose: a constant hum is a bigger " ..
               "ask than an occasional pulse, and it's worth trying deliberately rather " ..
               "than discovering by accident.",
    },
    {
        heading = "The Accessibility section",
        body = "Everything under the Accessibility headings is imported from Tremor, this " ..
               "addon's sibling — the same events, the same triggers, built for telling " ..
               "you about things you'd otherwise have to see, like a stun landing or your " ..
               "cast breaking.\n\n" ..
               "One thing did not carry over: Tremor plays one cue at a time and makes the " ..
               "most urgent one win, on the reasoning that a late or blended signal is " ..
               "worse than none. Pulse doesn't work that way — everything here can layer " ..
               "together, which is what makes the movement and combat textures feel good, " ..
               "but it means an accessibility cue can arrive blended with something else " ..
               "rather than standing alone the way it would in Tremor.\n\n" ..
               "If precise, unambiguous accessibility signals matter more to you than " ..
               "game-feel texture, Tremor on its own is built specifically for that and " ..
               "doesn't have this tradeoff. The two are not meant to run at the same time.",
    },
    {
        heading = "The experimental section",
        body = "A few triggers, in both the game-feel and Accessibility parts of the " ..
               "panel, rest on questions about the game that have no settled answer yet.\n\n" ..
               "When one of them fails it does not produce an error. It simply never " ..
               "fires, and there is nothing to fix. They may also change or stop working " ..
               "after any game update.\n\n" ..
               "Try them if you're curious. Don't build a habit on one.",
    },
    {
        heading = "Companion tools",
        body = "Two separate addons exist alongside Pulse, each with its own slash " ..
               "command — neither is required, and neither changes anything Pulse " ..
               "itself does.\n\n" ..
               "**PulseChecklist** (/pulsecheck or /pcheck) opens a standalone " ..
               "checklist window listing every trigger, for tracking which ones you've " ..
               "actually confirmed feel right on your own hardware.\n\n" ..
               "**PulseDebug** (/pdebug or /pd) is a chat-based troubleshooting " ..
               "companion — commands for inspecting what's currently blending, testing " ..
               "a mode directly, or watching an event fire in real time.",
    },
    {
        heading = "If nothing is happening",
        body = "Work down this list in order.\n\n" ..
               "Is controller support on? See the first section — this is by far the most " ..
               "common cause.\n\n" ..
               "Does the controller vibrate at all? Test a mode from the panel. If that's " ..
               "silent, the problem is the controller or the game, not your settings.\n\n" ..
               "Is Pulse switched on, and is the trigger you're waiting for switched on? " ..
               "Both have to be — and for an Accessibility trigger, check the section's " ..
               "master switch too, if it has one.\n\n" ..
               "Is it a texture rather than a pulse? Textures only run while their cause " ..
               "is actually happening — nothing to feel while standing still.",
    },
}

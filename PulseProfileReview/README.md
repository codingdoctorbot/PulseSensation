# Pulse Profile Review (prototype)

Standalone WoW addon for reviewing whether each registered Pulse cue belongs in each
profile. It reads cue metadata from `PulseHaptics` and the profile cue switches from
`PulseDB`; it never calls Pulse setters or changes haptic behavior.

## Install and open

Copy the `PulseProfileReview` folder next to `PulseHaptics` in the game's `Interface/AddOns`
directory, enable it in the AddOns list, then use `/pulsereview` (or `/prreview`). Use
`< Profile` / `Profile >` to choose which profile to review. The active in-game profile is
shown separately. Each cue row shows that selected profile's current On/Off setting and
independent Yes/No review buttons. A cue not yet reviewed remains explicitly unreviewed.

Use **Export** or `/pulsereview export` to open a Markdown report. Select and copy its text
into a `.md` file or a coding-agent prompt. WoW stores the review decisions in the addon's
own `PulseProfileReviewDB` SavedVariables; it does not write to `PulseDB`.

This is an early prototype. Review data is organized by profile and cue ID. Current-setting
values are read from the selected profile's saved trigger switches, while the active profile
label reflects Pulse's current profile resolution.

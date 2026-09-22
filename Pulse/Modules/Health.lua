-- Pulse — Modules/Health.lua
--
-- Low health via Blizzard's own LowHealthFrame, not UnitHealth and not a colour curve.
-- UnitHealth("player") is CONFIRMED unconditionally secret, and the colour-curve escape
-- hatch came back secret too. LowHealthFrame is different in kind: Blizzard's default-UI
-- frame that flashes the screen below 35% health (LowHealthFrameMixin:IsAtLowHealth(),
-- confirmed against live source), and its widget state — :IsShown()/:GetAlpha() — is
-- CONFIRMED NON-SECRET in-game (2026-09-15, HasSecretAspect("Shown")/("Alpha") both false).
-- This reads that state, never the health value. :IsAtLowHealth() exists but its own return
-- IS secret, so it stays unused.
--
-- Polled rather than event-driven for the crossing itself (:IsShown()): there is no public
-- "changed" event to hook.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("Health", M)

local POLL_INTERVAL = 0.05

-- Two candidate shapes for lowHealthTexture, switched by editing this line and /reload. A
-- taste call made by feel in-game, not worth UI plumbing until one wins; the loser is kept
-- in case a later session prefers it.
--   "smooth"       — GetAlpha() straight through every tick. The rumble breathes with the
--                    flash's own swell, continuously.
--   "lubdub_flash" — a sharp-then-soft double knock, peak-detected off the screen flash's
--                    animation cycle. Locks the rate to Blizzard's fixed ~57 BPM. An
--                    independently-timed variant with an adjustable BPM was tried and felt
--                    worse, so flash-synced won by feel, not by realism.
local HEARTBEAT_STYLE = "lubdub_flash"

-- Real heart sounds: S1 ("lub") is louder and sharper, S2 ("dub") follows softer. These
-- four were Registry.lua sliders; fixed as constants once this combination was CONFIRMED to
-- feel right in-game (2026-09-15).
--
-- knockDuration must be SHORTER than lubDubGap. HoldIfEnabled's default duration
-- (Engine.lua's REFRESH_WINDOW, 0.35s) holds the "lub" target until the "dub" call replaces
-- it, so the value steps from one to the other instead of decaying toward zero between them
-- — two taps read as one swelling pulse. What controls how distinct the knocks feel is
-- (lubDubGap - knockDuration), the silent window Engine.lua's smoothing has to decay in.
local LUB_DUB_GAP = 0.36
local KNOCK_DURATION = 0.05
local LUB_INTENSITY = 0.7
local DUB_INTENSITY = 0.2

-- Refuses to re-trigger inside the flash's own cycle (~1s at .5236s per BOUNCE half-swing)
-- even if sampling noise produces a spurious second local max: the real next peak is most
-- of a second away regardless.
local MIN_PEAK_GAP = 0.6

local pollTicker = nil
local wasShown = false
local beatTicker = nil
local pendingStopTimer = nil
local prevAlpha, prevPrevAlpha = nil, nil
local lastPeakTime = 0

-- Health hovering at Blizzard's 35% line — chip damage against a HoT tick, lifesteal —
-- makes LowHealthFrame flicker Show()/Hide() on every crossing. Stopping the ticker on
-- every Hide meant a flickering fight never got a repeating beat at all, only the one-off
-- crossing beat firing again each dip, spaced by crossings rather than by beatInterval.
-- This grace period makes a Hide stick for a moment before the ticker stops; a Hide
-- followed by a Show inside the window cancels the pending stop.
local STOP_GRACE = 1.0

local function cancelPendingStop()
    if pendingStopTimer then
        pendingStopTimer:Cancel()
        pendingStopTimer = nil
    end
end

-- Its own lub-dub knock — the same mechanism as lowHealthTexture's lubdub_flash, but on an
-- independent timer rather than peak-detecting the screen flash.
--
-- The rate is user-tunable (Registry.lua's lowHealthWarning.tunables) rather than fixed: a
-- constant repeat that cannot be slowed down is what turns useful into annoying. Exposed as
-- BPM rather than a raw seconds-interval so the slider number means something — "20 BPM"
-- reads as obviously too slow in a way "3.0 seconds" does not.
local function heartRate() return Pulse.Database:GetTriggerSetting("lowHealthWarning", "heartRate", 56) end

local function beatInterval() return 60 / heartRate() end

-- One slider instead of lowHealthTexture's four (gap/duration/lub/dub): a simpler
-- single-knob version for the cue that tracks nothing visual. 0 leans toward one soft pulse
-- — long gap and duration, lub and dub close in intensity — and 1 toward a sharp, clearly
-- separated double-knock. The four endpoints below are starting guesses; tune by feel.
local function distinctiveness() return Pulse.Database:GetTriggerSetting("lowHealthWarning", "distinctiveness", 0.7) end

local function lerp(from, to, factor) return from + (to - from) * factor end

local function warningKnockShape()
    local d = distinctiveness()
    local gap = lerp(0.06, 0.32, d)
    local duration = lerp(0.15, 0.05, d)
    local lub = lerp(0.6, 1.0, d)
    local dub = lerp(0.55, 0.25, d)
    return gap, duration, lub, dub
end

local function fireWarningBeat()
    local gap, duration, lub, dub = warningKnockShape()
    Pulse:HoldIfEnabled("lowHealthWarning", lub, lub, duration)
    C_Timer.After(gap, function() Pulse:HoldIfEnabled("lowHealthWarning", dub, dub, duration) end)
end

local function stopBeating()
    if beatTicker then
        beatTicker:Cancel()
        beatTicker = nil
    end
end

local function startBeating()
    if beatTicker then return end -- already beating, don't stack a second ticker
    beatTicker = C_Timer.NewTicker(beatInterval(), fireWarningBeat)
end

-- Restarting the ticker on either slider is simplest and costs nothing: it fires at the
-- same rate either way, only its start-of-period phase resets.
Pulse.Database:OnTriggerSettingChanged("lowHealthWarning", "heartRate", function()
    if beatTicker then
        stopBeating()
        startBeating()
    end
end)

local function fireLubDub()
    Pulse:HoldIfEnabled("lowHealthTexture", LUB_INTENSITY, LUB_INTENSITY, KNOCK_DURATION)
    C_Timer.After(
        LUB_DUB_GAP,
        function() Pulse:HoldIfEnabled("lowHealthTexture", DUB_INTENSITY, DUB_INTENSITY, KNOCK_DURATION) end
    )
end

-- lubdub_flash: peak-detects the screen flash's own alpha cycle.

-- prev1 is a local max exactly when it is higher than both neighbour samples.
--
-- The floor excludes the trough (LowHealthFrame's min alpha is about .15) without excluding
-- a real peak, and must stay BELOW that frame's reduced max alpha of .5: its source fades
-- the pulse max from 1.0 to .5 over the first ~3 seconds in this state. CONFIRMED LIVE — a
-- first attempt at .5 caught the initial peaks and then went permanently silent the instant
-- the fade finished, because every later peak settles at or just under .5 and a strict
-- ">.5" never clears again. .3 sits inside both the pre- and post-fade ranges and well clear
-- of the trough.
local function isLocalPeak(older, middle, newer)
    return middle and older and newer and middle > older and middle >= newer and middle > 0.3
end

-- RULE B: LowHealthFrame's widget state is confirmed non-secret, but every read still gets
-- the guard-before-use every other cue gets. The guard IS the test if a patch changes the
-- answer.
local function checkFrame()
    local shown = LowHealthFrame:IsShown()
    if issecretvalue(shown) then return end

    if shown and not wasShown then
        cancelPendingStop() -- a flicker back to shown cancels any stop still waiting out its grace period
        if not beatTicker then fireWarningBeat() end -- immediate first beat, but only if the ticker had actually stopped
        startBeating() -- then repeats for as long as it's still true
    elseif not shown and wasShown then
        cancelPendingStop()
        pendingStopTimer = C_Timer.NewTimer(STOP_GRACE, function()
            pendingStopTimer = nil
            stopBeating()
        end)
        prevAlpha, prevPrevAlpha = nil, nil -- don't let a stale peak carry into the next crossing
    end
    wasShown = shown

    if not shown then return end

    local alpha = LowHealthFrame:GetAlpha()
    if issecretvalue(alpha) then return end

    if HEARTBEAT_STYLE == "lubdub_flash" then
        if isLocalPeak(prevPrevAlpha, prevAlpha, alpha) then
            local now = GetTime()
            if now - lastPeakTime > MIN_PEAK_GAP then
                lastPeakTime = now
                fireLubDub()
            end
        end
        prevPrevAlpha, prevAlpha = prevAlpha, alpha
    else
        -- "smooth": the flash's alpha straight through, both roles driven equally — one
        -- continuous throb, not a low/high texture split.
        Pulse:HoldIfEnabled("lowHealthTexture", alpha, alpha)
    end
end

local function stopPolling()
    if pollTicker then
        pollTicker:Cancel()
        pollTicker = nil
    end
    wasShown = false
    prevAlpha, prevPrevAlpha = nil, nil
    lastPeakTime = 0
    cancelPendingStop()
    stopBeating()
end

local frame = CreateFrame("Frame")

local function sync()
    frame:UnregisterAllEvents()
    stopPolling()
    if not Pulse.Database:Get("masterEnabled") then return end
    if not (Pulse.Database:GetCue("lowHealthWarning") or Pulse.Database:GetCue("lowHealthTexture")) then return end
    if not LowHealthFrame then return end -- global not present: stay silent, RULE E

    -- Seed from live state, never from false: arriving already shown starts the beats
    -- immediately, not on the next crossing.
    local shown = LowHealthFrame:IsShown()
    wasShown = (not issecretvalue(shown)) and shown or false
    if wasShown then startBeating() end

    pollTicker = C_Timer.NewTicker(POLL_INTERVAL, checkFrame)
end

function M:OnEnable() Pulse:BindFrame({ "lowHealthWarning", "lowHealthTexture" }, sync) end

-- Straight to Engine:Set, bypassing HoldIfEnabled's masterEnabled and cue checks, for the
-- reason Pulse:TestMode gives: calibrating a shape should not require switching the cue on,
-- or standing at critical health. Reached by `/pulse test heartbeat`. Fires one knock-pair
-- rather than a ticker, so mashing the command previews gap, duration and intensity
-- together. Always the lub-dub shape regardless of HEARTBEAT_STYLE, since "smooth" has
-- nothing discrete to preview.
function M:TestHeartbeat()
    Pulse.Engine:RefreshDevice()
    if not Pulse.Engine:IsDeviceReady() then return false, "no controller detected" end
    Pulse.Engine:Set("lowHealthTexture", LUB_INTENSITY, LUB_INTENSITY, KNOCK_DURATION)
    C_Timer.After(
        LUB_DUB_GAP,
        function() Pulse.Engine:Set("lowHealthTexture", DUB_INTENSITY, DUB_INTENSITY, KNOCK_DURATION) end
    )
    return true
end

-- Same reasoning as TestHeartbeat above, for lowHealthWarning's own knock instead.
-- `/pulse test warningbeat` reaches this.
function M:TestWarningBeat()
    Pulse.Engine:RefreshDevice()
    if not Pulse.Engine:IsDeviceReady() then return false, "no controller detected" end
    local gap, duration, lub, dub = warningKnockShape()
    Pulse.Engine:Set("lowHealthWarning", lub, lub, duration)
    C_Timer.After(gap, function() Pulse.Engine:Set("lowHealthWarning", dub, dub, duration) end)
    return true
end

function M:_DebugHealth()
    return {
        warningBeatActive = beatTicker ~= nil,
        pollTickerActive = pollTicker ~= nil,
    }
end

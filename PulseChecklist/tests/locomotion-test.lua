-- Targeted test for Locomotion.lua's ground-contact guard.
--
-- Drives the predicate through _DebugGait().grounded, which is the only way in from
-- outside since hasGroundContact is a file local. Each case sets one state true and
-- expects the gait to report itself off the ground.

local ROOT = arg[1] or "."

-- ── Minimal stubs, only what Locomotion.lua touches at load ───────────────────

local now = 1000
function GetTime() return now end

local FrameMT = { __index = function() return function() end end }
function CreateFrame() return setmetatable({}, FrameMT) end

local hooks = {}
function hooksecurefunc(name, fn) hooks[name] = fn end
function JumpOrAscendStart() end

swimming, flying, falling, gliding = false, false, false, false
function IsSwimming() return swimming end
function IsFlying() return flying end
function IsFalling() return falling end
function IsMounted() return false end
C_PlayerInfo = { GetGlidingInfo = function() return gliding, true, 0 end }
C_Spell = { IsSpellKnownOrOverridesKnown = function() return false end }
C_Item = { GetItemInfoInstant = function() return nil end }
Enum = { ItemClass = { Armor = 4 } }
function issecretvalue() return false end
function UnitRace() return "Human", "Human" end
function GetUnitSpeed() return 7.0 end
function GetShapeshiftFormID() return nil end
function GetInventoryItemID() return nil end
function print(...) io.write("[print] ", ..., "\n") end

local Pulse = {
    modules = {},
    Database = {
        GetLocomotionProfile = function() return nil end,
        SetLocomotionProfile = function() end,
        GetTriggerSetting = function(_, _, _, default) return default end,
        GetDevicePreset = function() return "default" end,
        Get = function() return false end,
        GetCue = function() return false end,
    },
    Devices = {},
}
function Pulse:RegisterModule(name, module) self.modules[name] = module end
function Pulse:BindFrame() end
function Pulse:HoldIfEnabled() end
function Pulse:HoldRolesIfEnabled() end

assert(loadfile(ROOT .. "/Modules/Locomotion.lua"))("Pulse", Pulse)

-- ── Cases ─────────────────────────────────────────────────────────────────────

local M = Pulse.modules.Locomotion
local failures = 0

local function check(label, expected)
    local actual = M:_DebugGait().grounded
    local ok = (actual == expected)
    if not ok then failures = failures + 1 end
    io.write(("%-42s grounded=%-5s expected=%-5s %s\n")
        :format(label, tostring(actual), tostring(expected), ok and "ok" or "FAIL"))
end

local function reset()
    swimming, flying, falling, gliding = false, false, false, false
    now = now + 100   -- well past any jump grace
end

reset(); check("standing on ground", true)

reset(); swimming = true
check("swimming", false)

reset(); flying = true
check("flying (also covers a taxi ride)", false)

reset(); gliding = true
check("gliding (Skyriding)", false)

reset(); falling = true
check("falling", false)

-- The rise of a jump: IsFalling() is still false, so only the hook covers it.
reset()
hooks["JumpOrAscendStart"]()
check("jump, 0.0s after the input (ascent)", false)
now = now + 0.40
check("jump, 0.4s after the input (ascent)", false)
now = now + 0.10
check("jump, 0.5s after the input (grace over)", true)

-- And the descent is picked up by IsFalling even after the grace expires.
falling = true
check("jump, grace over but still falling", false)

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))

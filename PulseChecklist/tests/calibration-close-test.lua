-- Run actual settings/engine code with the existing UI mock and controlled time.
local ROOT = arg[1] or 'PulseHaptics'
local file = assert(io.open(ROOT .. '/../PulseChecklist/tests/harness.lua'))
local harness = file:read('*a'); file:close()
local cut = assert(harness:find('-- ── Exercise the spec', 1, true))
local write = io.write
io.write = function() end
local Pulse, frames = assert(loadstring(harness:sub(1, cut - 1) .. '\nreturn Pulse, frames'))()
io.write = write

local now, timers, outputs, messages = 1000, {}, {}, {}
function GetTime() return now end
C_Timer.After = function(delay, fn) timers[#timers + 1] = {at = now + delay, fn = fn} end
C_GamePad.IsEnabled = function() return true end
C_GamePad.GetActiveDeviceID = function() return 1 end
C_GamePad.StopVibration = function() outputs.Low = 0; outputs.High = 0 end
C_GamePad.SetVibration = function(channel, value) outputs[channel] = value end
function print(...) messages[#messages + 1] = {...} end

local function advance(seconds)
 now = now + seconds
 table.sort(timers, function(a, b) return a.at < b.at end)
 local due, future = {}, {}
 for _, timer in ipairs(timers) do
  if timer.at <= now then due[#due + 1] = timer else future[#future + 1] = timer end
 end
 timers = future
 for _, timer in ipairs(due) do timer.fn() end
 for _, frame in ipairs(frames) do
  local fn = frame:GetScript('OnUpdate')
  if fn then fn(frame, seconds) end
 end
end

local total, failures = 0, 0
local function check(label, condition)
 total = total + 1
 if not condition then failures = failures + 1; write('FAIL: ' .. label .. '\n') end
end
local Panel, Engine = Pulse.UI.Panel, Pulse.Engine
Pulse.Database:Init()
local rawCalls = 0
local originalRaw = Engine.RawChannel
Engine.RawChannel = function(self, ...)
 rawCalls = rawCalls + 1
 return originalRaw(self, ...)
end
local function hasLayer(name)
 for _, layer in ipairs(Engine:_DebugLayers()) do if layer.name == name then return true end end
 return false
end
local function reset()
 Pulse.UI.QuickSetup.Close()
 Panel.Close()
 Engine:StopAll()
 timers = {}
 Panel.Open('calibration')
 return assert(Panel.EnsureBuilt())
end
local function startGameplay()
 Engine:Set('retained-gameplay', .15, .1, 60)
end
local rampButton
for _, row in ipairs(Panel.Spec.BuildCalibrationPage()) do
 if row.buttonText == 'Ramp' then rampButton = row; break end
end
assert(rampButton and rampButton.onClick, 'calibration must expose its actual Ramp callback')

local exits = {
 {'Close button', function(window) window.CloseButton:GetScript('OnClick')(window.CloseButton) end},
 {'corner X', function(window) window.ClosePanelButton:GetScript('OnClick')(window.ClosePanelButton) end},
 {'Escape hide', function(window)
   local registered = false
   for _, name in ipairs(UISpecialFrames) do if name == 'PulseSettingsFrame' then registered = true end end
   assert(registered, 'Escape must be registered through UISpecialFrames')
   window:Hide()
  end},
 {'wizard handoff', function() Pulse.UI.QuickSetup.Open() end},
}
for _, route in ipairs(exits) do
 local window = reset()
 startGameplay()
 rampButton.onClick()
 advance(0)
 check(route[1] .. ': ramp starts', Engine:GetActiveRamp() ~= nil)
 route[2](window)
 check(route[1] .. ': settings hidden', not window:IsShown())
 check(route[1] .. ': ramp cleared', Engine:GetActiveRamp() == nil)
 check(route[1] .. ': raw motor silenced', outputs.Low == 0)
 check(route[1] .. ': gameplay layer retained', hasLayer('retained-gameplay'))
 local rawBefore = rawCalls
 Pulse.UI.QuickSetup.Close()
 for _ = 1, 42 do advance(.5) end
 check(route[1] .. ': queued ramp steps cancelled', rawCalls == rawBefore)
 check(route[1] .. ': gameplay survives queued callbacks', hasLayer('retained-gameplay'))
end

-- A one-shot raw test has no activeRamp, but still belongs to the window.
local window = reset()
startGameplay()
Engine:ProbeChannel('Low', .5, 1.5)
advance(0)
check('one-shot probe drives the motor', (outputs.Low or 0) > 0)
window:Hide()
check('one-shot probe stops on hide', outputs.Low == 0)
check('one-shot cleanup preserves gameplay', hasLayer('retained-gameplay'))

-- Closing also cancels continuous preview callbacks and queued discrete preview steps.
window = reset()
startGameplay()
local previewCalls = 0
Pulse:StartContinuousPreview(30, function()
 previewCalls = previewCalls + 1
 Engine:Hold('preview', .5, .5)
end)
check('continuous preview starts', Pulse:IsContinuousPreviewActive())
window:Hide()
check('continuous preview cleared on hide', not Pulse:IsContinuousPreviewActive())
local callsBefore = previewCalls
advance(.1)
check('continuous preview does not restart', previewCalls == callsBefore and not hasLayer('preview'))
check('continuous preview cleanup preserves gameplay', hasLayer('retained-gameplay'))

window = reset()
startGameplay()
Pulse:TestMode('STUTTER')
window:Hide()
advance(5)
check('queued discrete preview cannot restart after hide', not hasLayer('preview'))
check('discrete preview cleanup preserves gameplay', hasLayer('retained-gameplay'))

write(('%d checks, %d failures\n'):format(total, failures))
if failures > 0 then os.exit(1) end

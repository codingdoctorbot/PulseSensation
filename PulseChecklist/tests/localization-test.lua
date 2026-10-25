-- Real UI/data coverage for client locale, override persistence, fallback and stable IDs.
local root = arg[1] or "PulseHaptics"
local scriptDir = arg[0]:match("^(.-)[^/\\]*$") or ""
dofile(scriptDir .. "harness.lua")
local P = _G.Pulse
local locale, db, spec = P.Locale, P.Database, P.UI.Panel.Spec
-- The shared harness restores PulseDB after migration fixtures; rebind the real store.
db:Init()
local count, failures = 0, 0
local function check(label, condition)
 count = count + 1
 if not condition then failures = failures + 1; io.write("FAIL " .. label .. "\n") end
end
local function load(path, namespace) assert(loadfile(root .. "/" .. path))("PulseHaptics", namespace) end

-- A fresh localization core does not inspect the client or SavedVariables at load time.
local clientReads = 0
GetLocale = function() clientReads = clientReads + 1; return "frFR" end
local fresh = {}
load("Core/Locale.lua", fresh)
load("Locales/enUS.lua", fresh)
check("deferred client detection", clientReads == 0)
fresh.Locale:Initialize("auto")
check("automatic uses client", fresh.Locale.active == "frFR")
local clientFunction = GetLocale
fresh.Locale:Initialize("enUS")
check("addon override leaves GetLocale untouched", GetLocale == clientFunction and GetLocale() == "frFR")
fresh.Locale:Initialize("auto")
check("missing translation uses English", fresh.L("Enable Pulse") == "Enable Pulse")
fresh.Locale:Initialize("enUS")
check("English override on French client", fresh.Locale.active == "enUS")
GetLocale = function() return "enGB" end
fresh.Locale:Initialize("auto")
check("British English uses English catalog", fresh.Locale.active == "enUS")
GetLocale = function() return "xxXX" end
fresh.Locale:Initialize("auto")
check("unknown client falls back to English", fresh.Locale.active == "enUS")
check("unknown catalog code rejected", not fresh.Locale:Register("xxXX", {}))
check("Automatic cannot be a catalog", not fresh.Locale:Register("auto", {}))
fresh.Locale:Initialize("invalid")
check("invalid saved selection normalized", fresh.Locale.requested == "auto")

local missingEnglish = locale:GetMissingEnglishKeys()
for _, key in ipairs(missingEnglish) do io.write("Missing English metadata key: " .. key .. "\n") end
check("all registered metadata has English keys", #missingEnglish == 0)
check("English-only install exposes Automatic and English", #fresh.Locale:GetOptions() == 2)
local triggerFacts, profileNames, sectionKeys = {}, db:GetProfileNames(), {}
local lowChannel = P.HapticSchemas.standard.roles.low.channel
local highChannel = P.HapticSchemas.standard.roles.high.channel
for _, trigger in ipairs(P.Triggers) do
 triggerFacts[trigger.id] = { trigger.category, trigger.mode, trigger.default }
end
for _, page in ipairs(P.Registry:GetPages()) do
 for _, section in ipairs(page.sections) do sectionKeys[section] = page.id .. "/" .. section._englishLabel end
end
local locales = { "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
for _, code in ipairs(locales) do
 GetLocale = function() return code end
 -- Synthetic translations ensure the architecture is exercised even while catalog work
 -- is incomplete; this test does not claim linguistic translation coverage.
 if code ~= "enUS" then
  locale:Register(code, { ["Combat"] = code .. " Combat", ["Enable Pulse"] = code .. " Enable Pulse" })
 end
 locale:Initialize("auto")
 check(code .. " automatic", locale.active == code)
 check(code .. " stable motor channels", P.HapticSchemas.standard.roles.low.channel == lowChannel and P.HapticSchemas.standard.roles.high.channel == highChannel)
 check(code .. " source metadata translated", P.Registry:GetPages()[1].label == (code == "enUS" and "Combat" or code .. " Combat"))
 check(code .. " missing text survives", P.L("Missing test translation") == "Missing test translation")
 for _, trigger in ipairs(P.Triggers) do
  local fact = triggerFacts[trigger.id]
  check(code .. " stable cue " .. trigger.id, fact and fact[1] == trigger.category and fact[2] == trigger.mode and fact[3] == trigger.default)
 end
 for _, page in ipairs(P.Registry:GetPages()) do
  for _, section in ipairs(page.sections) do
   check(code .. " stable section key", page.id .. "/" .. section._englishLabel == sectionKeys[section])
  end
 end
 for i, name in ipairs(db:GetProfileNames()) do check(code .. " saved profile IDs", name == profileNames[i]) end
 for _, page in ipairs(spec.BuildPages()) do
  local ok, rows = pcall(page.build)
  check(code .. " build " .. page.id, ok and type(rows) == "table")
 end
end
locale:Register("frFR", { ["Value: %s (%d)"] = "Valeur : %s (%d)", ["Bad: %d"] = "Mauvais : %s", ["Empty"] = "" })
locale:Initialize("frFR")
check("valid format accepted", P.L("Value: %s (%d)"):format("x", 2) == "Valeur : x (2)")
check("mismatched placeholders rejected", P.L("Bad: %d") == "Bad: %d")
check("empty translation falls back", P.L("Empty") == "Empty")
locale:Register("deDE", { ["At %d%%"] = "Bei %d%%", ["Bad %d%%"] = "Falsch %d" })
locale:Initialize("deDE")
check("escaped percentage retained", P.L("At %d%%"):format(20) == "Bei 20%")
check("lost escaped percentage rejected", P.L("Bad %d%%") == "Bad %d%%")
local late = { id = "stable", value = "Combat", label = "Combat" }
locale:Register("deDE", { ["Combat"] = "Test Combat" })
locale:RegisterTable(late)
check("late data registration is localized", late.label == "Test Combat")
check("late data registration preserves IDs and values", late.id == "stable" and late.value == "Combat")
locale:Initialize("frFR")
check("non-string values not coerced", locale:Text(false) == false)
check("12 language options", #locale:GetOptions() == 12)
check("custom profile names unchanged", locale:ProfileLabel("My custom profile") == "My custom profile")

local choice
for _, row in ipairs(spec.BuildRootPage()) do
 if row.kind == "dropdown" and row.get and row.get() == db:Get("language") then
  local options = row.options and row.options()
  if options and options[1] and options[1].value == "auto" then choice = row end
 end
end
check("language option exists", choice ~= nil)
if choice then
 local active = locale.active
 choice.set("deDE")
 check("selection saved globally", db:Get("language") == "deDE")
 check("selection waits for reload", locale.active == active and locale:NeedsReload())
 choice.set("bad-code")
 check("invalid UI selection ignored", db:Get("language") == "deDE")
 local oldProfile = db:GetActiveProfileName()
 db:SetActiveProfileName("Questing")
 check("language independent of profile", db:Get("language") == "deDE")
 db:SetActiveProfileName(oldProfile)
 db:Init()
 check("saved override applied on initialization", locale.active == "deDE")
 choice.set("auto")
 db:Init()
end
for key, value in pairs(locale.catalogs.enUS) do check("English identity", key == value) end
io.write(string.format("Localization: %d checks, %d failures\n", count, failures))
if failures > 0 then os.exit(1) end

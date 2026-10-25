-- Display-only localization. English strings are stable translation keys.
-- No global hooks, gameplay lookups, or SavedVariables access at file load.
local _, Pulse = ...
local Locale = { catalogs = {}, active = "enUS", requested = "auto", initialized = false }
Pulse.Locale = Locale
local supported = {
 { code = "enUS", label = "English" }, { code = "deDE", label = "Deutsch" },
 { code = "esES", label = "Español (España)" }, { code = "esMX", label = "Español (Latinoamérica)" },
 { code = "frFR", label = "Français" }, { code = "itIT", label = "Italiano" },
 { code = "ptBR", label = "Português (Brasil)" }, { code = "ruRU", label = "Русский" },
 { code = "koKR", label = "한국어" }, { code = "zhCN", label = "简体中文" },
 { code = "zhTW", label = "繁體中文" },
}
local known = { auto = true }
for _, entry in ipairs(supported) do known[entry.code] = true end
local function normalize(code)
 if code == "enGB" then return "enUS" end
 return known[code] and code or "enUS"
end
function Locale:IsSupported(code)
 return type(code) == "string" and known[code] == true
end
local function signature(text)
 local result, i = {}, 1
 while i <= #text do
  if text:sub(i, i) == "%" then
   if text:sub(i + 1, i + 1) == "%" then result[#result + 1] = "%"; i = i + 2
   else
    local token = text:sub(i):match("^%%[-+ #0]*%d*%.?%d*([cdeEfgGiouXxqs])")
    if token then result[#result + 1] = token end
    i = i + 1
   end
  else i = i + 1 end
 end
 return table.concat(result, ",")
end
function Locale:Register(code, catalog)
 if not self:IsSupported(code) or code == "auto" or type(catalog) ~= "table" then return false end
 local clean = {}
 for key, value in pairs(catalog) do
  if type(key) == "string" and type(value) == "string" and value ~= "" and signature(key) == signature(value) then
   clean[key] = value
  end
 end
 self.catalogs[code] = clean
 return true
end
function Locale:Text(text)
 if type(text) ~= "string" then return text end
 local catalog = self.catalogs[self.active]
 return (catalog and catalog[text]) or (self.catalogs.enUS and self.catalogs.enUS[text]) or text
end
Pulse.L = function(text) return Locale:Text(text) end
local displayFields = {
 label = true, desc = true, caveat = true, heading = true, body = true,
 summary = true, emphasizes = true, silences = true, title = true,
 tooltip = true, buttonText = true, description = true,
}
local bindings = {}
local registered = setmetatable({}, { __mode = "k" })
function Locale:RegisterTable(data, allValues)
 if type(data) ~= "table" or registered[data] then return end
 registered[data] = true
 local englishLabel = data.label
 for key, value in pairs(data) do
  if type(value) == "table" then self:RegisterTable(value, allValues)
  elseif type(value) == "string" and (allValues or displayFields[key]) then
   bindings[#bindings + 1] = { data, key, value }
   if self.initialized then data[key] = self:Text(value) end
  end
 end
 if type(englishLabel) == "string" then data._englishLabel = englishLabel end
end
function Locale:Initialize(requested)
 self.requested = self:IsSupported(requested) and requested or "auto"
 local client = type(GetLocale) == "function" and GetLocale() or "enUS"
 self.client = normalize(client)
 self.active = self.requested == "auto" and self.client or normalize(self.requested)
 self.initialized = true
 for _, binding in ipairs(bindings) do binding[1][binding[2]] = self:Text(binding[3]) end
end
function Locale:GetOptions()
 local options = { { value = "auto", label = self:Text("Automatic — game language") } }
 for _, entry in ipairs(supported) do
  if self.catalogs[entry.code] then
   options[#options + 1] = { value = entry.code, label = entry.label }
  end
 end
 return options
end
function Locale:NeedsReload()
 local requested = Pulse.Database:Get("language")
 if not self:IsSupported(requested) then requested = "auto" end
 return requested ~= self.requested
end

function Locale:ProfileLabel(name)
 if name == "Default" then return self:Text(name) end
 for _, profile in ipairs(Pulse.DEFAULT_PROFILE_METADATA or {}) do
  if profile.id == name then return self:Text(name) end
 end
 return name
end

-- Diagnostics for authors and the offline harness; never called from the haptic loop.
function Locale:GetMissingEnglishKeys()
 local missing, seen = {}, {}
 local english = self.catalogs.enUS or {}
 for _, binding in ipairs(bindings) do
  local text = binding[3]
  if not english[text] and not seen[text] then
   missing[#missing + 1] = text
   seen[text] = true
  end
 end
 table.sort(missing)
 return missing
end

function Locale:ProfileReason(scope)
 local db = Pulse.Database
 if scope == db.SCOPE_SPEC then
  local id, name = db:GetSpecInfo()
  return self:Text("this specialization (%s)"):format(name or tostring(id))
 elseif scope == db.SCOPE_CHARACTER then return self:Text("this character")
 elseif scope == db.SCOPE_ACCOUNT then return self:Text("every character")
 end
 return self:Text("nothing set — falling back to Default")
end

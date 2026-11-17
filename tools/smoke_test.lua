-- Minimaler WoW-API-Mock für einen Rauchtest von ManaSigil
-- Aufruf (aus dem Addon-Ordner): lua5.1 tools/smoke_test.lua .
local dir = arg[1]
local now, mana, maxMana = 100, 1000, 1000
local scripts = {}
local function obj()
    local o = {}
    return setmetatable(o, { __index = function(t, k)
        if k == "GetFrameLevel" then return function() return 1 end end
        if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 10, 20 end end
        if k == "GetChecked" then return function() return true end end
        if k == "SetScript" then return function(self, n, fn) scripts[self] = scripts[self] or {}; scripts[self][n] = fn end end
        if k:match("^Create") then return function() return obj() end end
        return function() end
    end })
end
CreateFrame = function() return obj() end
UIParent, GameTooltip, ColorPickerFrame = obj(), obj(), obj()
STANDARD_TEXT_FONT = "x"
Enum = { PowerType = { Mana = 0 } }
GetTime = function() return now end
UnitPower = function() return mana end
UnitPowerMax = function() return maxMana end
UnitClass = function() return "Priester", "PRIEST" end
UnitAffectingCombat = function() return false end
InCombatLockdown = function() return false end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strsplit = function(sep, s, n) local a, b = s:match("^(%S*)%s*(.*)$"); return a, (b ~= "" and b or nil) end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
SlashCmdList = {}
Settings = { RegisterCanvasLayoutCategory = function() return { GetID = function() return 1 end } end,
             RegisterAddOnCategory = function() end, OpenToCategory = function() end }

local ns = {}
Minimap = obj()
Minimap.GetWidth = function() return 140 end
Minimap.GetHeight = function() return 140 end
Minimap.GetCenter = function() return 500, 500 end
Minimap.GetEffectiveScale = function() return 1 end
GetCursorPosition = function() return 400, 600 end
for _, f in ipairs({ "Core", "Themes", "Tracker", "Display", "Options", "Minimap" }) do
    assert(loadfile(dir .. "/" .. f .. ".lua"))("ManaSigil", ns)
end
local ev = scripts[ns.eventFrame].OnEvent
ev(nil, "ADDON_LOADED", "ManaSigil")
ev(nil, "PLAYER_LOGIN")
local upd = scripts[ns.Display.frame].OnUpdate

-- Mana verbrauchen -> FSR
mana = 800; ev(nil, "UNIT_POWER_UPDATE", "player", "MANA")
assert(ns.Tracker:InFSR(), "FSR sollte aktiv sein")
now = now + 2; upd(nil, 1)
print("FSR rest", ns.Tracker:FSRRemaining(), "info:", "ok")
now = now + 4; upd(nil, 1)
assert(not ns.Tracker:InFSR(), "FSR sollte vorbei sein")
mana = 850; ev(nil, "UNIT_POWER_UPDATE", "player", "MANA")
assert(ns.Tracker.tickAmount == 50, "Tick erwartet")
now = now + 1; upd(nil, 1)
print("Tickfortschritt", ns.Tracker:TickProgress())

-- alle Themen, Dekorationen, Textmodi durchprobieren
for _, key in ipairs(ns.themeOrder) do
    SlashCmdList.MANASIGIL("theme " .. key)
    for _, dec in ipairs({ "theme", "none", "demon" }) do
        ns.db.decor = dec
        for _, tm in ipairs({ "percent", "value", "both", "none" }) do
            ns.db.textMode = tm; ns.Display:Refresh(); now = now + 0.1; upd(nil, 1)
        end
    end
end
-- Module aus, geheime Werte simulieren
for k in pairs(ns.db.modules) do ns.db.modules[k] = false end
ns.Display:Refresh(); upd(nil, 1)
issecretvalue = function(v) return type(v) == "number" end
for k in pairs(ns.db.modules) do ns.db.modules[k] = true end
ns.Tracker:OnPower(); ns.Tracker:OnSpellCast(123); ns.Display:Refresh(); upd(nil, 1)
SlashCmdList.MANASIGIL(""); SlashCmdList.MANASIGIL("test"); SlashCmdList.MANASIGIL("lock"); SlashCmdList.MANASIGIL("help")
ns.Options:RefreshWidgets()
-- Minimap-Button: Klick an/aus, Rechtsklick, Ziehen, ausblenden
local mb = scripts[ns.Minimap.button]
mb.OnClick(nil, "LeftButton"); assert(ns.db.enabled == false and not ns.Display:ShouldShow(), "aus erwartet")
mb.OnClick(nil, "LeftButton"); assert(ns.db.enabled == true, "an erwartet")
mb.OnClick(nil, "RightButton")
mb.OnDragStart(ns.Minimap.button); scripts[ns.Minimap.button].OnUpdate(ns.Minimap.button)
print("Minimap-Winkel", ns.db.minimap.angle)
mb.OnEnter(ns.Minimap.button)
GetMinimapShape = function() return "SQUARE" end; ns.Minimap:UpdatePosition()
SlashCmdList.MANASIGIL("minimap"); SlashCmdList.MANASIGIL("minimap"); SlashCmdList.MANASIGIL("off"); SlashCmdList.MANASIGIL("on")
-- Gestaltung: alle Symbole, Stile, Hintergründe, Extremwerte, Farben
for _, shape in ipairs(ns.shapeOrder) do
    for _, rs in ipairs({ "symbols", "solid" }) do
        local st = ns.db.style
        st.outerShape, st.innerShape, st.outerStyle, st.innerStyle = shape, shape, rs, rs
        for _, bgs in ipairs({ "disc", "soft", "ring" }) do
            st.bgShape = bgs; ns.Display:Refresh(); now = now + 0.05; upd(nil, 1)
        end
    end
end
local st = ns.db.style
st.outerCount, st.outerSize, st.outerRadius, st.innerSize, st.innerRadius = 120, 3.0, 0.7, 0.3, 0.1
ns.Display:Refresh(); upd(nil, 1)
assert(ns.Display.outer.n <= 240 and ns.Display.inner.n >= 12, "Pip-Grenzen")
print("solid-Pips außen/innen", ns.Display.outer.n, ns.Display.inner.n)
st.outerStyle = "symbols"; ns.Display:Refresh()
assert(ns.Display.outer.n == 120, "120 Symbole erwartet")
st.outerCount = 8; ns.Display:Refresh(); assert(ns.Display.outer.n == 8)
for _, ck in ipairs(ns.colorKeys) do ns.db.colors[ck[1]] = { 0.1, 0.2, 0.3 } end
ns.Display:Refresh(); upd(nil, 1)
ns.db.colors = {}; ns.db.theme = "auto"; st.outerShape = "theme"; st.innerShape = "theme"
assert(ns.GetStyle("outerShape") == "dot" and ns.GetStyle("innerShape") == "star", "Priester-Standard")
ns.db.theme = "demon"; assert(ns.GetStyle("outerShape") == "flame")
for k in pairs(ns.db.modules) do ns.db.modules[k] = false end
ns.Display:Refresh(); upd(nil, 1)
for k in pairs(ns.db.modules) do ns.db.modules[k] = true end
ns.Display:Refresh(); upd(nil, 1); ns.Options:RefreshWidgets()
print("ALLES OK")

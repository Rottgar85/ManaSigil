-- Minimaler WoW-API-Mock für einen Rauchtest von ManaSigil
-- Aufruf (aus dem Addon-Ordner): lua5.1 tools/smoke_test.lua .
local dir = arg[1]
local now, mana, maxMana = 100, 1000, 1000
local scripts = {}
local obj
-- Wie im Spiel: SetText ohne gesetzten Font bricht ab ("Font not set")
local function fontString(template)
    local fs = obj()
    local hasFont = template ~= nil
    rawset(fs, "SetFont", function() hasFont = true end)
    rawset(fs, "SetFontObject", function() hasFont = true end)
    local function needFont() if not hasFont then error("FontString:SetText(): Font not set") end end
    rawset(fs, "SetText", needFont)
    rawset(fs, "SetFormattedText", needFont)
    return fs
end
function obj()
    local o = {}
    return setmetatable(o, { __index = function(t, k)
        if k == "GetFrameLevel" then return function() return 1 end end
        if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 10, 20 end end
        if k == "GetChecked" then return function() return true end end
        if k == "SetScript" then return function(self, n, fn) scripts[self] = scripts[self] or {}; scripts[self][n] = fn end end
        if k == "CreateFontString" then return function(_, _, _, template) return fontString(template) end end
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
GetManaRegen = function() return 12, 3 end   -- Mana pro Sekunde: normal, beim Zaubern
-- Sprache über Umgebungsvariable LOCALE testen (Standard: deDE)
GetLocale = function() return os.getenv("LOCALE") or "deDE" end
for _, f in ipairs({ "Locale", "Core", "Themes", "Tracker", "Display", "Options", "Minimap" }) do
    assert(loadfile(dir .. "/" .. f .. ".lua"))("ManaSigil", ns)
end
-- im Test jeden abgefangenen Fehler sofort sichtbar machen
ns.ReportError = function(where, err) error(where .. ": " .. tostring(err), 0) end
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
-- 1.2: Modi, Richtungen, Füllrichtung, MP5, Deko-Teile, Migration
issecretvalue = nil
local D = ns.Display
for _, mode in ipairs({ "ring", "pie", "bar" }) do
    SlashCmdList.MANASIGIL("mode " .. mode)
    assert(ns.db.mode == mode and D.mode == mode, "Modus " .. mode)
    for di, dir in ipairs({ "cw", "ccw", "up", "down", "ltr", "rtl" }) do
        st.outerDir, st.innerDir = dir, ({ "down", "up", "ccw", "rtl", "ltr", "cw" })[di]
        st.barDir = (di % 2 == 1) and "forward" or "reverse"
        st.innerBarDir = (di % 2 == 0) and "forward" or "reverse"
        st.barOrientation = (di <= 2) and "horizontal" or "vertical"
        st.pieStyle = (di % 2 == 1) and "smooth" or "segments"
        for _, ff in ipairs({ "drain", "fill" }) do
            st.fsrFill, st.tickFill = ff, ff
            for _, mp in ipairs({ "off", "current", "both" }) do
                st.mp5Mode = mp
                st.innerHideIdle = (mp == "both")
                D:Refresh(); now = now + 0.3; upd(nil, 1)
                mana = 600; ev(nil, "UNIT_POWER_UPDATE", "player", "MANA"); now = now + 0.5; upd(nil, 1)
                now = now + 6; mana = 650; ev(nil, "UNIT_POWER_UPDATE", "player", "MANA"); now = now + 0.5; upd(nil, 1)
            end
        end
    end
end
assert(ns.Display.outer.n == 0 and ns.Display.T1 and ns.Display.T1 > 0, "Balken-Modus aktiv")
-- Senkrechter Balken: Länge entspricht der Höhe
st.barOrientation, st.barWidth, st.barHeight = "vertical", 0.2, 1.6
SlashCmdList.MANASIGIL("mode bar"); upd(nil, 1)
assert(D.horiz == false and math.abs(D.L1 - 1.6 * ns.db.size) < 1e-6, "senkrechter Balken")
-- Torte als Flüssigkeit, in Stücken: Füllung in ganzen Stücken
st.outerDir, st.pieStyle, st.pieSegments = "up", "segments", 10
SlashCmdList.MANASIGIL("mode pie"); upd(nil, 1)
assert(D.pieLiquid and D.segN == 10 and D.outer.n == 0, "Flüssigkeits-Torte in 10 Stücken")
-- Torte von links nach rechts in Tausendsteln: Flüssigkeit, keine Trennlinien
local gapsBefore = #D.gaps
st.outerDir, st.pieSegments = "ltr", 1000
SlashCmdList.MANASIGIL("mode pie"); upd(nil, 1)
assert(D.pieLiquid and D.segN == 1000 and #D.gaps == gapsBefore, "Tausendstel ohne Trennlinien")
st.outerDir, st.pieSegments = "rtl", 4
SlashCmdList.MANASIGIL("mode pie"); upd(nil, 1)
assert(D.pieLiquid and D.segN == 4, "Torte von rechts in Vierteln")
-- Kreis von links nach rechts: linkestes Symbol zuerst
st.outerDir, st.outerStyle = "ltr", "symbols"
SlashCmdList.MANASIGIL("mode ring")
do
    local li, lo = nil, 2
    for i = 1, D.outer.n do if D.outer.ov[i] < lo then li, lo = i, D.outer.ov[i] end end
    assert(lo < 0.1 and math.cos(math.pi / 2 - (li - 0.5) / D.outer.n * 2 * math.pi) < -0.9, "links beginnt die Füllung")
end
-- Kreis von unten nach oben: unterstes Symbol wird zuerst gefüllt
st.outerDir, st.outerStyle = "up", "symbols"
SlashCmdList.MANASIGIL("mode ring")
local lowest, lowOv = nil, 2
for i = 1, D.outer.n do if D.outer.ov[i] < lowOv then lowest, lowOv = i, D.outer.ov[i] end end
assert(lowOv < 0.1 and math.sin(math.pi / 2 - (lowest - 0.5) / D.outer.n * 2 * math.pi) < -0.9, "unten beginnt die Füllung")
-- Umstellung der Einstellungen aus 1.2.0 (Version 2)
do
    local old = { dbVersion = 2, style = { outerClockwise = false, innerClockwise = true, barWidth = 1.0, barHeight = 2.0 } }
    ManaSigilDB = old
    local loaded = ns.db
    ev(nil, "ADDON_LOADED", "ManaSigil")
    local s = ManaSigilDB.style
    assert(s.outerDir == "ccw" and s.barDir == "reverse" and s.innerDir == "cw", "Richtung übernommen")
    assert(math.abs(s.barWidth - 1.6) < 1e-9 and math.abs(s.barHeight - 0.4) < 1e-9, "Balkenmaße umgerechnet")
    assert(s.outerClockwise == nil and ManaSigilDB.dbVersion == 4, "alte Felder entfernt")
    ManaSigilDB = loaded; ns.db = loaded
end
-- Umstellung aus 1.3.x: "Mana-Anzeige auch einfärben" -> eigener Verlauf der Mana-Leiste
do
    local old = { dbVersion = 3, style = { gradientRing = true, gradMidPct = 40 }, colors = { high = { 0, 0, 1 } } }
    ManaSigilDB = old
    local loaded = ns.db
    ev(nil, "ADDON_LOADED", "ManaSigil")
    local s, c = ManaSigilDB.style, ManaSigilDB.colors
    assert(s.manaColorMode == "gradient" and s.gradientRing == nil and s.manaGradMid == 40, "Mana-Verlauf übernommen")
    assert(c.manaHigh and c.manaHigh[3] == 1, "eigene Verlaufsfarbe übernommen")
    ManaSigilDB = loaded; ns.db = loaded
end
-- Leisten: getrennte Verläufe für Mana und Timer
do
    local D = ns.Display
    ns.db.colors.manaHigh = { 0, 0, 1 }
    ns.db.colors.timerHigh = { 1, 0, 1 }
    local r, g, b = D:GradientColor(1, "mana");  assert(b == 1 and r == 0, "Mana-Verlauf eigene Farbe")
    r, g, b = D:GradientColor(1, "timer");       assert(r == 1 and b == 1 and g == 0, "Timer-Verlauf eigene Farbe")
    r, g, b = D:GradientColor(1);                 assert(g > r and g > b, "Zahlen-Verlauf unverändert")
    ns.db.style.manaColorMode = "gradient"; ns.db.style.timerColorMode = "gradient"
    for _, m in ipairs({ "bar", "ring", "pie" }) do
        SlashCmdList.MANASIGIL("mode " .. m); D:Update(now)
    end
    ns.db.colors.manaHigh, ns.db.colors.timerHigh = nil, nil
    ns.db.style.manaColorMode = "fixed"; ns.db.style.timerColorMode = "fixed"
end
st.outerDir = "cw"; SlashCmdList.MANASIGIL("mode pie"); assert(D.outer.n == 90 and D.outer.kind == "pie", "Torte mit 90 Stücken")
-- MP5: 12 bzw. 3 Mana/Sek. -> 60 / 15 pro 5 Sekunden
local b5, c5 = ns.Tracker:GetMP5(); assert(b5 == 60 and c5 == 15, "MP5-Berechnung")
st.mp5Mode = "both"; ns.Tracker:StartFSR()
local line = D:MP5Line(now); print("MP5-Zeile:", line)
assert(line:find("60") and line:find("15"), "MP5-Zeile enthält beide Werte")
-- Drehung über Texturkoordinaten: Mittelpunkt bleibt in der Mitte
local got = {}
local fake = { SetTexCoord = function(_, ...) got = { ... } end }
ns.RotTexCoord(fake, math.pi / 2)
local cx = (got[1] + got[3] + got[5] + got[7]) / 4
local cy = (got[2] + got[4] + got[6] + got[8]) / 4
assert(math.abs(cx - 0.5) < 1e-9 and math.abs(cy - 0.5) < 1e-9, "Drehung um den Mittelpunkt")
-- Deko-Teile einzeln ausblenden (Engelsflügel: Heiligenschein weg)
ns.db.theme = "angel"; ns.db.decor = "theme"; ns.db.decorOff.halo = true
local count = #ns.GetDecor(); ns.db.decorOff.halo = nil
assert(count == #ns.GetDecor() - 1, "Heiligenschein einzeln ausblendbar")
-- Ersatzbalken abschaltbar
ns.db.modules.fallback = false; issecretvalue = function(v) return type(v) == "number" end
SlashCmdList.MANASIGIL("mode ring"); upd(nil, 1); issecretvalue = nil
SlashCmdList.MANASIGIL("debug")
ns.Options:RefreshWidgets()

-- Farbverlauf & Warnung bei wenig Mana
do
    local plays = 0
    PlaySound = function() plays = plays + 1 end
    local D = ns.Display
    st.warnEnabled, st.warnUnit, st.warnValue, st.warnSound, st.warnRepeat, st.warnBlink = true, "percent", 20, "raid", 0, "all"
    st.textColorMode = "gradient"
    local r, g = D:GradientColor(1); assert(g > r, "voll = grün")
    r, g = D:GradientColor(0); assert(r > g, "leer = rot")
    r, g = D:GradientColor(0.5); assert(r > 0.9 and g > 0.8, "Mitte = gelb")
    mana = 900; ev(nil, "UNIT_POWER_UPDATE", "player", "MANA"); now = now + 0.1; upd(nil, 1)
    assert(plays == 0, "kein Ton bei 90 %")
    mana = 150; ev(nil, "UNIT_POWER_UPDATE", "player", "MANA")
    for _ = 1, 5 do now = now + 0.1; upd(nil, 1) end
    assert(plays == 1, "Ton genau einmal beim Unterschreiten")
    assert(D.blinkAll, "Anzeige blinkt")
    mana = 210; ev(nil, "UNIT_POWER_UPDATE", "player", "MANA"); now = now + 0.1; upd(nil, 1)
    mana = 150; ev(nil, "UNIT_POWER_UPDATE", "player", "MANA"); now = now + 0.1; upd(nil, 1)
    assert(plays == 1, "kein neuer Ton beim Pendeln knapp über der Schwelle")
    mana = 500; ev(nil, "UNIT_POWER_UPDATE", "player", "MANA"); now = now + 0.1; upd(nil, 1)
    assert(not D.blinkAll, "Blinken endet")
    mana = 100; ev(nil, "UNIT_POWER_UPDATE", "player", "MANA"); now = now + 0.1; upd(nil, 1)
    assert(plays == 2, "nach Erholung wieder ein Ton")
    st.warnRepeat = 3; now = now + 3.1; upd(nil, 1)
    assert(plays == 3, "Wiederholung nach 3 s")
    st.warnUnit, st.warnValue = "mana", 50; now = now + 0.1; upd(nil, 1)
    assert(not D:IsLowMana(100, 0.1, true), "Schwelle in Manapunkten")
    st.warnCombatOnly = true; st.warnUnit, st.warnValue = "percent", 20
    assert(not D:IsLowMana(100, 0.1, true), "nur im Kampf")
    st.warnCombatOnly = false; st.warnRepeat = 0
    mana = 1000; ev(nil, "UNIT_POWER_UPDATE", "player", "MANA"); now = now + 0.1; upd(nil, 1)
end

-- Geheime Manawerte: Ticks und 5-Sek.-Regel werden über die Events erkannt
do
    local SMT = {}
    local function boom() error("secret value used", 2) end
    for _, m in ipairs({ "__add", "__sub", "__mul", "__div", "__lt", "__le", "__concat", "__unm" }) do SMT[m] = boom end
    local oldUP, oldUPM, oldRegen = UnitPower, UnitPowerMax, GetManaRegen
    issecretvalue = function(v) return getmetatable(v) == SMT end
    UnitPower = function() return setmetatable({}, SMT) end
    UnitPowerMax = function() return setmetatable({}, SMT) end
    GetManaRegen = function() return setmetatable({}, SMT), setmetatable({}, SMT) end
    local T = ns.Tracker
    T:Reset(); T.fsrEnd = 0
    for _, mode in ipairs({ "bar", "ring", "pie" }) do
        SlashCmdList.MANASIGIL("mode " .. mode)
        for _ = 1, 3 do now = now + 2; ev(nil, "UNIT_POWER_UPDATE", "player", "MANA"); upd(nil, 1) end
    end
    assert(T.lastTick == now and T:TickProgress(now + 1) == 0.5, "Tick bei geheimen Werten erkannt")
    -- fließende Regeneration: viele FREQUENT-Events dürfen keinen Tick erzeugen
    local tickAt = T.lastTick
    for _ = 1, 15 do now = now + 0.1; ev(nil, "UNIT_POWER_FREQUENT", "player", "MANA") end
    assert(T.lastTick == tickAt, "FREQUENT-Events sind keine Ticks")
    assert(T.stats.frequent >= 15, "Event-Statistik zählt FREQUENT")
    now = now + 0.5; ev(nil, "UNIT_POWER_UPDATE", "player", "MANA")
    assert(T.lastTick == now, "UPDATE-Event ist ein Tick")
    SlashCmdList.MANASIGIL("debug")
    now = now + 0.7
    ev(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "g", 2050); now = now + 0.1
    ev(nil, "UNIT_POWER_UPDATE", "player", "MANA"); upd(nil, 1)
    assert(T:InFSR(now), "5-Sek.-Regel bei geheimen Werten über den Zauber erkannt")
    -- Kurven des Spiels: Prozent, Farbverlauf und Warnung trotz geheimer Werte
    local secretFrac = 0.1
    Enum.LuaCurveType = { Linear = 1, Step = 2 }
    C_CurveUtil = { CreateCurve = function()
        local c = { pts = {} }
        function c:SetType(t) self.t = t end
        function c:AddPoint(x, y) self.pts[#self.pts + 1] = { x, y } end
        function c:Eval(x)
            local p = self.pts
            if self.t == 2 then local v = p[1][2]; for _, q in ipairs(p) do if x >= q[1] then v = q[2] end end; return v end
            for i = 2, #p do if x <= p[i][1] then local a, b = p[i - 1], p[i]; return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1]) end end
            return p[#p][2]
        end
        return c end }
    local evals = {}
    UnitPowerPercent = function(_, _, _, curve) local v = curve:Eval(secretFrac); evals[#evals + 1] = v; return setmetatable({ v = v }, SMT) end
    st.warnEnabled, st.warnUnit, st.warnValue, st.textColorMode, st.warnBlink = true, "percent", 20, "gradient", "text"
    st.manaColorMode, st.timerColorMode = "gradient", "gradient"
    for _, mode in ipairs({ "bar", "ring" }) do
        for _, tm in ipairs({ "percent", "value", "both" }) do
            ns.db.textMode = tm
            SlashCmdList.MANASIGIL("mode " .. mode); upd(nil, 1)
        end
    end
    assert(ns.Display.cv and ns.Display.cv.low, "Kurven gebaut")
    assert(ns.Display.cv.low:Eval(0.1) == 1 and ns.Display.cv.low:Eval(0.5) == 0, "Warnkurve: 10 % = wenig, 50 % = genug")
    assert(#evals > 0, "UnitPowerPercent wird genutzt")
    assert(ns.Display.cv.br and ns.Display.cv.bb, "Farbkurven der Mana-Leiste gebaut")
    st.manaColorMode, st.timerColorMode = "fixed", "fixed"
    C_CurveUtil, UnitPowerPercent = nil, nil; ns.db.textMode = "both"
    UnitPower, UnitPowerMax, GetManaRegen, issecretvalue = oldUP, oldUPM, oldRegen, nil
    T:Reset()
end

-- Visuelle Effekte einzeln abschaltbar
do
    local D, st = ns.Display, ns.db.style
    st.fxTickFlash = false; D:OnTick(); assert(D.flashAlpha == 0, "kein Aufblitzen, wenn aus")
    st.fxTickFlash = true;  D:OnTick(); assert(D.flashAlpha > 0, "Aufblitzen, wenn an")
    for _, k in ipairs({ "fxRotate", "fxBob", "fxPulse", "fxFlicker", "fxSparkPulse", "fxRimPulse" }) do st[k] = false end
    for _, th in ipairs({ "angel", "storm" }) do
        if ns.themes[th] then SlashCmdList.MANASIGIL("theme " .. th) end
        for _, m in ipairs({ "ring", "bar" }) do SlashCmdList.MANASIGIL("mode " .. m); D:Update(now) end
    end
    for _, k in ipairs({ "fxRotate", "fxBob", "fxPulse", "fxFlicker", "fxSparkPulse", "fxRimPulse" }) do st[k] = nil end
    assert(ns.L.EFFECTS.fxRimPulse and ns.L.TIP_EFFECTS.fxTickFlash, "Effekt-Texte übersetzt")
end

-- Übersetzung: alle Schlüssel der englischen Tabelle müssen auch in der aktiven Sprache existieren
print("Sprache", GetLocale(), "Thema angel =", ns.themes.angel.name, "| Symbol skull =", ns.shapeNames.skull)
assert(ns.L.H_THEME ~= "H_THEME" and ns.L.COLORS.ring and ns.L.MODULES.rim, "Übersetzung fehlt")
print("ALLES OK")

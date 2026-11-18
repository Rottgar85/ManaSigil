-- ManaSigil – Kern: Namespace, Datenbank, Events, Slash-Befehle
local addonName, ns = ...
local L = ns.L

ns.name  = addonName
ns.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
ns.MANA  = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

local DB_VERSION = 4

-- Standardwerte (pro Charakter gespeichert)
ns.defaults = {
    enabled    = true,      -- Anzeige an/aus (Minimap-Linksklick)
    minimap    = { hide = false, angle = 215 }, -- Minimap-Button
    point      = { "CENTER", "UIParent", "CENTER", 0, -160 },
    mode       = "ring",    -- ring = Kreis, pie = Torte, bar = Balken
    size       = 120,       -- Grundgröße in Pixeln
    scale      = 1.0,       -- (veraltet, wird in "size" übernommen)
    alpha      = 1.0,
    locked     = false,
    theme      = "auto",    -- "auto" = nach Klasse, sonst Themen-Schlüssel
    decor      = "theme",   -- "theme" = wie Thema, "none" = keine, sonst Themen-Schlüssel
    decorOff   = {},        -- einzeln ausgeblendete Deko-Teile, z. B. { halo = true }
    textMode   = "percent", -- percent | value | both | none
    hideWhenFull = false,   -- außerhalb des Kampfes bei vollem Mana ausblenden
    onlyManaClasses = true, -- bei Klassen ohne Mana nicht anzeigen
    modules = {
        ring       = true,  -- Mana-Anzeige (Ring / Torte / Balken)
        fsr        = true,  -- 5-Sekunden-Regel
        ticks      = true,  -- Mana-Tick-Timer (2 s)
        spark      = true,  -- Leuchtfunke am Ende der Mana-Anzeige
        decor      = true,  -- Themen-Dekoration (Flügel, Hörner ...)
        text       = true,  -- Zahlen
        background = true,  -- Hintergrund
        rim        = true,  -- Rand um den Ring
        animations = true,  -- Rotation / Schweben / Pulsieren
        fallback   = true,  -- Ersatzbalken, falls das Spiel Manawerte verbirgt
    },
    style = {
        outerStyle  = "symbols", -- symbols = einzelne Symbole, solid = durchgehender Kreis
        innerStyle  = "symbols",
        outerShape  = "theme",   -- "theme" oder ein Eintrag aus ns.shapeOrder
        innerShape  = "theme",
        outerCount  = 48,
        innerCount  = 32,
        outerSize   = 1.0,       -- Symbolgröße / Kreisdicke (Faktor)
        innerSize   = 1.0,
        outerRadius = 0.42,
        innerRadius = 0.31,
        -- Laufrichtung im Kreis/in der Torte: cw | ccw (im/gegen den Uhrzeigersinn),
        -- up (von unten nach oben) | down (von oben nach unten)
        outerDir    = "cw",
        innerDir    = "cw",
        -- Laufrichtung der Balken: forward (links→rechts bzw. unten→oben) | reverse
        barDir      = "forward",
        innerBarDir = "forward",
        pieStyle    = "smooth",  -- Torte: smooth = glatt, segments = in Stücken (Ticks)
        pieSegments = 12,
        fsrFill     = "drain",   -- 5-Sek.-Regel: drain = leert sich, fill = füllt sich
        tickFill    = "fill",    -- Tick-Timer: fill = füllt sich bis zum Tick, drain = leert sich
        innerHideIdle = true,    -- innerer Ring bei vollem Mana ausblenden
        rotateSymbols = false,   -- eckige Symbole zeigen nach außen
        emptyAlpha  = 0.45,      -- Deckkraft des leeren Teils
        bgShape     = "disc",    -- disc | soft | ring
        bgSize      = 1.0,
        bgAlpha     = 0.85,
        rimSize     = 1.0,
        rimAlpha    = 0.55,
        rimFSR      = true,      -- Rand leuchtet während der 5-Sek.-Regel
        barOrientation = "horizontal", -- Balken: horizontal | vertical
        barWidth    = 1.6,       -- Balken: Breite und Höhe (relativ zur Grundgröße)
        barHeight   = 0.2,
        barTexture  = "smooth",  -- smooth | flat | blizzard
        mp5Mode     = "current", -- off | current | both
        textScale   = 1.0,
        decorScale  = 1.0,
        sparkSize   = 1.0,
        -- Farbverlauf der Zahlen: fixed = feste Textfarbe, gradient = grün -> gelb -> rot
        textColorMode = "gradient",
        gradMidPct    = 50,      -- bei diesem Füllstand (%) ist die Farbe gelb
        -- Farben der beiden Leisten (unabhängig von den Zahlen)
        manaColorMode = "fixed",   -- Mana-Leiste/-Ring: fixed = Farbe "Mana-Ring", gradient = eigener Verlauf
        manaGradMid   = 50,
        timerColorMode = "fixed",  -- Tick-/5-Sek.-Leiste: fixed = Farben "Mana-Tick"/"5-Sek.-Regel", gradient = Verlauf
        timerGradMid  = 50,
        -- Warnung bei wenig Mana
        warnEnabled   = true,
        warnUnit      = "percent", -- percent | mana
        warnValue     = 20,        -- Schwelle (in % oder Mana-Punkten)
        warnBlink     = "text",    -- off | text | all
        warnSound     = "raid",    -- off oder ein Schlüssel aus ns.warnSounds
        warnRepeat    = 0,         -- Ton alle x Sekunden wiederholen (0 = nur einmal)
        warnCombatOnly = false,    -- nur im Kampf warnen
    },
    colors = {},            -- eigene Farben (siehe ns.colorKeys)
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

-- Alte Einstellungen auf den aktuellen Stand bringen
local function Migrate(db)
    local v = db.dbVersion or 1
    if v < 2 then
        db.style.rotateSymbols = false                -- Drehen erzeugte "Halbkreise"
        if db.scale and db.scale ~= 1 then            -- Skalierung in die Grundgröße übernehmen
            db.size = math.max(60, math.min(300, math.floor(db.size * db.scale + 0.5)))
        end
        db.scale = 1
    end
    if v < 3 then
        local s = db.style
        -- Richtung: aus true/false wird cw/ccw bzw. forward/reverse
        if s.outerClockwise ~= nil then
            s.outerDir = s.outerClockwise and "cw" or "ccw"
            s.barDir = s.outerClockwise and "forward" or "reverse"
        end
        if s.innerClockwise ~= nil then
            s.innerDir = s.innerClockwise and "cw" or "ccw"
            s.innerBarDir = s.innerClockwise and "forward" or "reverse"
        end
        s.outerClockwise, s.innerClockwise = nil, nil
        -- Balkenmaße sind jetzt direkte Faktoren der Grundgröße (vorher 1.6 bzw. 0.2 pro 1.0)
        if v == 2 then
            s.barWidth = (s.barWidth or 1) * 1.6
            s.barHeight = (s.barHeight or 1) * 0.2
        end
    end
    if v < 4 then
        -- "Mana-Anzeige auch einfärben" wird zum eigenen Verlauf der Mana-Leiste
        local s, cols = db.style, db.colors
        if s.gradientRing then s.manaColorMode = "gradient" end
        s.gradientRing = nil
        if s.gradMidPct then s.manaGradMid = s.gradMidPct end
        for _, k in ipairs({ "high", "mid", "low" }) do
            local key = "mana" .. k:sub(1, 1):upper() .. k:sub(2)
            if cols[k] and not cols[key] then cols[key] = { cols[k][1], cols[k][2], cols[k][3] } end
        end
    end
    db.dbVersion = DB_VERSION
end

-- Verfügbare Symbole für die Ringe
ns.shapeOrder = { "dot", "solid", "circle", "diamond", "star", "square", "heart", "flame", "cross", "skull", "leaf" }
ns.shapeNames = L.SHAPES
-- Runde Symbole werden nie gedreht
ns.linearDirs = { up = true, down = true, ltr = true, rtl = true }   -- Füllung wie eine Flüssigkeit
ns.roundShapes = { dot = true, solid = true, circle = true }

-- Einstellbare Farben (Reihenfolge = Optionsmenü)
ns.colorKeys = {}
for _, k in ipairs({ "ring", "empty", "fsr", "tick", "bg", "rim", "text", "spark", "decor", "high", "mid", "low" }) do
    ns.colorKeys[#ns.colorKeys + 1] = { k, L.COLORS[k] }
end

-- Hilfsfunktionen -------------------------------------------------------
function ns.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

function ns.Readable(v)
    return v ~= nil and not ns.IsSecret(v)
end

function ns.Print(msg)
    print("|cff7fb2ffMana|r|cffffd166Sigil|r: " .. tostring(msg))
end

function ns.PlayerClass()
    local _, class = UnitClass("player")
    return class
end

-- Verwendetes Thema (Farben/Grundstil)
function ns.GetThemeKey()
    local key = ns.db.theme
    if key == "auto" or not ns.themes[key] then
        key = ns.classDefaults[ns.PlayerClass() or ""] or "classic"
    end
    return key
end

function ns.GetTheme()
    return ns.themes[ns.GetThemeKey()] or ns.themes.classic
end

-- Quelle der Dekoration (kann ein anderes Thema sein)
function ns.GetDecorSource()
    local db = ns.db
    if db.decor ~= "theme" and ns.themes[db.decor] then return ns.themes[db.decor] end
    return ns.GetTheme()
end

-- Verwendete Dekoration (ohne einzeln ausgeblendete Teile)
function ns.GetDecor()
    local db = ns.db
    if not db.modules.decor or db.decor == "none" then return {} end
    local out = {}
    for _, d in ipairs(ns.GetDecorSource().decor or {}) do
        if not (d.part and db.decorOff[d.part]) then out[#out + 1] = d end
    end
    return out
end

-- Farbe: eigene Einstellung > Thema > abgeleitet > Klassik
-- Farben des Verlaufs (gelten für alle Themen)
local GREEN, YELLOW, RED = { 0.25, 0.95, 0.35 }, { 1.0, 0.85, 0.1 }, { 1.0, 0.15, 0.12 }
local GRADIENT_COLORS = {
    high = GREEN, mid = YELLOW, low = RED,                        -- Zahlen
    manaHigh = GREEN, manaMid = YELLOW, manaLow = RED,            -- Mana-Leiste
    timerHigh = GREEN, timerMid = YELLOW, timerLow = RED,         -- Tick-/5-Sek.-Leiste
}
-- Verläufe: welche drei Farben und welche "Mitte" zu welchem Teil gehören
ns.gradients = {
    text  = { "high", "mid", "low", "gradMidPct" },
    mana  = { "manaHigh", "manaMid", "manaLow", "manaGradMid" },
    timer = { "timerHigh", "timerMid", "timerLow", "timerGradMid" },
}

-- Warntöne: Schlüssel -> Sound-ID (SOUNDKIT, falls vorhanden)
ns.warnSoundOrder = { "raid", "ready", "alarm", "whisper", "ping" }
local function Kit(name, fallback) return (SOUNDKIT and SOUNDKIT[name]) or fallback end
ns.warnSounds = {
    raid    = Kit("RAID_WARNING", 8959),
    ready   = Kit("READY_CHECK", 8960),
    alarm   = Kit("ALARM_CLOCK_WARNING_3", 12889),
    whisper = Kit("TELL_MESSAGE", 3081),
    ping    = Kit("MAP_PING", 3175),
}
function ns.PlayWarnSound(key)
    local id = ns.warnSounds[key or ""]
    if id and PlaySound then pcall(PlaySound, id, "Master") end
end

function ns.GetColor(name)
    local c = ns.db.colors[name]
    if type(c) == "table" and c[1] then return c[1], c[2], c[3] end
    local t = ns.GetTheme().colors[name]
    if t then return t[1], t[2], t[3] end
    local gc = GRADIENT_COLORS[name]
    if gc then return gc[1], gc[2], gc[3] end
    if name == "empty" then
        local r, g, b = ns.GetColor("ring"); return r * 0.3, g * 0.3, b * 0.3
    elseif name == "rim" then
        return ns.GetColor("ring")
    elseif name == "spark" then
        local r, g, b = ns.GetColor("ring")
        return math.min(1, r + 0.35), math.min(1, g + 0.35), math.min(1, b + 0.35)
    end
    t = ns.themes.classic.colors[name] or { 1, 1, 1 }
    return t[1], t[2], t[3]
end

-- Stil-Wert; "theme"-Formen werden über das Thema aufgelöst
function ns.GetStyle(key)
    local v = ns.db.style[key]
    if v == nil then v = ns.defaults.style[key] end
    if v == "theme" then
        local shapes = ns.GetTheme().shapes or {}
        v = (key == "outerShape" and shapes.outer) or (key == "innerShape" and shapes.inner) or "dot"
    end
    return v
end

-- Anzeige an/aus
function ns.SetEnabled(on)
    ns.db.enabled = on and true or false
    ns.Display:UpdateVisibility()
    if ns.Minimap then ns.Minimap:Refresh() end
    if ns.Options then ns.Options:RefreshWidgets() end
    ns.Print(ns.db.enabled and L.ON or L.OFF)
end

function ns.ToggleEnabled()
    ns.SetEnabled(not ns.db.enabled)
end

-- Events ----------------------------------------------------------------
local events = CreateFrame("Frame")
ns.eventFrame = events
local handlers = {}

local function Dispatch(_, event, ...)
    local h = handlers[event]
    if h then h(...) end
end
events:SetScript("OnEvent", Dispatch)

function handlers.ADDON_LOADED(name)
    if name ~= addonName then return end
    local fresh = ManaSigilDB == nil
    ManaSigilDB = CopyDefaults(ns.defaults, ManaSigilDB or {})
    ns.db = ManaSigilDB
    if fresh then ns.db.dbVersion = DB_VERSION end   -- neue Charaktere brauchen keine Umstellung
    Migrate(ns.db)
    events:UnregisterEvent("ADDON_LOADED")
end

-- Fehler eines Teils melden, ohne den Rest des Addons anzuhalten
function ns.ReportError(where, err)
    local msg = "ManaSigil " .. (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version") or "")
        .. " [" .. where .. "]: " .. tostring(err)
    ns.Print("|cffff6060" .. msg .. "|r")
    ns.errors = ns.errors or {}
    table.insert(ns.errors, 1, msg)
    ns.errors[4] = nil
    local handler = geterrorhandler and geterrorhandler()
    if handler then pcall(handler, msg) end
end

local function Safe(where, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.ReportError(where, err) end
    return ok
end

function handlers.PLAYER_LOGIN()
    -- Events zuerst: die Mana-/Tick-Erkennung läuft auch, wenn ein anderer Teil scheitert
    events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    Safe("Tracker", ns.Tracker.Init, ns.Tracker)
    Safe("Display", ns.Display.Build, ns.Display)
    Safe("Options", ns.Options.Build, ns.Options)
    Safe("Minimap", ns.Minimap.Build, ns.Minimap)
    Safe("Refresh", ns.Display.Refresh, ns.Display)

    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
end

function handlers.PLAYER_ENTERING_WORLD()
    ns.Tracker:Reset()
    ns.Display:Refresh()
end

function handlers.PLAYER_REGEN_DISABLED()
    ns.Display:UpdateVisibility()
end

function handlers.PLAYER_REGEN_ENABLED()
    ns.Display:UpdateVisibility()
    if ns.pendingOptions then
        ns.pendingOptions = nil
        ns.Options:Open()
    end
end

function handlers.UNIT_POWER_UPDATE(unit, powerToken)
    if powerToken == "MANA" then ns.Tracker:OnPower("UNIT_POWER_UPDATE") end
end
function handlers.UNIT_POWER_FREQUENT(unit, powerToken)
    if powerToken == "MANA" then ns.Tracker:OnPower("UNIT_POWER_FREQUENT") end
end

function handlers.UNIT_MAXPOWER()
    ns.Tracker:OnPower()
    ns.Display:BuildCurves()   -- Warnschwelle in Manapunkten hängt vom Maximum ab
    ns.Display:UpdateVisibility()
end

function handlers.UNIT_DISPLAYPOWER()
    ns.Display:UpdateVisibility()
end

function handlers.UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
    ns.Tracker:OnSpellCast(spellID)
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")

-- Slash-Befehle -----------------------------------------------------------
local function ListThemes()
    local parts = {}
    for _, key in ipairs(ns.themeOrder) do
        parts[#parts + 1] = key .. " (" .. ns.themes[key].name .. ")"
    end
    ns.Print(string.format(L.THEMES_LIST, "auto, " .. table.concat(parts, ", ")))
end

-- Diagnose: zeigt, ob das Spiel Manawerte verbirgt, und die Regenerationswerte
local function Debug()
    local cur, maxMana = ns.Tracker:GetMana()
    local function show(v)
        if v == nil then return "nil" end
        if ns.IsSecret(v) then return "|cffff6060secret|r" end
        return tostring(v)
    end
    local base, casting = ns.Tracker:GetMP5()
    ns.Print(string.format("mana=%s/%s  mp5=%s/%s  fsr=%s  tick=%s  mode=%s  issecretvalue=%s",
        show(cur), show(maxMana), show(base), show(casting),
        ns.Tracker:InFSR() and "yes" or "no", show(ns.Tracker.tickAmount), ns.db.mode,
        issecretvalue and "yes" or "no"))
    local gaps = {}
    for _, g in ipairs(ns.Tracker.gaps or {}) do gaps[#gaps + 1] = string.format("%.2f", g) end
    ns.Print("tick gaps: " .. (#gaps > 0 and table.concat(gaps, " ") or "-")
        .. "  secret=" .. (ns.Tracker.secret and "yes" or "no"))
    local s = ns.Tracker.stats
    if s then
        local ug = {}
        for _, g in ipairs(s.gaps) do ug[#ug + 1] = string.format("%.2f", g) end
        ns.Print(string.format("events (%.0fs): update=%d frequent=%d  update gaps: %s",
            GetTime() - s.start, s.update, s.frequent, #ug > 0 and table.concat(ug, " ") or "-"))
    end
    local st = ns.db.style
    ns.Print(string.format("version=%s  text=%s  color=%s  warn=%s %s %s  combatOnly=%s",
        C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version") or "?",
        tostring(ns.db.textMode), tostring(ns.GetStyle("textColorMode")), tostring(ns.GetStyle("warnEnabled")),
        tostring(ns.GetStyle("warnValue")), tostring(ns.GetStyle("warnUnit")), tostring(ns.GetStyle("warnCombatOnly"))))
    ns.Print("selftest: " .. ns.Display:SelfTest())
    for _, e in ipairs(ns.errors or {}) do ns.Print("|cffff6060error: " .. e .. "|r") end
    if not ns.errors then ns.Print("errors: -") end
end

SLASH_MANASIGIL1 = "/manasigil"
SLASH_MANASIGIL2 = "/msig"
SlashCmdList.MANASIGIL = function(msg)
    local cmd, arg = strsplit(" ", strtrim(msg or ""):lower(), 2)
    if cmd == "" or cmd == "options" or cmd == "config" then
        ns.Options:Open()
    elseif cmd == "toggle" or cmd == "on" or cmd == "off" then
        if cmd == "toggle" then ns.ToggleEnabled() else ns.SetEnabled(cmd == "on") end
    elseif cmd == "minimap" then
        ns.db.minimap.hide = not ns.db.minimap.hide
        ns.Minimap:Refresh(); ns.Options:RefreshWidgets()
        ns.Print(ns.db.minimap.hide and L.MINIMAP_HIDDEN or L.MINIMAP_SHOWN)
    elseif cmd == "mode" then
        if arg == "ring" or arg == "pie" or arg == "bar" then
            ns.db.mode = arg; ns.Display:Refresh(); ns.Options:RefreshWidgets()
            ns.Print(string.format(L.MODE_SET, L.MODES[arg]))
        else
            ns.Print("/msig mode ring | pie | bar")
        end
    elseif cmd == "lock" then
        ns.db.locked = true;  ns.Display:Refresh(); ns.Print(L.LOCKED)
    elseif cmd == "unlock" then
        ns.db.locked = false; ns.Display:Refresh(); ns.Print(L.UNLOCKED)
    elseif cmd == "reset" then
        ns.db.point = CopyDefaults(ns.defaults.point, {})
        ns.Display:Refresh(); ns.Print(L.POS_RESET)
    elseif cmd == "theme" then
        if arg and (arg == "auto" or ns.themes[arg]) then
            ns.db.theme = arg; ns.Display:Refresh(); ns.Options:RefreshWidgets()
            ns.Print(string.format(L.THEME_SET, arg == "auto" and L.AUTO or ns.themes[arg].name))
        else
            ListThemes()
        end
    elseif cmd == "test" then
        ns.Tracker:StartFSR(); ns.Display:Show(true); ns.Print(L.TEST_STARTED)
    elseif cmd == "debug" then
        Debug()
    else
        ns.Print(L.HELP)
        ListThemes()
    end
end

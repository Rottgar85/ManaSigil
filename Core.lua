-- ManaSigil – Kern: Namespace, Datenbank, Events, Slash-Befehle
local addonName, ns = ...
local L = ns.L

ns.name  = addonName
ns.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
ns.MANA  = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

local DB_VERSION = 2

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
        outerClockwise = true,   -- Laufrichtung der Mana-Anzeige
        innerClockwise = true,   -- Laufrichtung des 5-Sek.-/Tick-Rings
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
        barWidth    = 1.0,       -- Balken-Modus
        barHeight   = 1.0,
        barTexture  = "smooth",  -- smooth | flat | blizzard
        mp5Mode     = "current", -- off | current | both
        textScale   = 1.0,
        decorScale  = 1.0,
        sparkSize   = 1.0,
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
    db.dbVersion = DB_VERSION
end

-- Verfügbare Symbole für die Ringe
ns.shapeOrder = { "dot", "solid", "circle", "diamond", "star", "square", "heart", "flame", "cross", "skull", "leaf" }
ns.shapeNames = L.SHAPES
-- Runde Symbole werden nie gedreht
ns.roundShapes = { dot = true, solid = true, circle = true }

-- Einstellbare Farben (Reihenfolge = Optionsmenü)
ns.colorKeys = {}
for _, k in ipairs({ "ring", "empty", "fsr", "tick", "bg", "rim", "text", "spark", "decor" }) do
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
function ns.GetColor(name)
    local c = ns.db.colors[name]
    if type(c) == "table" and c[1] then return c[1], c[2], c[3] end
    local t = ns.GetTheme().colors[name]
    if t then return t[1], t[2], t[3] end
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
    ManaSigilDB = CopyDefaults(ns.defaults, ManaSigilDB or {})
    ns.db = ManaSigilDB
    Migrate(ns.db)
    events:UnregisterEvent("ADDON_LOADED")
end

function handlers.PLAYER_LOGIN()
    ns.Display:Build()
    ns.Tracker:Init()
    ns.Options:Build()
    ns.Minimap:Build()
    ns.Display:Refresh()

    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
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
    if powerToken == "MANA" then ns.Tracker:OnPower() end
end
handlers.UNIT_POWER_FREQUENT = handlers.UNIT_POWER_UPDATE

function handlers.UNIT_MAXPOWER()
    ns.Tracker:OnPower()
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

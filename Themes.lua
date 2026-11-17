-- ManaSigil – Themen
-- Ein Thema besteht aus Farben und einer Liste von Dekorations-Elementen.
-- Eigene Themen: einfach unten mit Register("schluessel", { ... }) ergänzen.
--
-- Felder eines Dekorations-Elements (Größen/Positionen relativ zur Ringgröße):
-- Optional: shapes = { outer = "flame", inner = "skull" } (Symbole der Ringe, siehe ns.shapeOrder)
--
--   tex        Grafik aus Media\ (wing, horn, sigil, runes, rays, leaf, bolt, feather, glow, rim, disc, sym_*)
--   x, y       Versatz vom Mittelpunkt (1.0 = eine Ringgröße)
--   w, h       Breite/Höhe (1.0 = eine Ringgröße)
--   mirror     true = horizontal spiegeln (rechte Seite)
--   color      eigene Farbe {r,g,b}; sonst die Dekorationsfarbe des Themas
--   alpha      Grund-Deckkraft (Standard 1)
--   blend      "BLEND" (Standard) oder "ADD" (leuchtend)
--   front      true = vor dem Ring statt dahinter
--   rotate     Drehgeschwindigkeit in Bogenmaß/Sekunde (negativ = gegen den Uhrzeigersinn)
--   bob        Schwebe-Amplitude (relativ), bobSpeed = Geschwindigkeit
--   pulse      Puls-Amplitude der Deckkraft, pulseSpeed = Geschwindigkeit
--   flicker    true = unruhiges Flackern (z. B. Blitze)
local _, ns = ...

ns.themes = {}
ns.themeOrder = {}

-- Standard-Symbole je Thema (überschreibbar im Optionsmenü)
local SHAPES = {
    classic = { outer = "dot",     inner = "dot" },
    angel   = { outer = "dot",     inner = "star" },
    shadow  = { outer = "dot",     inner = "diamond" },
    demon   = { outer = "flame",   inner = "skull" },
    arcane  = { outer = "diamond", inner = "dot" },
    nature  = { outer = "dot",     inner = "leaf" },
    holy    = { outer = "dot",     inner = "cross" },
    storm   = { outer = "diamond", inner = "dot" },
    wild    = { outer = "dot",     inner = "diamond" },
}

local function Register(key, def)
    def.key = key
    def.decor = def.decor or {}
    def.shapes = def.shapes or SHAPES[key] or { outer = "dot", inner = "dot" }
    -- übersetzter Name aus Locale.lua (sonst der hier angegebene)
    def.name = rawget(ns.L.THEMES, key) or def.name or key
    ns.themes[key] = def
    ns.themeOrder[#ns.themeOrder + 1] = key
end
ns.RegisterTheme = Register

-- Standard-Thema je Klasse (nur Klassen mit Mana)
ns.classDefaults = {
    PRIEST  = "angel",
    WARLOCK = "demon",
    MAGE    = "arcane",
    DRUID   = "nature",
    PALADIN = "holy",
    SHAMAN  = "storm",
    HUNTER  = "wild",
}

Register("classic", {
    name = "Klassisch",
    colors = { ring = { 0.25, 0.55, 1.00 }, fsr = { 1.00, 0.80, 0.20 }, tick = { 0.45, 0.90, 1.00 },
               decor = { 1, 1, 1 }, bg = { 0.02, 0.03, 0.08 }, text = { 1, 1, 1 } },
    decor = {},
})

Register("angel", {
    name = "Engelsflügel",
    colors = { ring = { 0.50, 0.78, 1.00 }, fsr = { 1.00, 0.84, 0.35 }, tick = { 1.00, 1.00, 0.85 },
               decor = { 1.00, 0.97, 0.90 }, bg = { 0.07, 0.06, 0.03 }, text = { 1.00, 0.96, 0.85 } },
    decor = {
        { tex = "glow", x = 0, y = 0, w = 1.6, h = 1.6, blend = "ADD", color = { 1, 0.88, 0.55 }, alpha = 0.35, pulse = 0.15, pulseSpeed = 1.2 },
        { tex = "wing", x = -0.60, y = 0.10, w = 1.25, h = 1.25, bob = 0.03, bobSpeed = 1.6 },
        { tex = "wing", x =  0.60, y = 0.10, w = 1.25, h = 1.25, mirror = true, bob = 0.03, bobSpeed = 1.6 },
        { tex = "rim",  x = 0, y = 0.64, w = 0.55, h = 0.15, blend = "ADD", color = { 1, 0.85, 0.40 }, alpha = 0.9, pulse = 0.25, pulseSpeed = 2, front = true },
    },
})

Register("shadow", {
    name = "Schattenschwingen",
    colors = { ring = { 0.62, 0.35, 1.00 }, fsr = { 0.95, 0.40, 0.85 }, tick = { 0.75, 0.65, 1.00 },
               decor = { 0.42, 0.25, 0.62 }, bg = { 0.04, 0.01, 0.07 }, text = { 0.92, 0.85, 1.00 } },
    decor = {
        { tex = "glow", x = 0, y = 0, w = 1.7, h = 1.7, blend = "ADD", color = { 0.45, 0.15, 0.75 }, alpha = 0.45, pulse = 0.2, pulseSpeed = 0.9 },
        { tex = "wing", x = -0.60, y = 0.08, w = 1.30, h = 1.30, bob = 0.02, bobSpeed = 1.1 },
        { tex = "wing", x =  0.60, y = 0.08, w = 1.30, h = 1.30, mirror = true, bob = 0.02, bobSpeed = 1.1 },
        { tex = "runes", x = 0, y = 0, w = 1.15, h = 1.15, blend = "ADD", color = { 0.6, 0.3, 1 }, alpha = 0.35, rotate = -0.1 },
    },
})

Register("demon", {
    name = "Dämonenpakt",
    colors = { ring = { 0.55, 0.30, 0.95 }, fsr = { 0.45, 1.00, 0.25 }, tick = { 0.70, 1.00, 0.45 },
               decor = { 0.55, 0.42, 0.40 }, bg = { 0.05, 0.01, 0.03 }, text = { 0.80, 1.00, 0.70 } },
    decor = {
        { tex = "sigil", x = 0, y = 0, w = 1.45, h = 1.45, blend = "ADD", color = { 0.35, 1.00, 0.20 }, alpha = 0.55, rotate = -0.18, pulse = 0.2, pulseSpeed = 1.5 },
        { tex = "glow",  x = 0, y = 0, w = 1.7,  h = 1.7,  blend = "ADD", color = { 0.30, 0.85, 0.10 }, alpha = 0.30, pulse = 0.15, pulseSpeed = 0.8 },
        { tex = "horn",  x = -0.36, y = 0.46, w = 0.62, h = 0.62 },
        { tex = "horn",  x =  0.36, y = 0.46, w = 0.62, h = 0.62, mirror = true },
    },
})

Register("arcane", {
    name = "Arkane Runen",
    colors = { ring = { 0.35, 0.70, 1.00 }, fsr = { 1.00, 0.55, 0.95 }, tick = { 0.70, 0.95, 1.00 },
               decor = { 0.55, 0.80, 1.00 }, bg = { 0.02, 0.03, 0.10 }, text = { 0.85, 0.95, 1.00 } },
    decor = {
        { tex = "glow",  x = 0, y = 0, w = 1.6,  h = 1.6,  blend = "ADD", color = { 0.3, 0.5, 1 }, alpha = 0.35, pulse = 0.15 },
        { tex = "runes", x = 0, y = 0, w = 1.50, h = 1.50, blend = "ADD", alpha = 0.75, rotate = 0.14 },
        { tex = "runes", x = 0, y = 0, w = 1.22, h = 1.22, blend = "ADD", color = { 0.9, 0.5, 1 }, alpha = 0.35, rotate = -0.22 },
    },
})

Register("nature", {
    name = "Hain der Natur",
    colors = { ring = { 0.30, 0.65, 1.00 }, fsr = { 1.00, 0.70, 0.20 }, tick = { 0.55, 1.00, 0.45 },
               decor = { 0.40, 0.80, 0.30 }, bg = { 0.02, 0.06, 0.02 }, text = { 0.90, 1.00, 0.85 } },
    decor = {
        { tex = "glow", x = 0, y = 0, w = 1.5, h = 1.5, blend = "ADD", color = { 0.3, 0.9, 0.3 }, alpha = 0.25, pulse = 0.15 },
        { tex = "leaf", x = -0.50, y = -0.08, w = 0.70, h = 0.70, bob = 0.02, bobSpeed = 1.3 },
        { tex = "leaf", x =  0.50, y = -0.08, w = 0.70, h = 0.70, mirror = true, bob = 0.02, bobSpeed = 1.3 },
        { tex = "leaf", x = -0.36, y =  0.36, w = 0.48, h = 0.48, color = { 0.55, 0.85, 0.30 }, bob = 0.02, bobSpeed = 1.7 },
        { tex = "leaf", x =  0.36, y =  0.36, w = 0.48, h = 0.48, color = { 0.55, 0.85, 0.30 }, mirror = true, bob = 0.02, bobSpeed = 1.7 },
    },
})

Register("holy", {
    name = "Heiliges Licht",
    colors = { ring = { 0.40, 0.70, 1.00 }, fsr = { 1.00, 0.85, 0.30 }, tick = { 1.00, 0.95, 0.65 },
               decor = { 1.00, 0.85, 0.40 }, bg = { 0.07, 0.05, 0.01 }, text = { 1.00, 0.95, 0.75 } },
    decor = {
        { tex = "rays", x = 0, y = 0, w = 1.9, h = 1.9, blend = "ADD", alpha = 0.65, rotate = 0.08, pulse = 0.2, pulseSpeed = 1 },
        { tex = "wing", x = -0.48, y = 0.12, w = 0.85, h = 0.85, color = { 1, 0.92, 0.70 } },
        { tex = "wing", x =  0.48, y = 0.12, w = 0.85, h = 0.85, color = { 1, 0.92, 0.70 }, mirror = true },
    },
})

Register("storm", {
    name = "Sturmrufer",
    colors = { ring = { 0.25, 0.55, 1.00 }, fsr = { 1.00, 0.75, 0.25 }, tick = { 0.55, 0.95, 1.00 },
               decor = { 0.60, 0.85, 1.00 }, bg = { 0.01, 0.03, 0.07 }, text = { 0.85, 0.95, 1.00 } },
    decor = {
        { tex = "glow", x = 0, y = 0, w = 1.6, h = 1.6, blend = "ADD", color = { 0.2, 0.5, 1 }, alpha = 0.35, pulse = 0.2, pulseSpeed = 2 },
        { tex = "bolt", x = -0.52, y = 0.05, w = 0.65, h = 0.65, blend = "ADD", flicker = true },
        { tex = "bolt", x =  0.52, y = 0.05, w = 0.65, h = 0.65, blend = "ADD", mirror = true, flicker = true },
    },
})

Register("wild", {
    name = "Wildnis",
    colors = { ring = { 0.30, 0.62, 1.00 }, fsr = { 1.00, 0.65, 0.25 }, tick = { 0.65, 1.00, 0.55 },
               decor = { 0.80, 0.60, 0.40 }, bg = { 0.05, 0.03, 0.01 }, text = { 1.00, 0.95, 0.85 } },
    decor = {
        { tex = "feather", x = -0.50, y = -0.12, w = 0.75, h = 0.75, bob = 0.02, bobSpeed = 1.2 },
        { tex = "feather", x =  0.50, y = -0.12, w = 0.75, h = 0.75, mirror = true, bob = 0.02, bobSpeed = 1.2 },
        { tex = "feather", x = -0.40, y = -0.30, w = 0.55, h = 0.55, color = { 0.55, 0.40, 0.25 }, bob = 0.02, bobSpeed = 1.5 },
        { tex = "feather", x =  0.40, y = -0.30, w = 0.55, h = 0.55, color = { 0.55, 0.40, 0.25 }, mirror = true, bob = 0.02, bobSpeed = 1.5 },
    },
})

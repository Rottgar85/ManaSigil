-- ManaSigil – Anzeige: Kreis / Torte / Balken, 5-Sek.-Regel, Ticks, MP5, Hintergrund, Deko
local _, ns = ...

local D = {}
ns.Display = D

local UPDATE_RATE = 1 / 40          -- max. 40 Aktualisierungen pro Sekunde
local MAX_PIPS = 240                -- Obergrenze pro Ring
local PIE_N = 90
local MAX_SEGMENTS = 1000
local MAX_GAP_LINES = 72                    -- Tortenstücke (passend zur Grafik "wedge")
local TWO_PI = math.pi * 2
local sin, cos, floor, max, min = math.sin, math.cos, math.floor, math.max, math.min

local BG_TEX = { disc = "disc", soft = "glow", ring = "rim" }
local BAR_TEX = {
    smooth   = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    flat     = "Interface\\Buttons\\WHITE8X8",
    blizzard = "Interface\\TargetingFrame\\UI-StatusBar",
}

local function Media(name) return ns.MEDIA .. name end
for _, k in ipairs(ns.barTextureOrder or {}) do
    if not BAR_TEX[k] then BAR_TEX[k] = Media("bar_" .. k) end   -- eigene Balkentexturen
end
local function st(key) return ns.GetStyle(key) end

local function Hex(r, g, b)
    return string.format("|cff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

-- Textur um ihren Mittelpunkt drehen (über Texturkoordinaten statt SetRotation,
-- das im Client Symbole abschneiden kann). a = Winkel gegen den Uhrzeigersinn.
local function RotTexCoord(t, a)
    if a == 0 then t:SetTexCoord(0, 1, 0, 1); return end
    local c, s = cos(a), sin(a)
    local function tc(x, y)
        local rx, ry = x * c + y * s, -x * s + y * c
        return 0.5 + rx, 0.5 - ry
    end
    local ulx, uly = tc(-0.5, 0.5)
    local llx, lly = tc(-0.5, -0.5)
    local urx, ury = tc(0.5, 0.5)
    local lrx, lry = tc(0.5, -0.5)
    t:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end
ns.RotTexCoord = RotTexCoord

-- Ringe ------------------------------------------------------------------------
-- Ein Ring besteht aus vielen kleinen Texturen in einem eigenen Frame:
--   symbols = einzelne Symbole, solid = überlappende Kugeln (durchgehender Kreis),
--   pie     = Tortenstücke vom Mittelpunkt aus.
-- Ankerpunkte der verschiebbaren Teile werden hier mitgeschrieben. Die Sandbox liest
-- sie von hier, nicht vom Spiel: das hält die Ankerpunkte von Texten mit geheimem
-- Inhalt (z. B. dem Manawert) selbst geheim.
local pins = setmetatable({}, { __mode = "k" })
local function Pin(r, point, rel, relPoint, x, y)
    local list = pins[r]
    if not list then list = {}; pins[r] = list end
    list[#list + 1] = { point, rel, relPoint or point, x or 0, y or 0 }
    r:SetPoint(point, rel, relPoint or point, x or 0, y or 0)
end
local function Unpin(r)
    r:ClearAllPoints()
    pins[r] = {}
end
local function PinFill(r, parent)
    Unpin(r)
    Pin(r, "TOPLEFT", parent, "TOPLEFT", 0, 0)
    Pin(r, "BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
end
function D:GetPins(r) return pins[r] end

local function NewRing(parent)
    local f = CreateFrame("Frame", nil, parent)
    PinFill(f, parent)
    return { frame = f, pips = {}, n = 0, cache = {} }
end

local function PipAngle(i, n, ccw)
    local frac = (i - 0.5) / n
    if ccw then return math.pi / 2 + frac * TWO_PI end
    return math.pi / 2 - frac * TWO_PI
end

-- dir: cw / ccw = Füllung rundherum, up / down = Füllung nach Höhe (wie Flüssigkeit)
local function SetupRing(ring, kind, shape, count, size, radius, rotate, dir)
    local n, tex
    if kind == "solid" then
        tex = "sym_solid"
        n = min(MAX_PIPS, max(12, math.ceil(TWO_PI * radius / max(1, size * 0.35))))
        rotate = false
    elseif kind == "pie" then
        tex = "wedge"
        n = PIE_N
        rotate = true
    else
        tex = "sym_" .. shape
        n = min(MAX_PIPS, max(3, floor(count + 0.5)))
        if ns.roundShapes[shape] then rotate = false end
    end
    ring.n, ring.kind, ring.radius, ring.dir = n, kind, radius, dir
    ring.cache.key = nil
    -- Reihenfolge der Füllung: ov[i] = Position (0..1), w = Breite eines Teils
    ring.ov = ring.ov or {}
    local linear = ns.linearDirs[dir]
    ring.w = linear and max(1 / n * 2, size / max(1, radius * 2)) or 1 / n
    for i = 1, n do
        local t = ring.pips[i]
        if not t then
            t = ring.frame:CreateTexture(nil, "ARTWORK")
            ring.pips[i] = t
        end
        local a = PipAngle(i, n, dir == "ccw")
        if dir == "up" then
            ring.ov[i] = (1 + sin(a)) / 2          -- unten zuerst
        elseif dir == "down" then
            ring.ov[i] = (1 - sin(a)) / 2          -- oben zuerst
        elseif dir == "ltr" then
            ring.ov[i] = (1 + cos(a)) / 2          -- links zuerst
        elseif dir == "rtl" then
            ring.ov[i] = (1 - cos(a)) / 2          -- rechts zuerst
        else
            ring.ov[i] = (i - 0.5) / n
        end
        t:SetTexture(Media(tex))
        t:ClearAllPoints()
        if kind == "pie" then
            t:SetSize(radius * 2, radius * 2)
            t:SetPoint("CENTER", ring.frame, "CENTER", 0, 0)
        else
            t:SetSize(size, size)
            t:SetPoint("CENTER", ring.frame, "CENTER", cos(a) * radius, sin(a) * radius)
        end
        RotTexCoord(t, rotate and (a - math.pi / 2) or 0)
        t:Show()
    end
    for i = n + 1, #ring.pips do ring.pips[i]:Hide() end
    ring.frame:Show()
end

local function HideRing(ring)
    ring.frame:Hide()
    ring.n = 0
end

-- Füllstand anzeigen. Gefüllt = (r,g,b), leer = (er,eg,eb) mit Deckkraft ea.
-- Bei Kreis/Torte wird die Leerfarbe deckend mit dem Hintergrund gemischt,
-- damit überlappende Teile keine dunklen Flecken bilden.
-- cut (optional): Manavorschau – Teile oberhalb von cut (bis frac) bekommen die Farbe (cr,cg,cb).
local function FillRing(ring, frac, r, g, b, er, eg, eb, ea, mixR, mixG, mixB, cut, cr, cg, cb)
    local n = ring.n
    if n == 0 then return end
    local key = floor(frac * n * 16 + 0.5)
    local ckey = cut and floor(cut * n * 16 + 0.5) or -1
    local c = ring.cache
    if c.key == key and c.r == r and c.g == g and c.b == b and c.er == er and c.ea == ea and c.mr == mixR
        and c.ck == ckey and c.cr == cr and c.cg == cg and c.cb == cb then return end
    c.key, c.r, c.g, c.b, c.er, c.ea, c.mr = key, r, g, b, er, ea, mixR
    c.ck, c.cr, c.cg, c.cb = ckey, cr, cg, cb

    local opaque = ring.kind ~= "symbols"
    if opaque then
        local mr, mg, mb = mixR or 0, mixG or 0, mixB or 0
        er, eg, eb = mr + (er - mr) * ea, mg + (eg - mg) * ea, mb + (eb - mb) * ea
        ea = 1
    end
    local w = ring.w or (1 / n)
    for i = 1, n do
        -- Füllgrad dieses Teils: 0 = leer, 1 = voll, dazwischen weicher Übergang
        local v = (frac - (ring.ov[i] - w / 2)) / w
        local t = ring.pips[i]
        local fr, fg, fb = r, g, b
        if cut and (cut - (ring.ov[i] - w / 2)) / w < 0.5 then fr, fg, fb = cr, cg, cb end
        if v >= 1 then
            t:SetVertexColor(fr, fg, fb, 1)
        elseif v > 0 then
            if opaque then
                t:SetVertexColor(er + (fr - er) * v, eg + (fg - eg) * v, eb + (fb - eb) * v, 1)
            else
                t:SetVertexColor(fr, fg, fb, ea + (1 - ea) * v)
            end
        else
            t:SetVertexColor(er, eg, eb, ea)
        end
    end
end

local function SetFontSize(fs, size)
    fs:SetFont(STANDARD_TEXT_FONT, max(6, floor(size + 0.5)), "OUTLINE")
end

local function ShortNumber(v)
    if v >= 10000 then return string.format("%.1fk", v / 1000) end
    return tostring(floor(v + 0.5))
end

-- Aufbau -----------------------------------------------------------------------
function D:Build()
    local f = CreateFrame("Frame", nil, UIParent)
    self.frame = f
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s) if not ns.db.locked then s:StartMoving() end end)
    f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); D:SavePosition() end)
    f:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.Options:Open() end
    end)
    f:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine("ManaSigil", 0.5, 0.75, 1)
        GameTooltip:AddLine(ns.L.TT_DRAG, 1, 1, 1)
        GameTooltip:AddLine(ns.L.TT_RCLICK, 1, 1, 1)
        GameTooltip:AddLine(ns.L.TT_LOCK, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local lvl = f:GetFrameLevel()
    self.back  = CreateFrame("Frame", nil, f); self.back:SetAllPoints();  self.back:SetFrameLevel(lvl + 1)
    self.main  = CreateFrame("Frame", nil, f); self.main:SetAllPoints();  self.main:SetFrameLevel(lvl + 2)
    self.front = CreateFrame("Frame", nil, f); self.front:SetAllPoints(); self.front:SetFrameLevel(lvl + 6)

    local m = self.main
    self.bg = m:CreateTexture(nil, "BACKGROUND")
    Pin(self.bg, "CENTER", m, "CENTER", 0, 0)
    self.rim = m:CreateTexture(nil, "BORDER")
    self.rim:SetTexture(Media("rim"))
    Pin(self.rim, "CENTER", m, "CENTER", 0, 0)

    self.outer = NewRing(m)
    self.inner = NewRing(m)
    self.outer.frame:SetFrameLevel(lvl + 3)
    self.inner.frame:SetFrameLevel(lvl + 3)

    -- Torte als Flüssigkeit (von unten/oben gefüllt)
    local pf = CreateFrame("Frame", nil, m)
    PinFill(pf, m); pf:SetFrameLevel(lvl + 3)
    self.pieFrame = pf
    self.pieEmpty = pf:CreateTexture(nil, "ARTWORK", nil, 0)
    self.pieEmpty:SetTexture(Media("filldisc"))
    self.pieCost = pf:CreateTexture(nil, "ARTWORK", nil, 1)   -- Manavorschau (Kosten des Zaubers)
    self.pieCost:SetTexture(Media("filldisc"))
    self.pieCost:Hide()
    self.pieFill = pf:CreateTexture(nil, "ARTWORK", nil, 2)
    self.pieFill:SetTexture(Media("filldisc"))
    pf:Hide()
    -- Trennlinien zwischen Tortenstücken
    local gf = CreateFrame("Frame", nil, m)
    PinFill(gf, m); gf:SetFrameLevel(lvl + 4)
    self.gapFrame = gf
    self.gaps = {}

    self.spark = self.front:CreateTexture(nil, "BACKGROUND")
    self.spark:SetTexture(Media("glow"))
    self.spark:SetBlendMode("ADD")

    self.flash = self.front:CreateTexture(nil, "BACKGROUND", nil, -1)
    self.flash:SetTexture(Media("glow"))
    self.flash:SetBlendMode("ADD")
    self.flash:SetPoint("CENTER")
    self.flash:SetAlpha(0)

    -- Ersatz-Balken, falls Manawerte im Kampf geheim sind (Kreis-/Torten-Modus)
    self.fallback = CreateFrame("StatusBar", nil, self.front)
    self.fallback:SetStatusBarTexture(BAR_TEX.blizzard)
    self.fallbackAfter = CreateFrame("StatusBar", nil, self.fallback)
    self.fallbackAfter:SetAllPoints(self.fallback)
    self.fallbackAfter:SetFrameLevel(self.fallback:GetFrameLevel() + 1)
    self.fallbackAfter:SetStatusBarTexture(BAR_TEX.blizzard)
    self.fallbackAfter:SetMinMaxValues(0, 1)
    self.fallbackAfter:Hide()
    -- nichts darf über den Rand des Ersatzbalkens hinausragen
    if self.fallback.SetClipsChildren then pcall(self.fallback.SetClipsChildren, self.fallback, true) end
    self.fallback:Hide()

    -- Balken-Modus
    local bf = CreateFrame("Frame", nil, m)
    bf:SetFrameLevel(lvl + 3)
    self.barFrame = bf
    self.barBack = bf:CreateTexture(nil, "BACKGROUND")
    self.bar = CreateFrame("StatusBar", nil, bf)
    self.barEmpty = self.bar:CreateTexture(nil, "BACKGROUND")
    self.barEmpty:SetAllPoints()
    self.barCost = self.bar:CreateTexture(nil, "OVERLAY")       -- Manavorschau (Kosten des Zaubers)
    self.barCost:SetTexture(BAR_TEX.flat)
    self.barCost:SetBlendMode("BLEND")
    self.barCost:Hide()
    -- Manavorschau: zweite Leiste über der Mana-Leiste zeigt den Stand nach dem Zauber;
    -- die Mana-Leiste darunter wird solange zum blassen Schatten (= Kosten)
    self.barAfter = CreateFrame("StatusBar", nil, self.bar)
    self.barAfter:SetAllPoints(self.bar)
    self.barAfter:SetFrameLevel(lvl + 5)
    self.barAfter:SetMinMaxValues(0, 1)
    self.barAfter:Hide()
    -- die Vorschau-Leiste bleibt im Rahmen der Mana-Leiste (alles darüber hinaus wird abgeschnitten)
    if self.bar.SetClipsChildren then pcall(self.bar.SetClipsChildren, self.bar, true) end
    self.bar2 = CreateFrame("StatusBar", nil, bf)
    self.bar2Empty = self.bar2:CreateTexture(nil, "BACKGROUND")
    self.bar2Empty:SetAllPoints()
    self.bar2:SetMinMaxValues(0, 1)
    bf:Hide()

    local fr = self.front
    self.bigText  = fr:CreateFontString(nil, "OVERLAY")
    self.valText  = fr:CreateFontString(nil, "OVERLAY")
    self.infoText = fr:CreateFontString(nil, "OVERLAY")
    self.mp5Text  = fr:CreateFontString(nil, "OVERLAY")
    self.castText = fr:CreateFontString(nil, "OVERLAY")   -- Manavorschau beim Zaubern
    -- Kästchen hinter der MP5-Zeile (folgt dem Text, auch wenn er verschoben wird)
    self.mp5Bg = fr:CreateTexture(nil, "BACKGROUND")
    self.mp5Bg:SetTexture(BAR_TEX.flat)
    self.mp5Bg:SetPoint("TOPLEFT", self.mp5Text, "TOPLEFT", -4, 2)
    self.mp5Bg:SetPoint("BOTTOMRIGHT", self.mp5Text, "BOTTOMRIGHT", 4, -2)
    self.mp5Bg:Hide()
    -- Kästchen hinter der Mana-Zahl (folgt der Zahl)
    self.pctBg = fr:CreateTexture(nil, "BACKGROUND")
    self.pctBg:SetTexture(BAR_TEX.flat)
    self.pctBg:SetPoint("TOPLEFT", self.bigText, "TOPLEFT", -5, 2)
    self.pctBg:SetPoint("BOTTOMRIGHT", self.bigText, "BOTTOMRIGHT", 5, -2)
    self.pctBg:Hide()
    -- Rote Warn-Zahl für geheime Manawerte (Sichtbarkeit über eine Kurve des Spiels)
    self.warnHolder = CreateFrame("Frame", nil, fr)
    self.warnHolder:SetAllPoints(fr)
    self.warnHolder:SetFrameLevel(fr:GetFrameLevel() + 1)
    self.warnBig = self.warnHolder:CreateFontString(nil, "OVERLAY")
    self.warnBig:SetPoint("CENTER", self.bigText, "CENTER", 0, 0)
    -- Jede Schrift braucht von Anfang an einen Font, sonst bricht SetText ab
    -- ("Font not set") – z. B. valText im Balken-Modus, wo Layout ihn nie setzt
    for _, fs in ipairs({ self.bigText, self.valText, self.infoText, self.mp5Text, self.castText, self.warnBig }) do
        SetFontSize(fs, 14)
    end
    self.warnHolder:Hide()

    self.decorTex = {}
    self.activeDecor = {}
    self.flashAlpha = 0
    self.elapsed = 0

    f:SetScript("OnUpdate", function(_, elapsed)
        D.elapsed = D.elapsed + elapsed
        if D.elapsed < UPDATE_RATE then return end
        D.elapsed = 0
        -- Fehler nur einmal melden statt 40-mal pro Sekunde
        local ok, err = pcall(D.Update, D, GetTime())
        if not ok and not D.updateErrorShown then
            D.updateErrorShown = true
            ns.ReportError("Update", err)
        end
    end)
end

function D:SavePosition()
    local p, _, rp, x, y = self.frame:GetPoint()
    ns.db.point = { p or "CENTER", "UIParent", rp or "CENTER", x or 0, y or 0 }
end

-- Layout -------------------------------------------------------------------------
local function PlaceText(fs, parent, point, x, y)
    Unpin(fs)
    Pin(fs, point, parent, point, x, y)
end

-- Balken-Modus: waagerecht (Timer-Balken darunter) oder senkrecht (Timer-Balken rechts daneben).
-- barWidth/barHeight sind Breite und Höhe des Mana-Balkens relativ zur Grundgröße.
function D:LayoutBar(S)
    local mods = ns.db.modules
    local horiz = st("barOrientation") ~= "vertical"
    local Wf, Hf = max(4, S * st("barWidth")), max(4, S * st("barHeight"))
    local L1 = horiz and Wf or Hf            -- Länge (in Füllrichtung)
    local T1 = horiz and Hf or Wf            -- Dicke
    local T2 = (mods.fsr or mods.ticks) and max(3, T1 * 0.45) or 0
    local gap = T2 > 0 and max(2, T1 * 0.15) or 0
    local thick = T1 + gap + T2
    self.horiz, self.L1, self.T1, self.H2 = horiz, L1, T1, T2
    if horiz then
        self.frame:SetSize(L1, thick); self.W = L1
    else
        self.frame:SetSize(thick, L1); self.W = thick
    end

    local bf = self.barFrame
    bf:ClearAllPoints(); bf:SetAllPoints(self.frame); bf:Show()
    local pad = max(2, T1 * 0.12)
    Unpin(self.barBack)
    Pin(self.barBack, "TOPLEFT", bf, "TOPLEFT", -pad, pad)
    Pin(self.barBack, "BOTTOMRIGHT", bf, "BOTTOMRIGHT", pad, -pad)
    self.barBack:SetTexture(BAR_TEX.flat)

    local tex = BAR_TEX[st("barTexture")] or BAR_TEX.smooth
    local orient = horiz and "HORIZONTAL" or "VERTICAL"
    for _, pair in ipairs({ { self.bar, self.barEmpty }, { self.bar2, self.bar2Empty } }) do
        local bar, empty = pair[1], pair[2]
        bar:SetStatusBarTexture(tex)
        bar:SetOrientation(orient)
        bar:SetRotatesTexture(not horiz)
        empty:SetTexture(tex)
        RotTexCoord(empty, horiz and 0 or math.pi / 2)
        Unpin(bar)
    end
    if horiz then
        Pin(self.bar, "TOPLEFT", bf, "TOPLEFT"); Pin(self.bar, "TOPRIGHT", bf, "TOPRIGHT")
        self.bar:SetHeight(T1)
        Pin(self.bar2, "BOTTOMLEFT", bf, "BOTTOMLEFT"); Pin(self.bar2, "BOTTOMRIGHT", bf, "BOTTOMRIGHT")
        self.bar2:SetHeight(max(1, T2))
    else
        Pin(self.bar, "TOPLEFT", bf, "TOPLEFT"); Pin(self.bar, "BOTTOMLEFT", bf, "BOTTOMLEFT")
        self.bar:SetWidth(T1)
        Pin(self.bar2, "TOPRIGHT", bf, "TOPRIGHT"); Pin(self.bar2, "BOTTOMRIGHT", bf, "BOTTOMRIGHT")
        self.bar2:SetWidth(max(1, T2))
    end
    self.bar:SetReverseFill(st("barDir") == "reverse")
    self.barAfter:ClearAllPoints()
    self.barAfter:SetAllPoints(self.bar)
    self.barAfter:SetStatusBarTexture(tex)
    self.barAfter:SetOrientation(orient)
    self.barAfter:SetRotatesTexture(not horiz)
    self.barAfter:SetReverseFill(st("barDir") == "reverse")
    self.bar2:SetReverseFill(st("innerBarDir") == "reverse")
    self.bar:SetShown(mods.ring)
    self.bar2:SetShown(T2 > 0)

    local ts = st("textScale")
    self.valText:Hide()
    Unpin(self.mp5Text)
    if horiz then
        SetFontSize(self.bigText, T1 * 0.62 * ts)
        SetFontSize(self.infoText, max(T2 * 0.95, T1 * 0.4) * ts)
        SetFontSize(self.mp5Text, T1 * 0.5 * ts)
        PlaceText(self.bigText, self.bar, "CENTER", 0, 0)
        PlaceText(self.infoText, self.bar2, "CENTER", 0, 0)
        Pin(self.mp5Text, "TOP", bf, "BOTTOM", 0, -pad - 2)
        SetFontSize(self.castText, max(9, T1 * 0.5) * ts)
        Unpin(self.castText); Pin(self.castText, "BOTTOM", bf, "TOP", 0, pad + 2)
    else
        -- senkrecht: Zahlen über und unter dem Balken
        SetFontSize(self.bigText, S * 0.14 * ts)
        SetFontSize(self.infoText, S * 0.10 * ts)
        SetFontSize(self.mp5Text, S * 0.085 * ts)
        Unpin(self.bigText); Pin(self.bigText, "BOTTOM", bf, "TOP", 0, pad + 2)
        Unpin(self.infoText); Pin(self.infoText, "TOP", bf, "BOTTOM", 0, -pad - 2)
        Pin(self.mp5Text, "TOP", self.infoText, "BOTTOM", 0, -2)
        SetFontSize(self.castText, S * 0.09 * ts)
        Unpin(self.castText); Pin(self.castText, "BOTTOM", self.bigText, "TOP", 0, 2)
    end

    local sp = T1 * 1.6 * st("sparkSize")
    if horiz then self.spark:SetSize(sp * 0.5, sp) else self.spark:SetSize(sp, sp * 0.5) end
    if horiz then self.flash:SetSize(L1 * 1.2, thick * 2.5) else self.flash:SetSize(thick * 2.5, L1 * 1.2) end
end

-- Torte als Flüssigkeit vorbereiten
function D:SetupLiquid(R)
    self.pieR = R
    self.pieFrame:Show()
    self.pieEmpty:SetSize(R * 2, R * 2)
    self.pieEmpty:ClearAllPoints()
    self.pieEmpty:SetPoint("CENTER", self.pieFrame, "CENTER", 0, 0)
    self.pieEmpty:SetTexCoord(0, 1, 0, 1)
end

-- Füllstand der Flüssigkeits-Torte: ein Ausschnitt der Scheibe, von unten bzw. oben.
-- cut (optional): Manavorschau – der Teil zwischen cut und f in der Farbe (cr,cg,cb)
function D:UpdateLiquid(f, r, g, b, er, eg, eb, ea, cut, cr, cg, cb)
    self.pieEmpty:SetVertexColor(er, eg, eb, ea)
    if cut and cut < f then
        if self:LiquidTo(self.pieCost, f) then self.pieCost:SetVertexColor(cr, cg, cb, 1) end
        f = cut
    else
        self.pieCost:Hide()
    end
    if self:LiquidTo(self.pieFill, f) then self.pieFill:SetVertexColor(r, g, b, 1) end
end

-- Scheibe t bis zum Anteil f zeigen; false = nichts zu zeigen
function D:LiquidTo(t, f)
    local R = self.pieR or 1
    if f <= 0 then t:Hide(); return false end
    if f > 1 then f = 1 end
    t:ClearAllPoints()
    local dir = st("outerDir")
    if dir == "ltr" or dir == "rtl" then
        t:SetSize(R * 2 * f, R * 2)
        if dir == "ltr" then
            t:SetPoint("LEFT", self.pieFrame, "CENTER", -R, 0)
            t:SetTexCoord(0, f, 0, 1)
        else
            t:SetPoint("RIGHT", self.pieFrame, "CENTER", R, 0)
            t:SetTexCoord(1 - f, 1, 0, 1)
        end
    else
        t:SetSize(R * 2, R * 2 * f)
        if dir == "down" then
            t:SetPoint("TOP", self.pieFrame, "CENTER", 0, R)
            t:SetTexCoord(0, 1, 0, f)
        else
            t:SetPoint("BOTTOM", self.pieFrame, "CENTER", 0, -R)
            t:SetTexCoord(0, 1, 1 - f, 1)
        end
    end
    t:Show()
    return true
end

-- Trennlinien für die Torte "in Stücken": Speichen (rundherum) oder waagerechte Linien (von unten/oben)
function D:SetupGaps(R, S, dir)
    for _, t in ipairs(self.gaps) do t:Hide() end
    self.segN = nil
    if st("pieStyle") ~= "segments" then return end
    local N = min(MAX_SEGMENTS, max(2, floor(st("pieSegments") + 0.5)))
    self.segN = N
    local linear = ns.linearDirs[dir]
    local count = linear and (N - 1) or N
    -- bei sehr vielen Stücken (z. B. 1000) würden die Linien zu einer Fläche verschmelzen:
    -- dann nur in Schritten füllen, ohne Trennlinien
    if N > MAX_GAP_LINES then count = 0 end
    local th = max(1, S * 0.012)
    for k = 1, count do
        local t = self.gaps[k]
        if not t then
            t = self.gapFrame:CreateTexture(nil, "OVERLAY")
            self.gaps[k] = t
        end
        t:ClearAllPoints()
        if linear then
            local p = -R + 2 * R * k / N
            local chord = 2 * math.sqrt(max(0, R * R - p * p))
            t:SetTexture(BAR_TEX.flat)
            t:SetTexCoord(0, 1, 0, 1)
            if dir == "ltr" or dir == "rtl" then
                t:SetSize(th, max(1, chord))
                t:SetPoint("CENTER", self.gapFrame, "CENTER", p, 0)
            else
                t:SetSize(max(1, chord), th)
                t:SetPoint("CENTER", self.gapFrame, "CENTER", 0, p)
            end
        else
            local a = math.pi / 2 - (k - 1) / N * TWO_PI
            t:SetTexture(Media("spoke"))
            t:SetSize(R * 2, R * 2)
            t:SetPoint("CENTER", self.gapFrame, "CENTER", 0, 0)
            RotTexCoord(t, a - math.pi / 2)
        end
        t:Show()
    end
end

function D:LayoutCircle(S, mode)
    local mods = ns.db.modules
    self.barFrame:Hide()
    self.frame:SetSize(S, S)

    local rotate = st("rotateSymbols")
    local outerR = S * st("outerRadius")
    local outerSym = S * 0.075 * st("outerSize")
    local extent = 0
    local outerDir = st("outerDir")
    self.pieLiquid = false
    self.pieFrame:Hide()
    for _, t in ipairs(self.gaps) do t:Hide() end
    self.segN = nil
    if mods.ring and mode == "pie" then
        if ns.linearDirs[outerDir] then
            HideRing(self.outer)                   -- Flüssigkeit statt Tortenstücke
            self.pieLiquid = true
            self:SetupLiquid(outerR)
        else
            SetupRing(self.outer, "pie", "dot", 0, outerSym, outerR, true, outerDir)
        end
        self:SetupGaps(outerR, S, outerDir)
        extent = outerR
        self.outerExtent = outerR
    elseif mods.ring then
        SetupRing(self.outer, st("outerStyle"), st("outerShape"), st("outerCount"), outerSym, outerR, rotate, outerDir)
        extent = outerR + outerSym * 0.5
        self.outerExtent = extent
    else
        HideRing(self.outer)
    end
    if mods.fsr or mods.ticks then
        local innerSym = S * 0.055 * st("innerSize")
        local innerR = S * st("innerRadius")
        if mode == "pie" then                       -- in der Torte: Ring außen herum
            innerR = outerR + innerSym * 0.5 + S * 0.04
        end
        SetupRing(self.inner, st("innerStyle"), st("innerShape"), st("innerCount"), innerSym, innerR, rotate, st("innerDir"))
        extent = max(extent, innerR + innerSym * 0.5)
        self.innerExtent = innerR + innerSym * 0.5
    else
        HideRing(self.inner)
    end
    if extent == 0 then extent = S * 0.45 end
    self.extent = extent

    -- Hintergrund und Rand richten sich nach dem äußersten Ring
    local pad = S * 0.035
    local bgShape = st("bgShape")
    self.bg:SetTexture(Media(BG_TEX[bgShape] or "disc"))
    local bgS = 2 * (extent + pad) / 0.97 * st("bgSize") * (bgShape == "soft" and 1.3 or 1)
    self.bg:SetSize(bgS, bgS)
    local rimS = 2 * (extent + pad * 0.6) / 0.92 * st("rimSize")
    self.rim:SetSize(rimS, rimS)

    local sp = S * 0.2 * st("sparkSize")
    self.spark:SetSize(sp, sp)
    self.flash:SetSize(S * 0.9, S * 0.9)

    self.fallback:SetSize(S * 0.5, S * 0.07)
    self.fallbackAfter:ClearAllPoints()
    self.fallbackAfter:SetAllPoints(self.fallback)
    Unpin(self.fallback)
    Pin(self.fallback, "CENTER", self.main, "CENTER", 0, -S * 0.2)

    local ts = st("textScale")
    SetFontSize(self.bigText, S * 0.19 * ts)
    SetFontSize(self.valText, S * 0.095 * ts)
    SetFontSize(self.infoText, S * 0.11 * ts)
    SetFontSize(self.mp5Text, S * 0.085 * ts)
    PlaceText(self.bigText, self.front, "CENTER", 0, S * 0.04 * ts)
    PlaceText(self.valText, self.front, "CENTER", 0, S * 0.17 * ts)
    PlaceText(self.infoText, self.front, "CENTER", 0, -S * 0.10 * ts)
    PlaceText(self.mp5Text, self.front, "CENTER", 0, -S * 0.20 * ts)
    SetFontSize(self.castText, max(9, S * 0.095 * ts))
    Unpin(self.castText); Pin(self.castText, "BOTTOM", self.front, "TOP", 0, 2)
end

function D:Layout()
    local db, f = ns.db, self.frame
    local S = db.size
    self.S = S
    self.mode = db.mode
    f:SetScale(1)
    f:SetAlpha(db.alpha)
    f:ClearAllPoints()
    local p = db.point
    f:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    f:EnableMouse(not db.locked)

    if db.mode == "bar" then
        HideRing(self.outer); HideRing(self.inner)
        self.bg:Hide(); self.rim:Hide(); self.fallback:Hide()
        self.pieFrame:Hide(); self.pieLiquid = false; self.segN = nil
        for _, t in ipairs(self.gaps) do t:Hide() end
        self:LayoutBar(S)
    else
        self:LayoutCircle(S, db.mode)
    end
    -- Beispieltext, damit die Manavorschau in der Sandbox greifbar ist
    local sb = ns.Sandbox
    if db.modules.castPreview and sb and sb:IsActive() then
        self.castText:SetText(string.format(ns.L.CAST_AFTER, "1234", 60))
        self.castText:Show()
    else
        self.castText:Hide()
    end
end

function D:ApplyColors()
    local mods = ns.db.modules
    local br, bgc, bb = ns.GetColor("bg")
    local ba = st("bgAlpha")
    local er, eg, eb = ns.GetColor("empty")
    local ea = st("emptyAlpha")
    if self.mode == "bar" then
        self.barBack:SetVertexColor(br, bgc, bb, ba)
        self.barBack:SetShown(mods.background)
        self.bar:SetStatusBarColor(ns.GetColor("ring"))
        self.barEmpty:SetVertexColor(er, eg, eb, ea)
        local ter, teg, teb = ns.GetColor("timerEmpty")
        self.bar2Empty:SetVertexColor(ter, teg, teb, ea)
    else
        self.bg:SetVertexColor(br, bgc, bb, ba)
        self.bg:SetShown(mods.background)
        local rr, rg, rb = ns.GetColor("rim")
        self.rim:SetVertexColor(rr, rg, rb, st("rimAlpha"))
        self.rim:SetShown(mods.rim)
    end
    self.spark:SetVertexColor(ns.GetColor("spark"))
    self.fallback:SetStatusBarColor(ns.GetColor("ring"))
    local tr, tg, tb = ns.GetColor("text")
    self.bigText:SetTextColor(tr, tg, tb)
    self.valText:SetTextColor(tr * 0.85, tg * 0.85, tb * 0.85)
    self.mp5Text:SetTextColor(tr * 0.9, tg * 0.9, tb * 0.9)
    self.outer.cache.key, self.inner.cache.key = nil, nil
end

function D:ApplyDecor()
    for _, t in ipairs(self.decorTex) do t:Hide() end
    wipe(self.activeDecor)

    local db = ns.db
    local list = ns.GetDecor()
    local source = ns.GetDecorSource()
    local override = db.colors.decor
    local hasOverride = type(override) == "table" and override[1] ~= nil
    local base = hasOverride and override or source.colors.decor or { 1, 1, 1 }
    local S = self.S * st("decorScale")
    -- im Balken-Modus rücken seitliche Teile mit der Balkenbreite nach außen
    local kx = (self.mode == "bar") and max(1, (self.W or S) / self.S) or 1
    self.decorS, self.decorKX = S, kx
    local ox, oy = 0, 0
    if ns.Sandbox then ox, oy = ns.Sandbox:Offset("decor") end
    self.decorOX, self.decorOY = ox, oy

    for i, d in ipairs(list) do
        local t = self.decorTex[i]
        if not t then
            t = self.back:CreateTexture(nil, "ARTWORK")
            self.decorTex[i] = t
        end
        t:SetParent(d.front and self.front or self.back)
        t:SetDrawLayer(d.front and "BORDER" or "ARTWORK", min(7, i - 1))
        t:SetTexture(Media(d.tex))
        if d.mirror then t:SetTexCoord(1, 0, 0, 1) else t:SetTexCoord(0, 1, 0, 1) end
        t:SetBlendMode(d.blend or "BLEND")
        local c = hasOverride and base or d.color or base
        t:SetVertexColor(c[1], c[2], c[3])
        t:SetSize((d.w or 1) * S, (d.h or 1) * S)
        t:ClearAllPoints()
        t:SetPoint("CENTER", self.frame, "CENTER", (d.x or 0) * S * kx + ox, (d.y or 0) * S + oy)
        t:SetAlpha(d.alpha or 1)
        t:Show()
        self.activeDecor[#self.activeDecor + 1] = { tex = t, def = d, phase = i * 0.7 }
    end
end

function D:Refresh()
    if not self.frame then return end
    self:BuildCurves()
    local sb = ns.Sandbox
    if sb then sb:Restore() end      -- eigene Anordnung erst nach dem Layout wieder anwenden
    self:Layout()
    self:ApplyColors()
    self:ApplyDecor()
    if sb then
        local ok, err = pcall(sb.Apply, sb)   -- die Anordnung darf die Anzeige nie aufhalten
        if not ok then ns.ReportError("Sandbox", err) end
    end
    self:UpdateVisibility()
    if ns.Minimap then ns.Minimap:Refresh() end   -- Icon-Farbe folgt dem Thema
    self:Update(GetTime())
end

-- Sichtbarkeit ----------------------------------------------------------------------
function D:ShouldShow()
    local db = ns.db
    if not db.enabled then return false end                    -- per Minimap-Button ausgeschaltet
    if self.forceUntil and GetTime() < self.forceUntil then return true end
    if ns.Options and ns.Options:IsOpen() then return true end -- Vorschau beim Gestalten
    if ns.Sandbox and ns.Sandbox.editing then return true end  -- Bearbeitungsmodus
    if not db.locked then return true end                      -- entsperrt: immer zeigen (zum Verschieben)
    local cur, maxMana = ns.Tracker:GetMana()
    if db.onlyManaClasses and ns.Readable(maxMana) and maxMana <= 0 then return false end
    if db.hideWhenFull and not UnitAffectingCombat("player") then
        if ns.Readable(cur) and ns.Readable(maxMana) and cur >= maxMana and not ns.Tracker:InFSR() then
            return false
        end
    end
    return true
end

function D:UpdateVisibility()
    if not self.frame then return end
    self.frame:SetShown(self:ShouldShow())
    if ns.Sandbox then ns.Sandbox:UpdateVisibility() end
end

function D:Show(force)
    if force then self.forceUntil = GetTime() + 8 end
    self:UpdateVisibility()
end

-- Rückmeldungen vom Tracker -------------------------------------------------------
function D:OnFSRStart()
    self:UpdateVisibility()
end

function D:OnTick()
    self.flashAlpha = st("fxTickFlash") and 0.6 or 0
    self.tickShownUntil = GetTime() + 1.2
end

-- MP5-Zeile: aktuelle Regeneration bzw. beide Werte (normal / während der 5-Sek.-Regel)
function D:MP5Line(now)
    local mode = st("mp5Mode")
    if mode == "off" then return "" end
    local base, cast = ns.Tracker:GetMP5()
    if not base and not cast then return "" end
    local inFSR = ns.Tracker:InFSR(now)
    local fsrHex, tickHex = Hex(ns.GetColor("fsr")), Hex(ns.GetColor("tick"))
    local function n(v) return v and tostring(floor(v + 0.5)) or "?" end
    if mode == "current" then
        if inFSR then return ns.L.MP5 .. " " .. fsrHex .. n(cast) .. "|r" end
        return ns.L.MP5 .. " " .. tickHex .. n(base) .. "|r"
    end
    local a = (inFSR and "|cff808080" or tickHex) .. n(base) .. "|r"
    local b = (inFSR and fsrHex or "|cff808080") .. n(cast) .. "|r"
    return ns.L.MP5 .. " " .. a .. " / " .. b
end

-- Manavorschau im Balken: Bereich von a bis b (Anteile 0..1) der Mana-Leiste markieren
function D:PlaceBarCost(a, b)
    local t, L1 = self.barCost, self.L1 or 1
    local len = max(1, (b - a) * L1)
    local rev = st("barDir") == "reverse"
    t:ClearAllPoints()
    if self.horiz then
        if rev then t:SetPoint("RIGHT", self.bar, "RIGHT", -a * L1, 0)
        else t:SetPoint("LEFT", self.bar, "LEFT", a * L1, 0) end
        t:SetSize(len, self.T1 or 1)
    else
        if rev then t:SetPoint("TOP", self.bar, "TOP", 0, -a * L1)
        else t:SetPoint("BOTTOM", self.bar, "BOTTOM", 0, a * L1) end
        t:SetSize(self.T1 or 1, len)
    end
end

-- Manavorschau: was bleibt nach dem laufenden Zauber?
-- Rückgabe: Textzeile (oder nil), Anteil nach dem Zauber und Anteil jetzt (beide nur, wenn
-- der Füllstand sicher bekannt ist – sonst säße die Markierung an der falschen Stelle)
function D:CastPreview(cur, maxMana, frac, readable)
    local T = ns.Tracker
    local cost = T:CastPreview()
    if not cost then return nil end
    local L = ns.L
    local mx = ns.Readable(maxMana) and type(maxMana) == "number" and maxMana > 0 and maxMana or nil
    local nowF, exact = nil, false
    if readable then
        nowF, exact = frac, true
    else
        local p = self:ReadablePercent()
        if p then nowF, exact = p, true else nowF = T:EstimatedFraction() end
    end
    if not exact and mx then
        -- Mana geheim: das Spiel rechnet "Mana minus Kosten" selbst über Kurven (exakt)
        local pc = self:PreviewCurves(cost, mx)
        if pc then
            local line
            if nowF and nowF * mx - cost < 0 then line = Hex(ns.GetColor("low")) .. L.CAST_NOMANA .. "|r" end
            return line, nil, nil, pc
        end
    end
    if not (nowF and mx) then
        return Hex(ns.GetColor("cast")) .. string.format(L.CAST_COST, ShortNumber(cost)) .. "|r"
    end
    local mana = (readable and type(cur) == "number") and cur or nowF * mx
    local after = mana - cost
    if after < 0 then
        return Hex(ns.GetColor("low")) .. L.CAST_NOMANA .. "|r", exact and 0 or nil, exact and nowF or nil
    end
    local af = min(1, after / mx)
    local cr, cg, cb
    if st("textColorMode") == "gradient" then cr, cg, cb = self:GradientColor(af) else cr, cg, cb = ns.GetColor("cast") end
    local line = string.format(L.CAST_AFTER, (exact and "" or "~") .. ShortNumber(after), floor(af * 100 + 0.5))
    return Hex(cr, cg, cb) .. line .. "|r", exact and af or nil, exact and nowF or nil
end

-- Laufende Aktualisierung --------------------------------------------------------
-- Geheime Manawerte -------------------------------------------------------------
-- Das Spiel darf uns den Wert nicht verraten, kann ihn aber selbst über Kurven
-- umrechnen (UnitPowerPercent + C_CurveUtil). So bekommen wir Prozentzahl,
-- Farbverlauf und Warn-Sichtbarkeit, ohne selbst mit dem Wert zu rechnen.
local function NewCurve(kind, points)
    local c = C_CurveUtil.CreateCurve()
    c:SetType(Enum.LuaCurveType[kind])
    for _, p in ipairs(points) do c:AddPoint(p[1], p[2]) end
    return c
end

function D:BuildCurves()
    self.cv = nil
    if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType and UnitPowerPercent) then return end
    local ok, cv = pcall(function()
        local c = { pct = NewCurve("Linear", { { 0, 0 }, { 1, 100 } }) }
        -- je ein Satz Farbkurven für die Zahlen (r/g/b) und die Mana-Leiste (br/bg/bb)
        for prefix, which in pairs({ [""] = "text", b = "mana" }) do
            local gr = ns.gradients[which]
            local m = max(0.01, min(0.99, st(gr[4]) / 100))
            local hr, hg, hb = ns.GetColor(gr[1])
            local mr, mg, mb = ns.GetColor(gr[2])
            local lr, lg, lb = ns.GetColor(gr[3])
            c[prefix .. "r"] = NewCurve("Linear", { { 0, lr }, { m, mr }, { 1, hr } })
            c[prefix .. "g"] = NewCurve("Linear", { { 0, lg }, { m, mg }, { 1, hg } })
            c[prefix .. "b"] = NewCurve("Linear", { { 0, lb }, { m, mb }, { 1, hb } })
        end
        local t
        if st("warnUnit") == "mana" then
            local mx = UnitPowerMax("player", ns.MANA)
            if ns.Readable(mx) and mx > 0 then t = st("warnValue") / mx end
        else
            t = st("warnValue") / 100
        end
        if t then
            t = min(1, t) + 0.0001
            c.low    = NewCurve("Step", { { 0, 1 }, { t, 0 } })   -- 1 = wenig Mana
            c.notLow = NewCurve("Step", { { 0, 0 }, { t, 1 } })
        end
        return c
    end)
    if ok then self.cv = cv end
end

local function Eval(curve)
    if not curve then return nil end
    local ok, v = pcall(UnitPowerPercent, "player", ns.MANA, false, curve)
    if ok then return v end
end

-- Kurven für die Manavorschau bei geheimen Werten: aus dem Anteil x wird der Stand nach
-- dem Zauber (x - Kosten, nie unter 0) – als Anteil, Prozentzahl und Manawert
function D:PreviewCurves(cost, mx)
    if not self.cv then return nil end
    local c = min(1, cost / mx)
    local pc = self.prevCurves
    if pc and pc.c == c and pc.mx == mx then return pc end
    local ok, res = pcall(function()
        local function pts(top)
            if c >= 1 then return { { 0, 0 }, { 1, 0 } } end
            return { { 0, 0 }, { c, 0 }, { 1, top } }
        end
        return { c = c, mx = mx, frac = NewCurve("Linear", pts(1 - c)),
                 pct = NewCurve("Linear", pts(100 * (1 - c))), val = NewCurve("Linear", pts(mx - cost)) }
    end)
    if ok then self.prevCurves = res; return res end
end

-- Mana-Anteil (0..1) über UnitPowerPercent – nur wenn das Spiel ihn lesbar herausgibt
function D:ReadablePercent()
    local p = self.cv and Eval(self.cv.pct)
    if p ~= nil and ns.Readable(p) and type(p) == "number" then
        return max(0, min(1, p / 100))
    end
end

-- Für /msig debug: prüft jeden Schritt der Anzeige bei geheimen Werten einzeln
function D:SelfTest()
    local out = {}
    local function add(name, ok, err)
        out[#out + 1] = name .. "=" .. (ok and "ok" or ("|cffff6060FAIL|r" .. (err and (" (" .. tostring(err):sub(1, 80) .. ")") or "")))
    end
    add("api", C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType and UnitPowerPercent)
    add("curves", self.cv ~= nil)
    local cv = self.cv
    if cv then
        local ok, p = pcall(UnitPowerPercent, "player", ns.MANA, false, cv.pct)
        add("pct", ok and p ~= nil, not ok and p)
        if ok and p ~= nil and self.bigText then
            local fok, ferr = pcall(self.bigText.SetFormattedText, self.bigText, "%.0f%%", p)
            add("format", fok, ferr)
        end
        local okR, r = pcall(UnitPowerPercent, "player", ns.MANA, false, cv.r)
        if okR and r ~= nil and self.bigText then
            local cok, cerr = pcall(self.bigText.SetTextColor, self.bigText, r, r, r)
            add("color", cok, cerr)
        else
            add("colorcurve", false, r)
        end
        if cv.low then
            local lok, l = pcall(UnitPowerPercent, "player", ns.MANA, false, cv.low)
            add("low", lok and l ~= nil, not lok and l)
            if lok and l ~= nil and self.warnBig then
                local aok, aerr = pcall(self.warnBig.SetAlpha, self.warnBig, l)
                add("alpha", aok, aerr)
            end
        else
            add("lowcurve", false)
        end
    end
    out[#out + 1] = "warnShown=" .. ((self.warnHolder and self.warnHolder:IsShown()) and "yes" or "no")
    out[#out + 1] = "noSecretColor=" .. (self.noSecretColor and "yes" or "no")
    return table.concat(out, " ")
end

-- Text bei geheimen Werten; schreibt in die normale und in die rote Warn-Zahl
-- pc (optional): Kurven der Manavorschau – zeigt dann den Stand nach dem Zauber
function D:SecretText(cur, tm, mode, pc)
    local p
    if pc then
        p = Eval(pc.pct)
        cur = Eval(pc.val) or cur
    else
        p = self.cv and Eval(self.cv.pct)
    end
    self.valText:SetText("")
    for _, fs in ipairs({ self.bigText, self.warnBig }) do
        local ok
        if p and tm == "percent" then
            ok = pcall(fs.SetFormattedText, fs, "%.0f%%", p)
        elseif p and tm == "both" and mode == "bar" then
            ok = pcall(fs.SetFormattedText, fs, pc and "%.0f  (%.0f%%)" or "%s  (%.0f%%)", cur, p)
        elseif p and tm == "both" then
            ok = pcall(fs.SetFormattedText, fs, "%.0f%%", p)
            if fs == self.bigText then
                if pc then pcall(self.valText.SetFormattedText, self.valText, "%.0f", cur)
                else pcall(self.valText.SetText, self.valText, cur) end
            end
        elseif pc then
            ok = pcall(fs.SetFormattedText, fs, "%.0f", cur)    -- Kurvenwerte sind Kommazahlen
        else
            ok = pcall(fs.SetText, fs, cur)
        end
        if not ok then pcall(fs.SetText, fs, "") end
    end
end

-- Farbverlauf und Warnung bei geheimen Werten (Blinken ja, Ton nicht möglich)
function D:SecretStyle(now, textOn)
    local cv = self.cv
    if not cv then self.warnHolder:Hide(); return end
    if textOn and st("textColorMode") == "gradient" and not self.noSecretColor then
        local r, g, b = Eval(cv.r), Eval(cv.g), Eval(cv.b)
        if r and g and b then
            if pcall(self.bigText.SetTextColor, self.bigText, r, g, b) then
                pcall(self.valText.SetTextColor, self.valText, r, g, b)
            else
                self.noSecretColor = true      -- dieser Client erlaubt das nicht
            end
        end
    end
    if st("manaColorMode") == "gradient" and not self.noSecretBarColor then
        -- Balken-Modus: die Mana-Leiste; Kreis/Torte: der Ersatzbalken
        local target = (self.mode == "bar") and self.bar or self.fallback
        local r, g, b = Eval(cv.br), Eval(cv.bg), Eval(cv.bb)
        if target and r and g and b and not pcall(target.SetStatusBarColor, target, r, g, b) then
            self.noSecretBarColor = true
        end
    end
    local warn = textOn and cv.low and st("warnEnabled")
        and not (st("warnCombatOnly") and not (UnitAffectingCombat and UnitAffectingCombat("player")))
    local lowA, notA = warn and Eval(cv.low), warn and Eval(cv.notLow)
    if lowA and notA then
        local font, size, flags = self.bigText:GetFont()
        if font then self.warnBig:SetFont(font, size, flags) end
        self.warnBig:SetTextColor(ns.GetColor("low"))
        local okA = pcall(self.warnBig.SetAlpha, self.warnBig, lowA)
        okA = okA and pcall(self.bigText.SetAlpha, self.bigText, notA)
        if okA then
            pcall(self.valText.SetAlpha, self.valText, notA)
            local blink = st("warnBlink") ~= "off"
            self.warnHolder:SetAlpha(blink and (0.2 + 0.8 * math.abs(sin(now * 5))) or 1)
            self.warnHolder:Show()
            return
        end
    end
    self.warnHolder:Hide()
end

-- Farbverlauf: voll = "high" (grün), in der Mitte = "mid" (gelb), leer = "low" (rot)
-- which = "text" (Zahlen), "mana" (Mana-Leiste) oder "timer" (Tick-/5-Sek.-Leiste)
function D:GradientColor(frac, which)
    local g = ns.gradients[which or "text"]
    local hr, hg, hb = ns.GetColor(g[1])
    local mr, mg, mb = ns.GetColor(g[2])
    local lr, lg, lb = ns.GetColor(g[3])
    local m = max(0.01, min(0.99, st(g[4]) / 100))
    if frac >= m then
        local t = min(1, (frac - m) / (1 - m))
        return mr + (hr - mr) * t, mg + (hg - mg) * t, mb + (hb - mb) * t
    end
    local t = max(0, frac / m)
    return lr + (mr - lr) * t, lg + (mg - lg) * t, lb + (mb - lb) * t
end

-- Wenig Mana? Nur mit lesbaren Werten (geheime Werte lassen sich nicht vergleichen)
function D:IsLowMana(cur, frac, readable, margin)
    if not readable or not st("warnEnabled") then return false end
    if st("warnCombatOnly") and not (UnitAffectingCombat and UnitAffectingCombat("player")) then return false end
    local v = st("warnValue") + (margin or 0)
    if st("warnUnit") == "mana" then return cur <= v end
    return frac * 100 <= v
end

-- Warnton beim Unterschreiten der Schwelle; erneut erst, wenn das Mana wieder etwas darüber lag
function D:UpdateWarning(now, low, cur, frac, readable)
    if low then
        local rep = st("warnRepeat") or 0
        if self.warnArmed ~= false or (rep > 0 and now - (self.warnLast or 0) >= rep) then
            self.warnArmed = false
            self.warnLast = now
            if st("warnSound") ~= "off" then ns.PlayWarnSound(st("warnSound")) end
        end
    elseif not self:IsLowMana(cur, frac, readable, st("warnUnit") == "mana" and 50 or 2) then
        self.warnArmed = true
    end
end

function D:Update(now)
    local db, mods, T = ns.db, ns.db.modules, ns.Tracker
    local S = self.S or db.size
    local mode = self.mode or db.mode
    local cur, maxMana = T:GetMana()
    local readable = ns.Readable(cur) and ns.Readable(maxMana)

    local er, eg, eb = ns.GetColor("empty")
    local ea = st("emptyAlpha")
    local mr, mg, mb
    if mods.background then mr, mg, mb = ns.GetColor("bg") end

    -- Mana-Anzeige ------------------------------------------------------------
    local frac = 0
    if readable then
        frac = (maxMana > 0) and (cur / maxMana) or 0
        if frac > 1 then frac = 1 end
    end
    local r, g, b = ns.GetColor("ring")
    -- Für die Warnung: bei geheimem Mana den Prozentwert vom Spiel holen, falls er lesbar ist,
    -- sonst das selbst mitgerechnete Mana (Tracker:EstimatedFraction)
    local wcur, wfrac, wread = cur, frac, readable
    T:UpdateEstimate(now)          -- läuft immer mit, damit die Zeitrechnung nicht springt
    if not readable then
        wfrac = self:ReadablePercent() or T:EstimatedFraction()
        if wfrac then
            wread = true
            wcur = ns.Readable(maxMana) and wfrac * maxMana or 0
        end
    end
    local low = self:IsLowMana(wcur, wfrac, wread)
    self:UpdateWarning(now, low, wcur, wfrac, wread)
    if readable and st("manaColorMode") == "gradient" then r, g, b = self:GradientColor(frac, "mana") end
    local showSpark = mods.spark and mods.ring and readable and frac > 0 and frac < 1

    -- Manavorschau beim Zaubern: die Mana-Anzeige zeigt schon den Stand NACH dem Zauber.
    -- Der Teil, den der Zauber kostet, bleibt nur als blasser, pulsierender Schatten stehen.
    local castLine, cut, _, pcurves
    if mods.castPreview then castLine, cut, _, pcurves = self:CastPreview(cur, maxMana, frac, readable) end
    local pv = cut ~= nil or pcurves ~= nil        -- Vorschau läuft
    local gr0, gg0, gb0 = ns.GetColor("cast")
    local ghostA = 0.3 + 0.35 * math.abs(sin(now * 4))   -- Schatten der Kosten pulsiert
    local pr, pg, pb
    if cut then
        local k = 0.25 + 0.35 * math.abs(sin(now * 4))
        local cr, cg, cb = ns.GetColor("cast")
        pr, pg, pb = er + (cr - er) * k, eg + (cg - eg) * k, eb + (cb - eb) * k
        if readable then showSpark = showSpark and cut > 0 end
    end
    local sparkFrac = (readable and cut) or frac

    if mode == "bar" then
        if mods.ring then
            -- StatusBars dürfen auch geheime Werte anzeigen
            pcall(self.bar.SetMinMaxValues, self.bar, 0, maxMana)
            pcall(self.bar.SetValue, self.bar, cur)
            local after = cut and max(0, min(1, cut)) or (pcurves and Eval(pcurves.frac))
            self.barAfter:SetMinMaxValues(0, 1)
            if pv and after ~= nil and pcall(self.barAfter.SetValue, self.barAfter, after) then
                self.bar:SetStatusBarColor(gr0, gg0, gb0, ghostA)    -- Kosten = blasser Schatten
                self.barAfter:SetStatusBarColor(r, g, b)
                self.barAfter:Show()
            else
                self.bar:SetStatusBarColor(r, g, b, 1)
                self.barAfter:Hide()
            end
        else
            self.barAfter:Hide()
        end
        self.barCost:Hide()
        if showSpark then
            local pos = self.L1 * sparkFrac
            if st("barDir") == "reverse" then pos = self.L1 - pos end
            self.spark:ClearAllPoints()
            if self.horiz then
                self.spark:SetPoint("CENTER", self.bar, "LEFT", pos, 0)
            else
                self.spark:SetPoint("CENTER", self.bar, "BOTTOM", 0, pos)
            end
            self.spark:SetAlpha(st("fxSparkPulse") and (0.7 + 0.3 * sin(now * 6)) or 1)
            self.spark:Show()
        else
            self.spark:Hide()
        end
        self.fallback:Hide()
    else
        local dir = st("outerDir")
        if mods.ring then
            -- Torte "in Stücken": nur ganze Stücke füllen
            local shown = frac
            if self.segN then shown = floor(frac * self.segN + 1e-6) / self.segN end
            local ringCut = readable and cut or nil   -- Ring zeigt nur lesbare Werte
            if ringCut and self.segN then ringCut = floor(ringCut * self.segN + 1e-6) / self.segN end
            if self.pieLiquid then
                self:UpdateLiquid(shown, r, g, b, er, eg, eb, ea, ringCut, pr, pg, pb)
            else
                FillRing(self.outer, shown, r, g, b, er, eg, eb, ea, mr, mg, mb, ringCut, pr, pg, pb)
            end
            if self.segN then
                local gr, gg, gb = 0, 0, 0
                if mods.background then gr, gg, gb = ns.GetColor("bg") end
                for _, t in ipairs(self.gaps) do t:SetVertexColor(gr, gg, gb, 1) end
            end
        end
        -- Funke nur bei Füllung rundherum (bei "von unten/oben" gibt es keine Spitze)
        if showSpark and (dir == "cw" or dir == "ccw") then
            local a = math.pi / 2 + (dir == "cw" and -1 or 1) * sparkFrac * TWO_PI
            local rad = self.outer.radius or S * 0.42
            if self.outer.kind == "pie" then rad = rad * 0.92 end
            self.spark:ClearAllPoints()
            local mx, my = 0, 0     -- der Funke folgt einem verschobenen Mana-Ring
            if ns.Sandbox then mx, my = ns.Sandbox:Offset("mana") end
            self.spark:SetPoint("CENTER", self.main, "CENTER", cos(a) * rad + mx, sin(a) * rad + my)
            self.spark:SetAlpha(st("fxSparkPulse") and (0.7 + 0.3 * sin(now * 6)) or 1)
            self.spark:Show()
        else
            self.spark:Hide()
        end
        if not readable and mods.fallback and mods.ring then
            -- Geheime Werte: nur über das StatusBar-Widget anzeigen, nicht rechnen
            pcall(self.fallback.SetMinMaxValues, self.fallback, 0, maxMana)
            pcall(self.fallback.SetValue, self.fallback, cur)
            local after = pcurves and Eval(pcurves.frac)
            self.fallbackAfter:SetMinMaxValues(0, 1)
            if after ~= nil and pcall(self.fallbackAfter.SetValue, self.fallbackAfter, after) then
                self.fallback:SetStatusBarColor(gr0, gg0, gb0, ghostA)
                self.fallbackAfter:SetStatusBarColor(r, g, b)
                self.fallbackAfter:Show()
            else
                self.fallback:SetStatusBarColor(r, g, b, 1)
                self.fallbackAfter:Hide()
            end
            self.fallback:Show()
        else
            self.fallback:Hide()
        end
    end

    -- 5-Sekunden-Regel / Tick-Timer ------------------------------------------------
    local state, ifrac, info = "idle", 0, ""
    local ir, ig, ib = ns.GetColor("tick")
    if mods.fsr and T:InFSR(now) then
        state = "fsr"
        local rem = T:FSRRemaining(now)
        ifrac = rem / T.FSR_DURATION
        if st("fsrFill") == "fill" then ifrac = 1 - ifrac end
        ir, ig, ib = ns.GetColor("fsr")
        info = string.format("%.1f", rem)
    elseif mods.ticks and (not readable or frac < 1) and T:TickProgress(now) then
        state = "tick"
        local p = T:TickProgress(now)
        ifrac = (st("tickFill") == "drain") and (1 - p) or p
        if self.tickShownUntil and now < self.tickShownUntil and T.tickAmount then
            info = "+" .. ShortNumber(T.tickAmount)
        end
    end
    if state ~= "idle" and st("timerColorMode") == "gradient" then
        ir, ig, ib = self:GradientColor(ifrac, "timer")
    end
    local hideIdle = state == "idle" and st("innerHideIdle")

    if mode == "bar" then
        if self.H2 and self.H2 > 0 then
            self.bar2:SetValue(ifrac)
            self.bar2:SetStatusBarColor(ir, ig, ib)
            self.bar2:SetAlpha(hideIdle and 0 or 1)
        end
    elseif mods.fsr or mods.ticks then
        if hideIdle then
            self.inner.frame:Hide()
        else
            self.inner.frame:Show()
            local ter, teg, teb = ns.GetColor("timerEmpty")
            FillRing(self.inner, ifrac, ir, ig, ib, ter, teg, teb, state == "idle" and ea * 0.6 or ea, mr, mg, mb)
        end
    end

    -- Rand leuchtet während der 5-Sek.-Regel
    if mode ~= "bar" and mods.rim then
        if state == "fsr" and st("rimFSR") then
            local fr, fg, fb = ns.GetColor("fsr")
            local pulse = st("fxRimPulse") and 0.15 * sin(now * 8) or 0
            self.rim:SetVertexColor(fr, fg, fb, min(1, st("rimAlpha") + 0.35 + pulse))
        else
            local rr, rg, rb = ns.GetColor("rim")
            self.rim:SetVertexColor(rr, rg, rb, st("rimAlpha"))
        end
    end

    -- Text ------------------------------------------------------------------------
    local tm = db.textMode
    if mods.text and tm ~= "none" and mods.ring then
        -- Manavorschau: Zahlen zeigen schon den Stand nach dem Zauber
        local tFrac, tCur = frac, cur
        if cut then tFrac, tCur = cut, cut * maxMana end
        if readable or cut then
            local pct = floor(tFrac * 100 + 0.5) .. "%"
            local cur = tCur      -- luacheck: ignore 421
            if mode == "bar" then
                if tm == "percent" then self.bigText:SetText(pct)
                elseif tm == "value" then self.bigText:SetText(ShortNumber(cur))
                else self.bigText:SetText(ShortNumber(cur) .. "  (" .. pct .. ")") end
                self.valText:SetText("")
            elseif tm == "percent" then
                self.bigText:SetText(pct); self.valText:SetText("")
            elseif tm == "value" then
                self.bigText:SetText(ShortNumber(cur)); self.valText:SetText("")
            else
                self.bigText:SetText(pct); self.valText:SetText(ShortNumber(cur))
            end
        else
            self:SecretText(cur, tm, mode, pcurves)
        end
        -- Textfarbe: fest oder Verlauf; bei Warnung rot
        local tr, tg, tb
        if pv then
            -- Vorschau-Farbe (rot, wenn das Mana nicht reicht), leicht pulsierend
            local k = 0.75 + 0.25 * math.abs(sin(now * 4))
            local cr, cg, cb = ns.GetColor((cut and cut <= 0) and "low" or "cast")
            tr, tg, tb = cr * k, cg * k, cb * k
        elseif readable and low then
            tr, tg, tb = ns.GetColor("low")
        elseif readable and st("textColorMode") == "gradient" then
            tr, tg, tb = self:GradientColor(frac)
        else
            tr, tg, tb = ns.GetColor("text")
        end
        self.bigText:SetTextColor(tr, tg, tb)
        self.valText:SetTextColor(tr * 0.85, tg * 0.85, tb * 0.85)
        self.bigText:Show(); self.valText:SetShown(mode ~= "bar")
        if st("pctBg") then
            local br, bgc, bb = ns.GetColor("pctbg")
            self.pctBg:SetVertexColor(br, bgc, bb, st("pctBgAlpha"))
            self.pctBg:Show()
        else
            self.pctBg:Hide()
        end
    else
        self.bigText:Hide(); self.valText:Hide(); self.pctBg:Hide()
    end

    -- Blinken bei wenig Mana
    local blink = low and st("warnBlink") or "off"
    local ba = (blink ~= "off") and (0.2 + 0.8 * math.abs(sin(now * 5))) or 1
    self.bigText:SetAlpha(blink == "text" and ba or 1)
    self.valText:SetAlpha(blink == "text" and ba or 1)
    if blink == "all" then
        self.frame:SetAlpha(db.alpha * ba); self.blinkAll = true
    elseif self.blinkAll then
        self.frame:SetAlpha(db.alpha); self.blinkAll = nil
    end
    if readable or pv then
        self.warnHolder:Hide()
    else
        self:SecretStyle(now, mods.text and tm ~= "none" and mods.ring)
    end
    local sb = ns.Sandbox
    if info == "" and sb and sb:IsActive() then info = "5.0" end   -- Beispielschrift zum Greifen
    self.infoText:SetText(info)
    self.infoText:SetTextColor(ir, ig, ib)
    self.infoText:SetShown(mods.text)
    if mods.text then
        local line = self:MP5Line(now)
        self.mp5Text:SetText(line)
        self.mp5Text:Show()
        if st("mp5Bg") and line ~= "" then
            local br, bgc, bb = ns.GetColor("mp5bg")
            self.mp5Bg:SetVertexColor(br, bgc, bb, st("mp5BgAlpha"))
            self.mp5Bg:Show()
        else
            self.mp5Bg:Hide()
        end
    else
        self.mp5Text:Hide()
        self.mp5Bg:Hide()
    end

    -- Textzeile der Manavorschau (in der Sandbox ein Beispiel zum Greifen).
    -- Mit sicher bekanntem Stand steht die Vorschau in der Mana-Anzeige selbst; die Zeile
    -- darüber bleibt für "Zu wenig Mana!" und für geschätzte Werte
    if cut and cut > 0 then castLine = nil end
    if not castLine and mods.castPreview and sb and sb:IsActive() then
        castLine = string.format(ns.L.CAST_AFTER, "1234", 60)
    end
    if castLine then
        self.castText:SetText(castLine)
        self.castText:Show()
    else
        self.castText:Hide()
    end

    -- Aufblitzen bei Mana-Tick
    if self.flashAlpha > 0 then
        self.flashAlpha = max(0, self.flashAlpha - 0.04)
        local tr, tg, tb = ns.GetColor("tick")
        self.flash:SetVertexColor(tr, tg, tb)
        self.flash:SetAlpha(self.flashAlpha)
    end

    -- Dekorations-Animationen: jeder Effekt einzeln abschaltbar. Abgeschaltete
    -- Effekte setzen die Deko in die Ruhelage zurück (nicht mitten in der Bewegung stehen lassen)
    do
        local anim = mods.animations
        local fxRot, fxBob = anim and st("fxRotate"), anim and st("fxBob")
        local fxPulse, fxFlick = anim and st("fxPulse"), anim and st("fxFlicker")
        local DS, kx = self.decorS or S, self.decorKX or 1
        for _, a in ipairs(self.activeDecor) do
            local d, t = a.def, a.tex
            if d.rotate then RotTexCoord(t, fxRot and (now * d.rotate) % TWO_PI or 0) end
            if d.bob then
                local off = fxBob and sin(now * (d.bobSpeed or 1) * math.pi) * d.bob * DS or 0
                t:ClearAllPoints()
                t:SetPoint("CENTER", self.frame, "CENTER", (d.x or 0) * DS * kx + (self.decorOX or 0),
                    (d.y or 0) * DS + off + (self.decorOY or 0))
            end
            local alpha = d.alpha or 1
            if d.pulse and fxPulse then
                alpha = alpha * (1 - d.pulse * 0.5 + d.pulse * 0.5 * sin(now * (d.pulseSpeed or 1) * math.pi))
            end
            if d.flicker and fxFlick then
                alpha = alpha * (0.5 + 0.5 * math.abs(sin(now * 13 + a.phase) * sin(now * 7.3)))
            end
            t:SetAlpha(max(0, min(1, alpha)))
        end
    end

    if sb and sb.drag then sb:Dim() end

    -- Sichtbarkeit bei "bei vollem Mana ausblenden" nachziehen
    if db.hideWhenFull and db.locked then
        local full = readable and frac >= 1 and not T:InFSR(now)
        if full ~= self.lastFull then
            self.lastFull = full
            self:UpdateVisibility()
        end
    end
end

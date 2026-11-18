-- ManaSigil – Anzeige: Kreis / Torte / Balken, 5-Sek.-Regel, Ticks, MP5, Hintergrund, Deko
local _, ns = ...

local D = {}
ns.Display = D

local UPDATE_RATE = 1 / 40          -- max. 40 Aktualisierungen pro Sekunde
local MAX_PIPS = 240                -- Obergrenze pro Ring
local PIE_N = 90                    -- Tortenstücke (passend zur Grafik "wedge")
local TWO_PI = math.pi * 2
local sin, cos, floor, max, min = math.sin, math.cos, math.floor, math.max, math.min

local BG_TEX = { disc = "disc", soft = "glow", ring = "rim" }
local BAR_TEX = {
    smooth   = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    flat     = "Interface\\Buttons\\WHITE8X8",
    blizzard = "Interface\\TargetingFrame\\UI-StatusBar",
}

local function Media(name) return ns.MEDIA .. name end
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
local function NewRing(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    return { frame = f, pips = {}, n = 0, cache = {} }
end

local function PipAngle(i, n, clockwise)
    local frac = (i - 0.5) / n
    if clockwise then return math.pi / 2 - frac * TWO_PI end
    return math.pi / 2 + frac * TWO_PI
end

local function SetupRing(ring, kind, shape, count, size, radius, rotate, clockwise)
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
    ring.n, ring.kind, ring.radius, ring.clockwise = n, kind, radius, clockwise
    ring.cache.key = nil
    for i = 1, n do
        local t = ring.pips[i]
        if not t then
            t = ring.frame:CreateTexture(nil, "ARTWORK")
            ring.pips[i] = t
        end
        local a = PipAngle(i, n, clockwise)
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
local function FillRing(ring, frac, r, g, b, er, eg, eb, ea, mixR, mixG, mixB)
    local n = ring.n
    if n == 0 then return end
    local filled = frac * n
    local key = floor(filled * 16 + 0.5)
    local c = ring.cache
    if c.key == key and c.r == r and c.g == g and c.b == b and c.er == er and c.ea == ea and c.mr == mixR then return end
    c.key, c.r, c.g, c.b, c.er, c.ea, c.mr = key, r, g, b, er, ea, mixR

    local opaque = ring.kind ~= "symbols"
    if opaque then
        local mr, mg, mb = mixR or 0, mixG or 0, mixB or 0
        er, eg, eb = mr + (er - mr) * ea, mg + (eg - mg) * ea, mb + (eb - mb) * ea
        ea = 1
    end
    for i = 1, n do
        local v = filled - (i - 1)
        local t = ring.pips[i]
        if v >= 1 then
            t:SetVertexColor(r, g, b, 1)
        elseif v > 0 then
            if opaque then
                t:SetVertexColor(er + (r - er) * v, eg + (g - eg) * v, eb + (b - eb) * v, 1)
            else
                t:SetVertexColor(r, g, b, ea + (1 - ea) * v)
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
    self.front = CreateFrame("Frame", nil, f); self.front:SetAllPoints(); self.front:SetFrameLevel(lvl + 5)

    local m = self.main
    self.bg = m:CreateTexture(nil, "BACKGROUND")
    self.bg:SetPoint("CENTER")
    self.rim = m:CreateTexture(nil, "BORDER")
    self.rim:SetTexture(Media("rim"))
    self.rim:SetPoint("CENTER")

    self.outer = NewRing(m)
    self.inner = NewRing(m)
    self.outer.frame:SetFrameLevel(lvl + 3)
    self.inner.frame:SetFrameLevel(lvl + 3)

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
    self.fallback:Hide()

    -- Balken-Modus
    local bf = CreateFrame("Frame", nil, m)
    bf:SetFrameLevel(lvl + 3)
    self.barFrame = bf
    self.barBack = bf:CreateTexture(nil, "BACKGROUND")
    self.bar = CreateFrame("StatusBar", nil, bf)
    self.barEmpty = self.bar:CreateTexture(nil, "BACKGROUND")
    self.barEmpty:SetAllPoints()
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

    self.decorTex = {}
    self.activeDecor = {}
    self.flashAlpha = 0
    self.elapsed = 0

    f:SetScript("OnUpdate", function(_, elapsed)
        D.elapsed = D.elapsed + elapsed
        if D.elapsed < UPDATE_RATE then return end
        D.elapsed = 0
        D:Update(GetTime())
    end)
end

function D:SavePosition()
    local p, _, rp, x, y = self.frame:GetPoint()
    ns.db.point = { p or "CENTER", "UIParent", rp or "CENTER", x or 0, y or 0 }
end

-- Layout -------------------------------------------------------------------------
local function PlaceText(fs, parent, point, x, y)
    fs:ClearAllPoints()
    fs:SetPoint(point, parent, point, x, y)
end

function D:LayoutBar(S)
    local mods = ns.db.modules
    local W = S * 1.6 * st("barWidth")
    local H1 = max(4, S * 0.2 * st("barHeight"))
    local H2 = (mods.fsr or mods.ticks) and max(3, H1 * 0.45) or 0
    local gap = H2 > 0 and max(2, H1 * 0.15) or 0
    local total = H1 + gap + H2
    self.W, self.H1, self.H2 = W, H1, H2
    self.frame:SetSize(W, total)

    local bf = self.barFrame
    bf:ClearAllPoints(); bf:SetAllPoints(self.frame); bf:Show()
    local pad = max(2, H1 * 0.12)
    self.barBack:ClearAllPoints()
    self.barBack:SetPoint("TOPLEFT", bf, "TOPLEFT", -pad, pad)
    self.barBack:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", pad, -pad)
    self.barBack:SetTexture(BAR_TEX.flat)

    local tex = BAR_TEX[st("barTexture")] or BAR_TEX.smooth
    self.bar:SetStatusBarTexture(tex); self.barEmpty:SetTexture(tex)
    self.bar2:SetStatusBarTexture(tex); self.bar2Empty:SetTexture(tex)
    self.bar:ClearAllPoints()
    self.bar:SetPoint("TOPLEFT", bf, "TOPLEFT"); self.bar:SetPoint("TOPRIGHT", bf, "TOPRIGHT")
    self.bar:SetHeight(H1)
    self.bar:SetReverseFill(not st("outerClockwise"))
    self.bar:SetShown(mods.ring)
    self.bar2:ClearAllPoints()
    self.bar2:SetPoint("BOTTOMLEFT", bf, "BOTTOMLEFT"); self.bar2:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT")
    self.bar2:SetHeight(max(1, H2))
    self.bar2:SetReverseFill(not st("innerClockwise"))
    self.bar2:SetShown(H2 > 0)

    local ts = st("textScale")
    SetFontSize(self.bigText, H1 * 0.62 * ts)
    SetFontSize(self.infoText, max(H2 * 0.95, H1 * 0.4) * ts)
    SetFontSize(self.mp5Text, H1 * 0.5 * ts)
    PlaceText(self.bigText, self.bar, "CENTER", 0, 0)
    PlaceText(self.infoText, self.bar2, "CENTER", 0, 0)
    self.mp5Text:ClearAllPoints()
    self.mp5Text:SetPoint("TOP", bf, "BOTTOM", 0, -pad - 2)
    self.valText:Hide()

    local sp = H1 * 1.6 * st("sparkSize")
    self.spark:SetSize(sp * 0.5, sp)
    self.flash:SetSize(W * 1.2, total * 2.5)
end

function D:LayoutCircle(S, mode)
    local mods = ns.db.modules
    self.barFrame:Hide()
    self.frame:SetSize(S, S)

    local rotate = st("rotateSymbols")
    local outerR = S * st("outerRadius")
    local outerSym = S * 0.075 * st("outerSize")
    local extent = 0
    if mods.ring then
        local kind = (mode == "pie") and "pie" or st("outerStyle")
        SetupRing(self.outer, kind, st("outerShape"), st("outerCount"), outerSym, outerR, rotate, st("outerClockwise"))
        extent = outerR + (kind == "pie" and 0 or outerSym * 0.5)
    else
        HideRing(self.outer)
    end
    if mods.fsr or mods.ticks then
        local innerSym = S * 0.055 * st("innerSize")
        local innerR = S * st("innerRadius")
        if mode == "pie" then                       -- in der Torte: Ring außen herum
            innerR = outerR + innerSym * 0.5 + S * 0.04
        end
        SetupRing(self.inner, st("innerStyle"), st("innerShape"), st("innerCount"), innerSym, innerR, rotate, st("innerClockwise"))
        extent = max(extent, innerR + innerSym * 0.5)
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
    self.fallback:ClearAllPoints()
    self.fallback:SetPoint("CENTER", self.main, "CENTER", 0, -S * 0.2)

    local ts = st("textScale")
    SetFontSize(self.bigText, S * 0.19 * ts)
    SetFontSize(self.valText, S * 0.095 * ts)
    SetFontSize(self.infoText, S * 0.11 * ts)
    SetFontSize(self.mp5Text, S * 0.085 * ts)
    PlaceText(self.bigText, self.front, "CENTER", 0, S * 0.04 * ts)
    PlaceText(self.valText, self.front, "CENTER", 0, S * 0.17 * ts)
    PlaceText(self.infoText, self.front, "CENTER", 0, -S * 0.10 * ts)
    PlaceText(self.mp5Text, self.front, "CENTER", 0, -S * 0.20 * ts)
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
        self:LayoutBar(S)
    else
        self:LayoutCircle(S, db.mode)
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
        self.bar2Empty:SetVertexColor(er, eg, eb, ea)
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
        t:SetPoint("CENTER", self.frame, "CENTER", (d.x or 0) * S * kx, (d.y or 0) * S)
        t:SetAlpha(d.alpha or 1)
        t:Show()
        self.activeDecor[#self.activeDecor + 1] = { tex = t, def = d, phase = i * 0.7 }
    end
end

function D:Refresh()
    if not self.frame then return end
    self:Layout()
    self:ApplyColors()
    self:ApplyDecor()
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
    self.flashAlpha = 0.6
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

-- Laufende Aktualisierung --------------------------------------------------------
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
    local showSpark = mods.spark and mods.ring and readable and frac > 0 and frac < 1

    if mode == "bar" then
        if mods.ring then
            -- StatusBars dürfen auch geheime Werte anzeigen
            pcall(self.bar.SetMinMaxValues, self.bar, 0, maxMana)
            pcall(self.bar.SetValue, self.bar, cur)
            self.bar:SetStatusBarColor(r, g, b)
        end
        if showSpark then
            local x = self.W * frac
            if not st("outerClockwise") then x = self.W - x end
            self.spark:ClearAllPoints()
            self.spark:SetPoint("CENTER", self.bar, "LEFT", x, 0)
            self.spark:SetAlpha(0.7 + 0.3 * sin(now * 6))
            self.spark:Show()
        else
            self.spark:Hide()
        end
        self.fallback:Hide()
    else
        if mods.ring then
            FillRing(self.outer, frac, r, g, b, er, eg, eb, ea, mr, mg, mb)
        end
        if showSpark then
            local a = math.pi / 2 + (st("outerClockwise") and -1 or 1) * frac * TWO_PI
            local rad = self.outer.radius or S * 0.42
            if self.outer.kind == "pie" then rad = rad * 0.92 end
            self.spark:ClearAllPoints()
            self.spark:SetPoint("CENTER", self.main, "CENTER", cos(a) * rad, sin(a) * rad)
            self.spark:SetAlpha(0.7 + 0.3 * sin(now * 6))
            self.spark:Show()
        else
            self.spark:Hide()
        end
        if not readable and mods.fallback and mods.ring then
            -- Geheime Werte: nur über das StatusBar-Widget anzeigen, nicht rechnen
            pcall(self.fallback.SetMinMaxValues, self.fallback, 0, maxMana)
            pcall(self.fallback.SetValue, self.fallback, cur)
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
            FillRing(self.inner, ifrac, ir, ig, ib, er, eg, eb, state == "idle" and ea * 0.6 or ea, mr, mg, mb)
        end
    end

    -- Rand leuchtet während der 5-Sek.-Regel
    if mode ~= "bar" and mods.rim then
        if state == "fsr" and st("rimFSR") then
            local fr, fg, fb = ns.GetColor("fsr")
            self.rim:SetVertexColor(fr, fg, fb, min(1, st("rimAlpha") + 0.35 + 0.15 * sin(now * 8)))
        else
            local rr, rg, rb = ns.GetColor("rim")
            self.rim:SetVertexColor(rr, rg, rb, st("rimAlpha"))
        end
    end

    -- Text ------------------------------------------------------------------------
    local tm = db.textMode
    if mods.text and tm ~= "none" and mods.ring then
        if readable then
            local pct = floor(frac * 100 + 0.5) .. "%"
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
            if not pcall(self.bigText.SetText, self.bigText, cur) then self.bigText:SetText("") end
            self.valText:SetText("")
        end
        self.bigText:Show(); self.valText:SetShown(mode ~= "bar")
    else
        self.bigText:Hide(); self.valText:Hide()
    end
    self.infoText:SetText(info)
    self.infoText:SetTextColor(ir, ig, ib)
    self.infoText:SetShown(mods.text)
    if mods.text then
        self.mp5Text:SetText(self:MP5Line(now))
        self.mp5Text:Show()
    else
        self.mp5Text:Hide()
    end

    -- Aufblitzen bei Mana-Tick
    if self.flashAlpha > 0 then
        self.flashAlpha = max(0, self.flashAlpha - 0.04)
        local tr, tg, tb = ns.GetColor("tick")
        self.flash:SetVertexColor(tr, tg, tb)
        self.flash:SetAlpha(self.flashAlpha)
    end

    -- Dekorations-Animationen
    if mods.animations then
        local DS, kx = self.decorS or S, self.decorKX or 1
        for _, a in ipairs(self.activeDecor) do
            local d, t = a.def, a.tex
            if d.rotate then RotTexCoord(t, (now * d.rotate) % TWO_PI) end
            if d.bob then
                local off = sin(now * (d.bobSpeed or 1) * math.pi) * d.bob * DS
                t:ClearAllPoints()
                t:SetPoint("CENTER", self.frame, "CENTER", (d.x or 0) * DS * kx, (d.y or 0) * DS + off)
            end
            local alpha = d.alpha or 1
            if d.pulse then
                alpha = alpha * (1 - d.pulse * 0.5 + d.pulse * 0.5 * sin(now * (d.pulseSpeed or 1) * math.pi))
            end
            if d.flicker then
                alpha = alpha * (0.5 + 0.5 * math.abs(sin(now * 13 + a.phase) * sin(now * 7.3)))
            end
            t:SetAlpha(max(0, min(1, alpha)))
        end
    end

    -- Sichtbarkeit bei "bei vollem Mana ausblenden" nachziehen
    if db.hideWhenFull and db.locked then
        local full = readable and frac >= 1 and not T:InFSR(now)
        if full ~= self.lastFull then
            self.lastFull = full
            self:UpdateVisibility()
        end
    end
end

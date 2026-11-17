-- ManaSigil – Anzeige: Mana-Ring, innerer FSR-/Tick-Ring, Hintergrund, Dekoration, Text
local _, ns = ...

local D = {}
ns.Display = D

local UPDATE_RATE = 1 / 40          -- max. 40 Aktualisierungen pro Sekunde
local MAX_PIPS = 240                -- Obergrenze pro Ring
local TWO_PI = math.pi * 2
local sin, cos, floor, max, min = math.sin, math.cos, math.floor, math.max, math.min

local function Media(name) return ns.MEDIA .. name end

local BG_TEX = { disc = "disc", soft = "glow", ring = "rim" }

-- Ringe ------------------------------------------------------------------------
-- Ein Ring besteht aus vielen kleinen Texturen (Symbole). Im Modus "solid" überlappen
-- sich runde Kugeln so dicht, dass ein durchgehender Kreis entsteht.
local function NewRing(parent, sublevel)
    return { parent = parent, sublevel = sublevel, pips = {}, n = 0, cache = {} }
end

local function SetupRing(ring, S, style, shape, count, sizeF, radiusF, baseSize, rotate)
    local radius = S * radiusF
    local size = S * baseSize * sizeF
    local n, tex
    if style == "solid" then
        tex = "sym_solid"
        n = min(MAX_PIPS, max(12, math.ceil(TWO_PI * radius / max(1, size * 0.35))))
        rotate = false
    else
        tex = "sym_" .. shape
        n = min(MAX_PIPS, max(3, floor(count + 0.5)))
    end
    ring.n, ring.solid, ring.radius = n, style == "solid", radius
    ring.cache.key = nil
    for i = 1, n do
        local t = ring.pips[i]
        if not t then
            t = ring.parent:CreateTexture(nil, "ARTWORK", nil, ring.sublevel)
            ring.pips[i] = t
        end
        local a = math.pi / 2 - (i - 0.5) / n * TWO_PI   -- oben beginnend, im Uhrzeigersinn
        t:SetTexture(Media(tex))
        t:SetSize(size, size)
        t:ClearAllPoints()
        t:SetPoint("CENTER", ring.parent, "CENTER", cos(a) * radius, sin(a) * radius)
        t:SetRotation(rotate and (a - math.pi / 2) or 0)
        t:Show()
    end
    for i = n + 1, #ring.pips do ring.pips[i]:Hide() end
end

local function HideRing(ring)
    for i = 1, #ring.pips do ring.pips[i]:Hide() end
    ring.n = 0
end

-- Füllstand anzeigen. Gefüllt = (r,g,b), leer = (er,eg,eb) mit Deckkraft ea.
-- Beim durchgehenden Kreis wird die Leerfarbe deckend mit dem Hintergrund gemischt,
-- damit überlappende Kugeln keine dunklen Flecken bilden.
local function FillRing(ring, frac, r, g, b, er, eg, eb, ea, mixR, mixG, mixB)
    local n = ring.n
    if n == 0 then return end
    local filled = frac * n
    local key = floor(filled * 16 + 0.5)
    local c = ring.cache
    if c.key == key and c.r == r and c.g == g and c.b == b and c.er == er and c.ea == ea and c.mr == mixR then return end
    c.key, c.r, c.g, c.b, c.er, c.ea, c.mr = key, r, g, b, er, ea, mixR

    if ring.solid and mixR then
        er, eg, eb = mixR + (er - mixR) * ea, mixG + (eg - mixG) * ea, mixB + (eb - mixB) * ea
        ea = 1
    end
    for i = 1, n do
        local v = filled - (i - 1)
        local t = ring.pips[i]
        if v >= 1 then
            t:SetVertexColor(r, g, b, 1)
        elseif v > 0 then
            if ring.solid then
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
    return tostring(v)
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
    self.front = CreateFrame("Frame", nil, f); self.front:SetAllPoints(); self.front:SetFrameLevel(lvl + 3)

    local m = self.main
    self.bg = m:CreateTexture(nil, "BACKGROUND")
    self.bg:SetPoint("CENTER")

    self.rim = m:CreateTexture(nil, "BORDER")
    self.rim:SetTexture(Media("rim"))
    self.rim:SetPoint("CENTER")

    self.outer = NewRing(m, 0)
    self.inner = NewRing(m, 1)

    self.spark = m:CreateTexture(nil, "OVERLAY", nil, 1)
    self.spark:SetTexture(Media("glow"))
    self.spark:SetBlendMode("ADD")

    self.flash = m:CreateTexture(nil, "OVERLAY", nil, 0)
    self.flash:SetTexture(Media("glow"))
    self.flash:SetBlendMode("ADD")
    self.flash:SetPoint("CENTER")
    self.flash:SetAlpha(0)

    -- Ersatz-Balken, falls Manawerte im Kampf geheim sind
    self.fallback = CreateFrame("StatusBar", nil, m)
    self.fallback:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    self.fallback:Hide()

    local fr = self.front
    self.bigText  = fr:CreateFontString(nil, "OVERLAY")
    self.valText  = fr:CreateFontString(nil, "OVERLAY")
    self.infoText = fr:CreateFontString(nil, "OVERLAY")

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

-- Layout / Thema -------------------------------------------------------------------
function D:Layout()
    local db, f, st = ns.db, self.frame, ns.GetStyle
    local mods = db.modules
    local S = db.size
    self.S = S
    f:SetSize(S, S)
    f:SetScale(db.scale)
    f:SetAlpha(db.alpha)
    f:ClearAllPoints()
    local p = db.point
    f:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    f:EnableMouse(not db.locked)

    -- Hintergrund und Rand
    local bgShape = st("bgShape")
    self.bg:SetTexture(Media(BG_TEX[bgShape] or "disc"))
    local bgS = S * 0.98 * st("bgSize") * (bgShape == "soft" and 1.25 or 1)
    self.bg:SetSize(bgS, bgS)
    local rimS = S * 2.08 * st("outerRadius") * st("rimSize")
    self.rim:SetSize(rimS, rimS)

    -- Ringe
    local rotate = st("rotateSymbols")
    if mods.ring then
        SetupRing(self.outer, S, st("outerStyle"), st("outerShape"), st("outerCount"),
            st("outerSize"), st("outerRadius"), 0.075, rotate)
    else
        HideRing(self.outer)
    end
    if mods.fsr or mods.ticks then
        SetupRing(self.inner, S, st("innerStyle"), st("innerShape"), st("innerCount"),
            st("innerSize"), st("innerRadius"), 0.055, rotate)
    else
        HideRing(self.inner)
    end

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
    self.bigText:SetPoint("CENTER", self.front, "CENTER", 0, S * 0.03 * ts)
    self.valText:SetPoint("CENTER", self.front, "CENTER", 0, S * 0.17 * ts)
    self.infoText:SetPoint("CENTER", self.front, "CENTER", 0, -S * 0.13 * ts)
end

function D:ApplyColors()
    local mods, st = ns.db.modules, ns.GetStyle
    local br, bgc, bb = ns.GetColor("bg")
    self.bg:SetVertexColor(br, bgc, bb, st("bgAlpha"))
    self.bg:SetShown(mods.background)
    local rr, rg, rb = ns.GetColor("rim")
    self.rim:SetVertexColor(rr, rg, rb, st("rimAlpha"))
    self.rim:SetShown(mods.rim)
    self.spark:SetVertexColor(ns.GetColor("spark"))
    self.fallback:SetStatusBarColor(ns.GetColor("ring"))
    local tr, tg, tb = ns.GetColor("text")
    self.bigText:SetTextColor(tr, tg, tb)
    self.valText:SetTextColor(tr * 0.85, tg * 0.85, tb * 0.85)
    self.outer.cache.key, self.inner.cache.key = nil, nil
end

function D:ApplyDecor()
    for _, t in ipairs(self.decorTex) do t:Hide() end
    wipe(self.activeDecor)

    local db = ns.db
    local list = ns.GetDecor()
    local source = (db.decor ~= "theme" and ns.themes[db.decor]) or ns.GetTheme()
    local override = db.colors.decor
    local hasOverride = type(override) == "table" and override[1] ~= nil
    local base = hasOverride and override or source.colors.decor or { 1, 1, 1 }
    local S = self.S * ns.GetStyle("decorScale")
    self.decorS = S

    for i, d in ipairs(list) do
        local t = self.decorTex[i]
        if not t then
            t = self.back:CreateTexture(nil, "ARTWORK")
            self.decorTex[i] = t
        end
        t:SetParent(d.front and self.front or self.back)
        t:SetDrawLayer("ARTWORK", min(7, i - 1))
        t:SetTexture(Media(d.tex))
        t:SetRotation(0)
        if d.mirror then t:SetTexCoord(1, 0, 0, 1) else t:SetTexCoord(0, 1, 0, 1) end
        t:SetBlendMode(d.blend or "BLEND")
        local c = hasOverride and base or d.color or base
        t:SetVertexColor(c[1], c[2], c[3])
        t:SetSize((d.w or 1) * S, (d.h or 1) * S)
        t:ClearAllPoints()
        t:SetPoint("CENTER", self.frame, "CENTER", (d.x or 0) * S, (d.y or 0) * S)
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

-- Laufende Aktualisierung --------------------------------------------------------
function D:Update(now)
    local db, mods, T = ns.db, ns.db.modules, ns.Tracker
    local S = self.S or db.size
    local cur, maxMana = T:GetMana()
    local readable = ns.Readable(cur) and ns.Readable(maxMana)

    local er, eg, eb = ns.GetColor("empty")
    local ea = ns.GetStyle("emptyAlpha")
    local mr, mg, mb
    if mods.background then mr, mg, mb = ns.GetColor("bg") end

    -- Äußerer Ring: Mana
    local frac = 0
    if readable then
        frac = (maxMana > 0) and (cur / maxMana) or 0
        if frac > 1 then frac = 1 end
        self.fallback:Hide()
        if mods.ring then
            local r, g, b = ns.GetColor("ring")
            FillRing(self.outer, frac, r, g, b, er, eg, eb, ea, mr, mg, mb)
        end
        if mods.spark and mods.ring and frac > 0 and frac < 1 then
            local a = math.pi / 2 - frac * TWO_PI
            local rad = self.outer.radius or S * 0.42
            self.spark:ClearAllPoints()
            self.spark:SetPoint("CENTER", self.main, "CENTER", cos(a) * rad, sin(a) * rad)
            self.spark:SetAlpha(0.7 + 0.3 * sin(now * 6))
            self.spark:Show()
        else
            self.spark:Hide()
        end
    else
        -- Geheime Werte: nur über das StatusBar-Widget anzeigen, nicht rechnen
        self.spark:Hide()
        if mods.ring then
            local r, g, b = ns.GetColor("ring")
            FillRing(self.outer, 0, r, g, b, er, eg, eb, ea, mr, mg, mb)
        end
        pcall(self.fallback.SetMinMaxValues, self.fallback, 0, maxMana)
        pcall(self.fallback.SetValue, self.fallback, cur)
        self.fallback:Show()
    end

    -- Innerer Ring: 5-Sekunden-Regel bzw. Tick-Timer
    local info, ir, ig, ib = "", 1, 1, 1
    if mods.fsr and T:InFSR(now) then
        local rem = T:FSRRemaining(now)
        ir, ig, ib = ns.GetColor("fsr")
        FillRing(self.inner, rem / T.FSR_DURATION, ir, ig, ib, er, eg, eb, ea, mr, mg, mb)
        info = string.format("%.1f", rem)
    elseif mods.ticks and (not readable or frac < 1) and T:TickProgress(now) then
        ir, ig, ib = ns.GetColor("tick")
        FillRing(self.inner, T:TickProgress(now), ir, ig, ib, er, eg, eb, ea, mr, mg, mb)
        if self.tickShownUntil and now < self.tickShownUntil and T.tickAmount then
            info = "+" .. ShortNumber(T.tickAmount)
        end
    elseif mods.fsr or mods.ticks then
        ir, ig, ib = ns.GetColor("tick")
        FillRing(self.inner, 0, ir, ig, ib, er, eg, eb, ea * 0.6, mr, mg, mb)
    end

    -- Text
    if mods.text and db.textMode ~= "none" then
        if readable then
            local pct = floor(frac * 100 + 0.5) .. "%"
            if db.textMode == "percent" then
                self.bigText:SetText(pct); self.valText:SetText("")
            elseif db.textMode == "value" then
                self.bigText:SetText(ShortNumber(cur)); self.valText:SetText("")
            else
                self.bigText:SetText(pct); self.valText:SetText(ShortNumber(cur))
            end
        else
            if not pcall(self.bigText.SetText, self.bigText, cur) then self.bigText:SetText("") end
            self.valText:SetText("")
        end
        self.infoText:SetText(info)
        self.infoText:SetTextColor(ir, ig, ib)
        self.bigText:Show(); self.valText:Show(); self.infoText:Show()
    else
        self.bigText:Hide(); self.valText:Hide()
        self.infoText:SetText(info); self.infoText:SetTextColor(ir, ig, ib)
        self.infoText:SetShown(mods.text)
    end

    -- Aufblitzen bei Mana-Tick
    if self.flashAlpha > 0 then
        self.flashAlpha = max(0, self.flashAlpha - 0.04)
        local r, g, b = ns.GetColor("tick")
        self.flash:SetVertexColor(r, g, b)
        self.flash:SetAlpha(self.flashAlpha)
    end

    -- Dekorations-Animationen
    if mods.animations then
        local DS = self.decorS or S
        for _, a in ipairs(self.activeDecor) do
            local d, t = a.def, a.tex
            if d.rotate then t:SetRotation((now * d.rotate) % TWO_PI) end
            if d.bob then
                local off = sin(now * (d.bobSpeed or 1) * math.pi) * d.bob * DS
                t:ClearAllPoints()
                t:SetPoint("CENTER", self.frame, "CENTER", (d.x or 0) * DS, (d.y or 0) * DS + off)
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

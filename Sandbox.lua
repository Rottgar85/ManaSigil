-- ManaSigil – Sandbox: grüner Bereich um die Anzeige, solange die Einstellungen offen sind.
-- Darin lassen sich Zahlen, Timer, Dekoration und die ganze Anzeige mit der Maus verschieben.
-- Die Teile bleiben dabei innerhalb des grünen Rahmens.
local _, ns = ...
local L = ns.L

local SB = {}
ns.Sandbox = SB

local MARGIN = 30           -- Platz um die Anzeige herum (Pixel)
local MIN_W, MIN_H = 44, 16 -- Mindestgröße der Griffe (leere Texte wären sonst unsichtbar)

-- Gespeicherte Verschiebung eines Teils im aktuellen Modus
function SB:Offset(key)
    local db = ns.db
    local lay = db and db.layout and db.layout[db.mode]
    local o = lay and lay[key]
    if o then return o[1] or 0, o[2] or 0 end
    return 0, 0
end

local function SetOffset(key, x, y)
    local db = ns.db
    db.layout = db.layout or {}
    db.layout[db.mode] = db.layout[db.mode] or {}
    if x == 0 and y == 0 then db.layout[db.mode][key] = nil else db.layout[db.mode][key] = { x, y } end
end

-- Verschiebbare Teile ---------------------------------------------------------------
local function D() return ns.Display end
local function Mods() return ns.db.modules end

-- Rechteck eines Bildschirmelements: links, unten, rechts, oben (oder nil)
-- Geheime Werte (z. B. die Breite eines Textes mit geheimem Manawert) gelten als unbekannt
local function Rect(r)
    if not r then return nil end
    local ok, l, b, w, h = pcall(r.GetRect, r)
    if not ok or not (ns.Readable(l) and ns.Readable(b) and ns.Readable(w) and ns.Readable(h)) then return nil end
    return l, b, l + w, b + h
end

-- Texte: Größe eines Textes mit geheimem Inhalt ist selbst geheim. Dann misst ein
-- unsichtbarer Platzhalter an derselben Stelle (Größe nach der Schriftgröße geschätzt).
local function TextRect(p)
    local fs = p.regions()[1]
    local l, b, r, t = Rect(fs)
    if l then return l, b, r, t end
    return Rect(p.probe)
end

local function TextPart(key, field, extra)
    return {
        key = key, text = true,
        regions = function() return { D()[field] } end,
        shown = function()
            return Mods().text and D()[field]:IsShown() and (not extra or extra())
        end,
        rect = TextRect,
    }
end

local function Union(rects)
    local L1, B1, R1, T1
    for _, r in ipairs(rects) do
        if r[1] then
            L1 = L1 and math.min(L1, r[1]) or r[1]
            B1 = B1 and math.min(B1, r[2]) or r[2]
            R1 = R1 and math.max(R1, r[3]) or r[3]
            T1 = T1 and math.max(T1, r[4]) or r[4]
        end
    end
    return L1, B1, R1, T1
end

SB.parts = {
    TextPart("bigText", "bigText"),
    TextPart("valText", "valText"),
    TextPart("infoText", "infoText"),
    TextPart("mp5Text", "mp5Text", function() return ns.GetStyle("mp5Mode") ~= "off" end),
    { key = "timer",
      regions = function()
          if ns.db.mode == "bar" then return { D().bar2 } end
          return { D().inner.frame }
      end,
      shown = function()
          if not (Mods().fsr or Mods().ticks) then return false end
          if ns.db.mode == "bar" then return D().bar2:IsShown() end
          return true
      end,
      rect = function()
          local d = D()
          if ns.db.mode == "bar" then return Rect(d.bar2) end
          -- innerer Ring: Mittelpunkt des Ring-Rahmens ± Radius
          local l, b, r, t = Rect(d.inner.frame)
          if not l then return nil end
          local cx, cy, e = (l + r) / 2, (b + t) / 2, d.innerExtent or 10
          return cx - e, cy - e, cx + e, cy + e
      end },
    { key = "decor",
      decor = true,
      shown = function() return Mods().decor and #D().activeDecor > 0 end,
      rect = function()
          local rects = {}
          for _, a in ipairs(D().activeDecor) do rects[#rects + 1] = { Rect(a.tex) } end
          return Union(rects)
      end },
}

-- Ausgangslage merken und Verschiebung anwenden ---------------------------------------
-- Vor dem Layout alles zurück auf die Ausgangslage (sonst addieren sich Verschiebungen)
function SB:Restore()
    for _, p in ipairs(self.parts) do
        if p.base then
            for i, r in ipairs(p.regs) do
                r:ClearAllPoints()
                for _, pt in ipairs(p.base[i]) do r:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
            end
        end
        p.base, p.regs = nil, nil
    end
end

local function ApplyPart(p)
    if p.decor then
        D():ApplyDecor()             -- die Dekoration rechnet ihre Verschiebung selbst ein
        return
    end
    if not p.base then return end
    local ox, oy = SB:Offset(p.key)
    for i, r in ipairs(p.regs) do
        r:ClearAllPoints()
        for _, pt in ipairs(p.base[i]) do r:SetPoint(pt[1], pt[2], pt[3], pt[4] + ox, pt[5] + oy) end
    end
    -- Platzhalter des Textes folgt mit denselben Ankerpunkten
    if p.probe then
        p.probe:ClearAllPoints()
        for _, pt in ipairs(p.base[1] or {}) do p.probe:SetPoint(pt[1], pt[2], pt[3], pt[4] + ox, pt[5] + oy) end
    end
end
SB.ApplyPart = ApplyPart

-- Nach dem Layout: Ausgangslage erfassen, Sandbox-Größe bestimmen, Verschiebungen anwenden
function SB:Apply()
    local rects = { { Rect(D().frame) } }
    for _, p in ipairs(self.parts) do
        if not p.decor then
            p.regs = p.regions()
            p.base = {}
            for i, r in ipairs(p.regs) do
                local pts = {}
                for n = 1, (r:GetNumPoints() or 0) do pts[n] = { r:GetPoint(n) } end
                p.base[i] = pts
            end
            if p.text then
                if not p.probe then
                    p.probe = CreateFrame("Frame", nil, D().front)
                    p.probe:EnableMouse(false)
                end
                local _, size = p.regs[1]:GetFont()
                size = (ns.Readable(size) and size) or 14
                p.probe:SetSize(size * 3.2, size * 1.25)
                p.probe:ClearAllPoints()
                for _, pt in ipairs(p.base[1]) do p.probe:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
            end
        end
        if p.shown() then
            -- Ausgangslage (ohne Verschiebung) bestimmt die Größe der Sandbox
            local ox, oy = 0, 0
            if p.decor then ox, oy = self:Offset("decor") end
            local l, b, r, t = p.rect(p)
            if l then rects[#rects + 1] = { l - ox, b - oy, r - ox, t - oy } end
        end
    end
    self.box = { Union(rects) }
    for _, p in ipairs(self.parts) do
        if not p.decor then ApplyPart(p) end
    end
    self:Place()
end

-- Sandbox-Fenster -------------------------------------------------------------------------
local GREEN = { 0.2, 0.9, 0.3 }

local function Border(f, a)
    local edges = {}
    for i = 1, 4 do
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], a)
        edges[i] = t
    end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(2)
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(2)
    edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(2)
    edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(2)
end

local function ShowTip(owner, title, text)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:AddLine(title, GREEN[1], GREEN[2], GREEN[3])
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
end

function SB:Build()
    local f = CreateFrame("Frame", nil, D().frame)
    f:SetFrameLevel(D().frame:GetFrameLevel() + 30)
    self.frame = f
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 0.10)
    Border(f, 0.9)

    -- Titelleiste: zieht die ganze Anzeige
    local bar = CreateFrame("Button", nil, f)
    bar:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 0)
    bar:SetHeight(18)
    local bbg = bar:CreateTexture(nil, "BACKGROUND")
    bbg:SetAllPoints()
    bbg:SetColorTexture(GREEN[1] * 0.6, GREEN[2] * 0.6, GREEN[3] * 0.6, 0.85)
    local title = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("CENTER")
    title:SetText(L.SB_TITLE)
    bar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bar:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then D().frame:StartMoving() end
    end)
    bar:SetScript("OnMouseUp", function(_, button)
        D().frame:StopMovingOrSizing()
        if button == "RightButton" then
            ns.db.point = { "CENTER", "UIParent", "CENTER", 0, -160 }
            D():Refresh()
        else
            D():SavePosition()
        end
    end)
    bar:SetScript("OnEnter", function(s) ShowTip(s, L.SB_WHOLE, L.SB_WHOLE_TIP) end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.titleBar = bar

    self.handles = {}
    for _, p in ipairs(self.parts) do
        local h = CreateFrame("Button", nil, f)
        h:SetFrameLevel(f:GetFrameLevel() + 2)
        local hb = h:CreateTexture(nil, "BACKGROUND")
        hb:SetAllPoints()
        hb:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 0.18)
        Border(h, 0.7)
        local lbl = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("BOTTOMLEFT", h, "TOPLEFT", 2, 1)
        lbl:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
        h.label = lbl
        h.part = p
        h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        h:SetScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" then return end
            local sc = f:GetEffectiveScale() or 1
            local cx, cy = GetCursorPosition()
            local ox, oy = SB:Offset(p.key)
            SB.drag = { part = p, x = cx / sc, y = cy / sc, ox = ox, oy = oy }
        end)
        h:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" then
                SetOffset(p.key, 0, 0); ApplyPart(p)
            end
            SB.drag = nil
        end)
        h:SetScript("OnEnter", function(s) ShowTip(s, L.SB_PARTS[p.key] or p.key, L.SB_PART_TIP) end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.handles[#self.handles + 1] = h
    end

    f:SetScript("OnUpdate", function()
        -- Fehler nur einmal melden statt in jedem Bild
        local ok, err = pcall(SB.OnUpdate, SB)
        if not ok and not SB.errorShown then
            SB.errorShown = true
            ns.ReportError("Sandbox", err)
        end
    end)
    f:Hide()
end

-- Sandbox an die Anzeige hängen (Größe = Ausgangslage aller Teile + Rand)
function SB:Place()
    local f, box = self.frame, self.box
    if not f or not box or not box[1] then return end
    local fl, fb = D().frame:GetRect()
    if not fl then return end
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", D().frame, "BOTTOMLEFT", box[1] - fl - MARGIN, box[2] - fb - MARGIN)
    f:SetSize(box[3] - box[1] + 2 * MARGIN, box[4] - box[2] + 2 * MARGIN)
end

-- Teil verschieben, aber nie über den grünen Rand hinaus
local function MoveClamped(p, x, y)
    SetOffset(p.key, x, y); ApplyPart(p)
    local l, b, r, t = p.rect(p)
    local sl, sb, sr, st = Rect(SB.frame)
    if not (l and sl) then return end
    local dx, dy = 0, 0
    if l < sl then dx = sl - l elseif r > sr then dx = sr - r end
    if b < sb then dy = sb - b elseif t > st then dy = st - t end
    if dx ~= 0 or dy ~= 0 then
        SetOffset(p.key, x + dx, y + dy); ApplyPart(p)
    end
end
SB.MoveClamped = MoveClamped

function SB:OnUpdate()
    local drag = self.drag
    if drag then
        if not IsMouseButtonDown or IsMouseButtonDown("LeftButton") then
            local sc = self.frame:GetEffectiveScale() or 1
            local cx, cy = GetCursorPosition()
            MoveClamped(drag.part, math.floor(drag.ox + cx / sc - drag.x + 0.5), math.floor(drag.oy + cy / sc - drag.y + 0.5))
        else
            self.drag = nil
        end
    end
    -- Griffe folgen ihren Teilen
    local sl, sb = Rect(self.frame)
    for _, h in ipairs(self.handles) do
        local p = h.part
        local l, b, r, t
        if sl and p.shown() then l, b, r, t = p.rect(p) end
        if l then
            local w, hh = math.max(MIN_W, r - l), math.max(MIN_H, t - b)
            local cx, cy = (l + r) / 2, (b + t) / 2
            h:ClearAllPoints()
            h:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", cx - w / 2 - sl, cy - hh / 2 - sb)
            h:SetSize(w, hh)
            h.label:SetText(L.SB_PARTS[p.key] or p.key)
            h:Show()
        else
            h:Hide()
        end
    end
end

-- Sichtbar, solange die Einstellungen offen sind und die Anzeige zu sehen ist
function SB:UpdateVisibility()
    if not self.frame then return end
    local on = ns.db.sandbox ~= false and ns.Options and ns.Options:IsOpen() and D().frame:IsShown()
    on = on and true or false
    if on == (self.frame:IsShown() and true or false) then return end
    self.frame:SetShown(on)
    -- über das Einstellungsfenster heben, damit man die Anzeige dort sieht und greifen kann
    D().frame:SetFrameStrata(on and "DIALOG" or "MEDIUM")
    if on then
        D():Refresh()                -- Maße erst jetzt sicher bekannt: Sandbox neu ausmessen
    else
        self.drag = nil
    end
end

-- Alle Verschiebungen des aktuellen Modus zurücksetzen
function SB:ResetAll()
    if ns.db.layout then ns.db.layout[ns.db.mode] = nil end
    D():Refresh()
end

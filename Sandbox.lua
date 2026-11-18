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

-- Kreis um den Mittelpunkt eines Rahmens (Ringe liegen über die ganze Anzeige)
local function CircleRect(frame, e)
    local l, b, r, t = Rect(frame)
    if not l then return nil end
    local cx, cy = (l + r) / 2, (b + t) / 2
    return cx - e, cy - e, cx + e, cy + e
end

local function IsBar() return ns.db.mode == "bar" end

SB.parts = {
    { key = "background",
      regions = function() return { IsBar() and D().barBack or D().bg } end,
      shown = function() return Mods().background end,
      rect = function() return Rect(IsBar() and D().barBack or D().bg) end },
    { key = "rim",
      regions = function() return IsBar() and {} or { D().rim } end,
      shown = function() return not IsBar() and Mods().rim end,
      rect = function() return Rect(D().rim) end },
    { key = "mana",
      regions = function()
          local d = D()
          if IsBar() then return { d.bar } end
          return { d.outer.frame, d.pieFrame, d.gapFrame, d.fallback }
      end,
      shown = function() return Mods().ring end,
      rect = function()
          local d = D()
          if IsBar() then return Rect(d.bar) end
          return CircleRect(d.outer.frame, d.outerExtent or 20)
      end },
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
          return CircleRect(d.inner.frame, d.innerExtent or 10)   -- innerer Ring
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

-- Ankerpunkte sicher erfassen und setzen ---------------------------------------------
local VALID_POINT = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
                      RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }

-- Liest die Ankerpunkte eines Teils. Unbrauchbare Angaben (fehlender Punkt, geheime oder
-- fehlende Abstände) werden ersetzt; ohne brauchbare Punkte füllt das Teil seinen Eltern-Rahmen.
local function CapturePoints(r)
    -- Die Anzeige schreibt ihre Ankerpunkte selbst mit (D:GetPins). Beim Spiel nachfragen
    -- geht nicht: bei Texten mit geheimem Inhalt sind sogar die Ankerpunkte geheim.
    local pts = {}
    local src = (D().GetPins and D():GetPins(r)) or (r.GetPins and r:GetPins()) or {}
    for _, pt in ipairs(src) do
        local point, rel, relPoint, x, y = pt[1], pt[2], pt[3], pt[4], pt[5]
        if type(point) == "string" and VALID_POINT[point] then
            if type(relPoint) ~= "string" or not VALID_POINT[relPoint] then relPoint = point end
            if type(rel) ~= "table" then rel = r:GetParent() end
            if type(x) ~= "number" then x = 0 end
            if type(y) ~= "number" then y = 0 end
            pts[#pts + 1] = { point, rel, relPoint, x, y }
        end
    end
    if #pts == 0 then
        local parent = r:GetParent()
        pts = { { "TOPLEFT", parent, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0 } }
    end
    return pts
end

SB.CapturePoints = CapturePoints

-- Setzt die Ankerpunkte mit Verschiebung; ein Fehler betrifft nur dieses Teil
local function SetPoints(r, pts, ox, oy, key)
    r:ClearAllPoints()
    for _, pt in ipairs(pts) do
        local ok, err = pcall(r.SetPoint, r, pt[1], pt[2], pt[3], pt[4] + ox, pt[5] + oy)
        if not ok then
            if not SB.pointErrorShown then
                SB.pointErrorShown = true
                ns.ReportError("Sandbox " .. tostring(key), err)
            end
            pcall(r.SetPoint, r, "CENTER", r:GetParent(), "CENTER", ox, oy)
            return
        end
    end
end

-- Ausgangslage merken und Verschiebung anwenden ---------------------------------------
-- Vor dem Layout alles zurück auf die Ausgangslage (sonst addieren sich Verschiebungen)
function SB:Restore()
    for _, p in ipairs(self.parts) do
        if p.base then
            for i, r in ipairs(p.regs) do SetPoints(r, p.base[i], 0, 0, p.key) end
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
    for i, r in ipairs(p.regs) do SetPoints(r, p.base[i], ox, oy, p.key) end
    -- Platzhalter des Textes folgt mit denselben Ankerpunkten
    if p.probe and p.base[1] then SetPoints(p.probe, p.base[1], ox, oy, p.key) end
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
                p.base[i] = CapturePoints(r)
            end
            if p.text then
                if not p.probe then
                    p.probe = CreateFrame("Frame", nil, D().front)
                    p.probe:EnableMouse(false)
                end
                local _, size = p.regs[1]:GetFont()
                size = (ns.Readable(size) and size) or 14
                p.probe:SetSize(size * 3.2, size * 1.25)
                if p.base[1] then SetPoints(p.probe, p.base[1], 0, 0, p.key) end
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
    return edges
end

-- Griff hervorheben: beim Überfahren und Ziehen deutlich, sonst nur ein feiner Rahmen
local function Highlight(h, level)
    local fillA, edgeA = 0.0, 0.35
    if level == "hover" then fillA, edgeA = 0.15, 0.9 elseif level == "drag" then fillA, edgeA = 0.25, 1 end
    h.fill:SetAlpha(fillA)
    for _, e in ipairs(h.edges) do e:SetAlpha(edgeA) end
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
    -- Ebene der Griffe: Texte über Timer über Dekoration, damit ein Klick auf eine
    -- Schrift immer die Schrift greift (die Deko ist großflächig und liegt darunter)
    local LEVEL = { background = 1, rim = 2, decor = 3, mana = 4, timer = 5 }
    for _, p in ipairs(self.parts) do
        local h = CreateFrame("Button", nil, f)
        h:SetFrameLevel(f:GetFrameLevel() + (LEVEL[p.key] or 7))
        local hb = h:CreateTexture(nil, "BACKGROUND")
        hb:SetAllPoints()
        hb:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 1)
        h.fill = hb
        h.edges = Border(h, 1)
        -- Namensschild: liegt über allen Kästchen, damit sich auch verdeckte Teile
        -- (Hintergrund, Rand, Mana-Ring unter den Zahlen) greifen lassen
        local tab = CreateFrame("Button", nil, f)
        tab:SetFrameLevel(f:GetFrameLevel() + 12)
        local tb = tab:CreateTexture(nil, "BACKGROUND")
        tb:SetAllPoints()
        tb:SetColorTexture(0, 0, 0, 0.75)
        tab.edges = Border(tab, 0.8)
        local lbl = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("CENTER")
        lbl:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
        tab.label = lbl
        h.tab, h.label = tab, lbl
        h.part = p
        for _, g in ipairs({ h, tab }) do
        g:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        g:SetScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" then return end
            local sc = f:GetEffectiveScale() or 1
            local cx, cy = GetCursorPosition()
            local ox, oy = SB:Offset(p.key)
            SB.drag = { part = p, x = cx / sc, y = cy / sc, ox = ox, oy = oy }
            GameTooltip:Hide()
        end)
        g:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" then
                SetOffset(p.key, 0, 0); ApplyPart(p)
            end
            SB:EndDrag()
        end)
        g:SetScript("OnEnter", function(s)
            h.hover = true
            if not SB.drag then ShowTip(s, L.SB_PARTS[p.key] or p.key, L.SB_PART_TIP) end
        end)
        g:SetScript("OnLeave", function() h.hover = nil; GameTooltip:Hide() end)
        end
        Highlight(h)
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
            self:EndDrag()
        end
    end
    self:Dim()
    -- Griffe folgen ihren Teilen
    local sl, sb = Rect(self.frame)
    local tabs = {}
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
            local dragging = self.drag and self.drag.part == p
            Highlight(h, dragging and "drag" or (h.hover and not self.drag and "hover") or nil)
            -- beim Ziehen treten die anderen Griffe zurück
            local a = (self.drag and not dragging) and 0.25 or 1
            h:SetAlpha(a)
            h:Show()
            -- Schild oben links am Teil; überdeckt es ein anderes, rückt es nach rechts bzw. unten
            local lw = h.label:GetStringWidth()
            local tw, th = (ns.Readable(lw) and lw or 60) + 10, 14
            local x0 = cx - w / 2 - sl
            local tx, ty = x0, cy + hh / 2 - sb
            local function hits()
                for _, o in ipairs(tabs) do
                    if tx < o[1] + o[3] + 2 and tx + tw + 2 > o[1] and ty < o[2] + o[4] + 2 and ty + th + 2 > o[2] then
                        return true
                    end
                end
            end
            local tries = 0
            while hits() and tries < 12 do
                tries = tries + 1
                tx = tx + 40
                if tries % 4 == 0 then tx, ty = x0, ty - th - 2 end
            end
            tabs[#tabs + 1] = { tx, ty, tw, th }
            h.tab:ClearAllPoints()
            h.tab:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", tx, ty)
            h.tab:SetSize(tw, th)
            h.tab:SetAlpha(a)
            h.tab:Show()
        else
            h:Hide(); h.tab:Hide()
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
        self:EndDrag()
    end
end

-- Beim Ziehen rückt alles andere in den Hintergrund ---------------------------------
local DIM = 0.25

-- Teile der Anzeige, die nicht verschoben werden (Mana-Ring/-Balken, Hintergrund ...)
local function BaseRegions()
    local d = D()
    return { d.spark }
end

local function PartRegions(p)
    if p.decor then
        local t = {}
        for _, a in ipairs(D().activeDecor) do t[#t + 1] = a.tex end
        return t
    end
    local regs = p.regions()
    if p.key == "bigText" then regs[#regs + 1] = D().warnHolder end
    return regs
end

function SB:Dim()
    local drag = self.drag
    if not drag then return end
    for _, r in ipairs(BaseRegions()) do r:SetAlpha(DIM) end
    for _, p in ipairs(self.parts) do
        local a = (p == drag.part) and 1 or DIM
        for _, r in ipairs(PartRegions(p)) do r:SetAlpha(a) end
    end
    self.dimmed = true
end

-- Ziehen beenden: alles wieder voll sichtbar (Texte und Deko setzt die Anzeige
-- ohnehin in jedem Bild neu, der Rest wird hier zurückgesetzt)
function SB:EndDrag()
    self.drag = nil
    if not self.dimmed then return end
    self.dimmed = nil
    for _, r in ipairs(BaseRegions()) do r:SetAlpha(1) end
    for _, p in ipairs(self.parts) do
        for _, r in ipairs(PartRegions(p)) do r:SetAlpha(1) end
    end
    for _, h in ipairs(self.handles or {}) do h:SetAlpha(1); h.tab:SetAlpha(1) end
end

function SB:IsActive()
    return self.frame ~= nil and self.frame:IsShown() == true
end

-- Alle Verschiebungen des aktuellen Modus zurücksetzen
function SB:ResetAll()
    if ns.db.layout then ns.db.layout[ns.db.mode] = nil end
    D():Refresh()
end

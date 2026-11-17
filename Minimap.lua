-- ManaSigil – Minimap-Button (ohne Bibliotheken)
-- Linksklick: Anzeige an/aus · Rechtsklick: Optionen · Ziehen: um die Minimap verschieben
local _, ns = ...

local M = {}
ns.Minimap = M

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

-- Position auf dem Minimap-Rand (rund oder eckig)
function M:UpdatePosition()
    local b = self.button
    if not b then return end
    local angle = math.rad(ns.db.minimap.angle or 215)
    local x, y = math.cos(angle), math.sin(angle)
    local w = (Minimap:GetWidth() / 2) + 5
    local h = (Minimap:GetHeight() / 2) + 5
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
        -- auf den Rand des Quadrats projizieren
        local m = math.max(math.abs(x), math.abs(y))
        x, y = x / m, y / m
        w, h = w - 5, h - 5
    end
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", x * w, y * h)
end

function M:Refresh()
    local b = self.button
    if not b then return end
    b:SetShown(not ns.db.minimap.hide)
    local r, g, bl = ns.GetColor("ring")
    if ns.db.enabled then
        b.icon:SetDesaturated(false)
        b.icon:SetVertexColor(r, g, bl)
    else
        b.icon:SetDesaturated(true)
        b.icon:SetVertexColor(0.5, 0.5, 0.5)
    end
    self:UpdatePosition()
end

local function OnDragUpdate(self)
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    ns.db.minimap.angle = math.deg(atan2(py - my, px - mx)) % 360
    M:UpdatePosition()
end

function M:Build()
    -- Globaler Name, damit Minimap-Sammler (z. B. MBB) den Button finden
    local b = CreateFrame("Button", "ManaSigilMinimapButton", Minimap)
    self.button = b
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(22, 22)
    bg:SetPoint("CENTER")
    bg:SetVertexColor(0, 0, 0, 0.8)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.MEDIA .. "sigil")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    b.icon = icon

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns.Options:Open()
        else
            ns.ToggleEnabled()
        end
    end)
    b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff7fb2ffMana|r|cffffd166Sigil|r")
        GameTooltip:AddLine("Anzeige: " .. (ns.db.enabled and "|cff40ff40an|r" or "|cffff4040aus|r"), 1, 1, 1)
        GameTooltip:AddLine("Thema: " .. ns.GetTheme().name, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Linksklick: an/aus", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Rechtsklick: Optionen", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Ziehen: Button verschieben", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self:Refresh()
end

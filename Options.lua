-- ManaSigil – Optionsmenü (Spieloptionen > AddOns > ManaSigil)
local _, ns = ...

local O = {}
ns.Options = O
O.widgets = {}

local LABEL_W = 170   -- Breite der Beschriftungsspalte

local function Changed()
    ns.Display:Refresh()
end

-- Bausteine ----------------------------------------------------------------------
local function Header(parent, text, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 16, y - 22)
    line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    return fs
end

local function Label(parent, text, x, y, template)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function Check(parent, text, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y + 4)
    local lbl = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    lbl:SetText(text)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); Changed() end)
    cb.Refresh = function(self) self:SetChecked(get()) end
    O.widgets[#O.widgets + 1] = cb
    return cb
end

-- Auswahl mit < > Pfeilen
local function Cycler(parent, text, x, y, valuesFn, labelFn, get, set)
    Label(parent, text, x, y)
    local prev = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    prev:SetSize(26, 22); prev:SetPoint("TOPLEFT", x + LABEL_W, y + 4); prev:SetText("<")
    local box = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    box:SetPoint("LEFT", prev, "RIGHT", 6, 0); box:SetWidth(220); box:SetJustifyH("CENTER")
    local nextB = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    nextB:SetSize(26, 22); nextB:SetPoint("LEFT", box, "RIGHT", 6, 0); nextB:SetText(">")

    local holder = { Refresh = function() box:SetText(labelFn(get())) end }
    local function Step(dir)
        local vals = valuesFn()
        local cur, idx = get(), 1
        for i, v in ipairs(vals) do if v == cur then idx = i end end
        idx = (idx - 1 + dir) % #vals + 1
        set(vals[idx]); holder.Refresh(); Changed()
    end
    prev:SetScript("OnClick", function() Step(-1) end)
    nextB:SetScript("OnClick", function() Step(1) end)
    O.widgets[#O.widgets + 1] = holder
    return holder
end

local function FormatValue(fmt, v)
    if type(fmt) == "function" then return fmt(v) end
    return string.format(fmt, v)
end

local function Slider(parent, text, x, y, minV, maxV, step, fmt, get, set)
    Label(parent, text, x, y)
    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(220, 16)
    s:SetPoint("TOPLEFT", x + LABEL_W + 4, y)
    s:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    local val = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    val:SetPoint("LEFT", s, "RIGHT", 8, 0)
    local updating = false
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        val:SetText(FormatValue(fmt, v))
        if updating then return end
        set(v); Changed()
    end)
    s.Refresh = function()
        updating = true
        s:SetValue(get())
        val:SetText(FormatValue(fmt, get()))
        updating = false
    end
    O.widgets[#O.widgets + 1] = s
    return s
end

local function OpenColorPicker(r, g, b, onChange)
    local function Apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        onChange(nr, ng, nb)
    end
    local function Cancel(prev)
        if type(prev) == "table" then
            onChange(prev.r or r, prev.g or g, prev.b or b)
        else
            onChange(r, g, b)
        end
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = Apply, cancelFunc = Cancel,
        })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r = r, g = g, b = b }
        ColorPickerFrame.func = Apply
        ColorPickerFrame.cancelFunc = Cancel
        ColorPickerFrame:SetColorRGB(r, g, b)
        ShowUIPanel(ColorPickerFrame)
    end
end

local function Swatch(parent, text, key, x, y)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(22, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 3, -3); tex:SetPoint("BOTTOMRIGHT", -3, 3)
    tex:SetColorTexture(1, 1, 1)
    local lbl = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("LEFT", b, "RIGHT", 6, 0)
    lbl:SetText(text)
    local mark = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    mark:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
    b.Refresh = function()
        local r, g, bl = ns.GetColor(key)
        tex:SetColorTexture(r, g, bl)
        mark:SetText(ns.db.colors[key] and "*" or "")   -- * = eigene Farbe
    end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then          -- Rechtsklick: zurück zur Themenfarbe
            ns.db.colors[key] = nil
            b.Refresh(); Changed()
            return
        end
        local r, g, bl = ns.GetColor(key)
        OpenColorPicker(r, g, bl, function(nr, ng, nb)
            ns.db.colors[key] = { nr, ng, nb }
            b.Refresh(); Changed()
        end)
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(text)
        GameTooltip:AddLine("Linksklick: Farbe wählen", 1, 1, 1)
        GameTooltip:AddLine("Rechtsklick: Themenfarbe verwenden", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    O.widgets[#O.widgets + 1] = b
    return b
end

local function Button(parent, text, x, y, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 170, 24)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- Werte-Listen ---------------------------------------------------------------------
local function ThemeValues()
    local t = { "auto" }
    for _, k in ipairs(ns.themeOrder) do t[#t + 1] = k end
    return t
end

local function ThemeLabel(v)
    if v == "auto" then
        local key = ns.classDefaults[ns.PlayerClass() or ""] or "classic"
        return "Automatisch (" .. ns.themes[key].name .. ")"
    end
    return ns.themes[v] and ns.themes[v].name or v
end

local function DecorValues()
    local t = { "theme", "none" }
    for _, k in ipairs(ns.themeOrder) do
        if #ns.themes[k].decor > 0 then t[#t + 1] = k end
    end
    return t
end

local function DecorLabel(v)
    if v == "theme" then return "Wie Thema" end
    if v == "none" then return "Keine" end
    return ns.themes[v] and ns.themes[v].name or v
end

local function ShapeValues()
    local t = { "theme" }
    for _, k in ipairs(ns.shapeOrder) do t[#t + 1] = k end
    return t
end

local function ShapeLabel(which)
    return function(v)
        if v == "theme" then
            local shapes = ns.GetTheme().shapes or {}
            return "Wie Thema (" .. (ns.shapeNames[shapes[which]] or "Leuchtpunkt") .. ")"
        end
        return ns.shapeNames[v] or v
    end
end

local RING_STYLES = { "symbols", "solid" }
local RING_STYLE_LABELS = { symbols = "Einzelne Symbole", solid = "Durchgehender Kreis" }
local BG_SHAPES = { "disc", "soft", "ring" }
local BG_LABELS = { disc = "Scheibe", soft = "Weicher Schein", ring = "Nur Ring" }
local TEXT_MODES = { "percent", "value", "both", "none" }
local TEXT_LABELS = { percent = "Prozent", value = "Manawert", both = "Prozent + Wert", none = "Aus" }

local function Pct(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
local function Times(v) return string.format("%.2fx", v) end

-- Panel ------------------------------------------------------------------------------
function O:Build()
    local panel = CreateFrame("Frame")
    panel.name = "ManaSigil"
    self.panel = panel

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", -28, 4)
    local c = CreateFrame("Frame", nil, scroll)
    c:SetSize(620, 100)
    scroll:SetScrollChild(c)

    local db = function() return ns.db end
    local style = function() return ns.db.style end
    local function SG(key) return function() return style()[key] end end
    local function SS(key) return function(v) style()[key] = v end end
    local y = -12

    local title = c:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, y)
    title:SetText("|cff7fb2ffMana|r|cffffd166Sigil|r")
    Label(c, "Mana-Ring, 5-Sekunden-Regel und Tick-Timer – alles frei gestaltbar. Der Ring bleibt sichtbar, solange dieses Fenster offen ist.",
        16, y - 30, "GameFontHighlightSmall")
    y = y - 60

    -- Thema ----------------------------------------------------------------
    Header(c, "Thema", y); y = y - 34
    Cycler(c, "Thema (Farben/Symbole)", 20, y, ThemeValues, ThemeLabel,
        function() return db().theme end, function(v) db().theme = v end)
    y = y - 30
    Cycler(c, "Dekoration", 20, y, DecorValues, DecorLabel,
        function() return db().decor end, function(v) db().decor = v end)
    y = y - 30
    Slider(c, "Dekorationsgröße", 20, y, 0.3, 2.0, 0.05, Times, SG("decorScale"), SS("decorScale"))
    y = y - 40

    -- Gesamtgröße -----------------------------------------------------------
    Header(c, "Größe & Deckkraft", y); y = y - 34
    Slider(c, "Grundgröße", 20, y, 60, 300, 5, "%d px",
        function() return db().size end, function(v) db().size = v end)
    y = y - 28
    Slider(c, "Skalierung", 20, y, 0.5, 2.0, 0.05, Times,
        function() return db().scale end, function(v) db().scale = v end)
    y = y - 28
    Slider(c, "Gesamt-Deckkraft", 20, y, 0.1, 1.0, 0.05, Pct,
        function() return db().alpha end, function(v) db().alpha = v end)
    y = y - 40

    -- Äußerer Ring ------------------------------------------------------------
    Header(c, "Mana-Ring (außen)", y); y = y - 34
    Cycler(c, "Darstellung", 20, y, function() return RING_STYLES end,
        function(v) return RING_STYLE_LABELS[v] or v end, SG("outerStyle"), SS("outerStyle"))
    y = y - 30
    Cycler(c, "Symbol", 20, y, ShapeValues, ShapeLabel("outer"), SG("outerShape"), SS("outerShape"))
    y = y - 30
    Slider(c, "Anzahl Symbole", 20, y, 8, 120, 1, "%d", SG("outerCount"), SS("outerCount"))
    y = y - 28
    Slider(c, "Symbolgröße / Dicke", 20, y, 0.3, 3.0, 0.05, Times, SG("outerSize"), SS("outerSize"))
    y = y - 28
    Slider(c, "Radius", 20, y, 0.15, 0.7, 0.01, Pct, SG("outerRadius"), SS("outerRadius"))
    y = y - 40

    -- Innerer Ring ------------------------------------------------------------
    Header(c, "5-Sek.-Regel / Tick-Ring (innen)", y); y = y - 34
    Cycler(c, "Darstellung", 20, y, function() return RING_STYLES end,
        function(v) return RING_STYLE_LABELS[v] or v end, SG("innerStyle"), SS("innerStyle"))
    y = y - 30
    Cycler(c, "Symbol", 20, y, ShapeValues, ShapeLabel("inner"), SG("innerShape"), SS("innerShape"))
    y = y - 30
    Slider(c, "Anzahl Symbole", 20, y, 6, 100, 1, "%d", SG("innerCount"), SS("innerCount"))
    y = y - 28
    Slider(c, "Symbolgröße / Dicke", 20, y, 0.3, 3.0, 0.05, Times, SG("innerSize"), SS("innerSize"))
    y = y - 28
    Slider(c, "Radius", 20, y, 0.1, 0.6, 0.01, Pct, SG("innerRadius"), SS("innerRadius"))
    y = y - 34
    Check(c, "Symbole zeigen nach außen (mitdrehen)", 20, y, SG("rotateSymbols"), SS("rotateSymbols"))
    y = y - 28
    Slider(c, "Deckkraft leerer Teil", 20, y, 0, 1, 0.05, Pct, SG("emptyAlpha"), SS("emptyAlpha"))
    y = y - 40

    -- Hintergrund -----------------------------------------------------------
    Header(c, "Hintergrund & Rand", y); y = y - 34
    Cycler(c, "Hintergrund-Form", 20, y, function() return BG_SHAPES end,
        function(v) return BG_LABELS[v] or v end, SG("bgShape"), SS("bgShape"))
    y = y - 30
    Slider(c, "Hintergrund-Größe", 20, y, 0.2, 2.0, 0.05, Times, SG("bgSize"), SS("bgSize"))
    y = y - 28
    Slider(c, "Hintergrund-Deckkraft", 20, y, 0, 1, 0.05, Pct, SG("bgAlpha"), SS("bgAlpha"))
    y = y - 28
    Slider(c, "Rand-Größe", 20, y, 0.5, 1.8, 0.02, Times, SG("rimSize"), SS("rimSize"))
    y = y - 28
    Slider(c, "Rand-Deckkraft", 20, y, 0, 1, 0.05, Pct, SG("rimAlpha"), SS("rimAlpha"))
    y = y - 40

    -- Text & Funke -----------------------------------------------------------
    Header(c, "Text & Funke", y); y = y - 34
    Cycler(c, "Text in der Mitte", 20, y, function() return TEXT_MODES end,
        function(v) return TEXT_LABELS[v] or v end,
        function() return db().textMode end, function(v) db().textMode = v end)
    y = y - 30
    Slider(c, "Textgröße", 20, y, 0.4, 2.5, 0.05, Times, SG("textScale"), SS("textScale"))
    y = y - 28
    Slider(c, "Funkengröße", 20, y, 0.3, 3.0, 0.05, Times, SG("sparkSize"), SS("sparkSize"))
    y = y - 40

    -- Farben -----------------------------------------------------------------
    Header(c, "Farben", y); y = y - 34
    Label(c, "Linksklick: Farbe wählen · Rechtsklick: Themenfarbe · * = eigene Farbe", 20, y, "GameFontDisableSmall")
    y = y - 22
    for i, ck in ipairs(ns.colorKeys) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        Swatch(c, ck[2], ck[1], 20 + col * 195, y - row * 30)
    end
    y = y - math.ceil(#ns.colorKeys / 3) * 30 - 4
    Button(c, "Alle Farben zurücksetzen", 20, y, 200, function()
        wipe(ns.db.colors); O:RefreshWidgets(); Changed()
    end)
    y = y - 44

    -- Module -------------------------------------------------------------------
    Header(c, "Module", y); y = y - 34
    local mods = {
        { "ring",       "Mana-Ring (außen)" },
        { "fsr",        "5-Sekunden-Regel (innen)" },
        { "ticks",      "Mana-Tick-Timer (innen)" },
        { "spark",      "Leuchtfunke am Ring" },
        { "decor",      "Dekoration (Flügel, Hörner ...)" },
        { "text",       "Zahlen anzeigen" },
        { "background", "Hintergrund" },
        { "rim",        "Rand" },
        { "animations", "Animationen" },
    }
    for i, m in ipairs(mods) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        Check(c, m[2], 20 + col * 290, y - row * 28,
            function() return db().modules[m[1]] end,
            function(v) db().modules[m[1]] = v end)
    end
    y = y - math.ceil(#mods / 2) * 28 - 14

    -- Verhalten ----------------------------------------------------------------
    Header(c, "Verhalten", y); y = y - 34
    Check(c, "Anzeige aktiviert", 20, y,
        function() return db().enabled end, function(v) db().enabled = v; ns.Minimap:Refresh() end)
    Check(c, "Minimap-Button anzeigen", 310, y,
        function() return not db().minimap.hide end, function(v) db().minimap.hide = not v; ns.Minimap:Refresh() end)
    y = y - 28
    Check(c, "Fixieren (klickt durch, nicht verschiebbar)", 20, y,
        function() return db().locked end, function(v) db().locked = v end)
    y = y - 28
    Check(c, "Außerhalb des Kampfes bei vollem Mana ausblenden", 20, y,
        function() return db().hideWhenFull end, function(v) db().hideWhenFull = v end)
    y = y - 28
    Check(c, "Bei Formen/Klassen ohne Mana ausblenden", 20, y,
        function() return db().onlyManaClasses end, function(v) db().onlyManaClasses = v end)
    y = y - 44

    -- Werkzeuge ----------------------------------------------------------------
    Header(c, "Werkzeuge", y); y = y - 34
    Button(c, "5-Sek.-Regel testen", 20, y, 180, function()
        ns.Tracker:StartFSR(); ns.Display:Show(true)
    end)
    Button(c, "Position zurücksetzen", 210, y, 180, function()
        ns.db.point = { "CENTER", "UIParent", "CENTER", 0, -160 }; Changed()
    end)
    Button(c, "Form & Größen zurücksetzen", 400, y, 200, function()
        wipe(ns.db.style)
        for k, v in pairs(ns.defaults.style) do ns.db.style[k] = v end
        O:RefreshWidgets(); Changed()
    end)
    y = y - 34
    Label(c, "Befehle: /msig, toggle, minimap, lock, unlock, theme <name>, test", 20, y, "GameFontDisableSmall")
    y = y - 30

    c:SetHeight(-y + 20)

    panel:SetScript("OnShow", function() O:RefreshWidgets(); ns.Display:UpdateVisibility() end)
    panel:SetScript("OnHide", function() ns.Display:UpdateVisibility() end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, "ManaSigil")
        Settings.RegisterAddOnCategory(cat)
        self.category = cat
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function O:IsOpen()
    return self.panel ~= nil and self.panel:IsVisible() == true
end

function O:RefreshWidgets()
    if not ns.db then return end
    for _, w in ipairs(self.widgets) do
        if w.Refresh then w:Refresh() end
    end
end

function O:Open()
    if InCombatLockdown() then
        ns.pendingOptions = true
        ns.Print("Optionen öffnen sich nach dem Kampf.")
        return
    end
    if self.category and Settings and Settings.OpenToCategory then
        local id = self.category.GetID and self.category:GetID() or self.category.ID
        Settings.OpenToCategory(id)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.panel)
        InterfaceOptionsFrame_OpenToCategory(self.panel)
    end
end

-- ManaSigil – Optionsmenü (Spieloptionen > AddOns > ManaSigil)
local _, ns = ...
local L = ns.L

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
        GameTooltip:AddLine(L.TT_COLOR_PICK, 1, 1, 1)
        GameTooltip:AddLine(L.TT_COLOR_RESET, 1, 1, 1)
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
        return string.format(L.AUTO_FMT, ns.themes[key].name)
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
    if v == "theme" then return L.DECOR_THEME end
    if v == "none" then return L.DECOR_NONE end
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
            return string.format(L.THEME_AS, ns.shapeNames[shapes[which]] or ns.shapeNames.dot)
        end
        return ns.shapeNames[v] or v
    end
end

-- Auswahl aus einer übersetzten Tabelle
local function Lookup(tbl) return function(v) return tbl[v] or v end end

local RING_STYLES = { "symbols", "solid" }
local BG_SHAPES = { "disc", "soft", "ring" }
local TEXT_MODES = { "percent", "value", "both", "none" }
local MODULE_ORDER = { "ring", "fsr", "ticks", "spark", "decor", "text", "background", "rim", "animations" }

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
    local sub = Label(c, L.OPT_SUBTITLE, 16, y - 30, "GameFontHighlightSmall")
    sub:SetWidth(580); sub:SetJustifyH("LEFT")
    y = y - 64

    -- Thema ----------------------------------------------------------------
    Header(c, L.H_THEME, y); y = y - 34
    Cycler(c, L.O_THEME, 20, y, ThemeValues, ThemeLabel,
        function() return db().theme end, function(v) db().theme = v end)
    y = y - 30
    Cycler(c, L.O_DECOR, 20, y, DecorValues, DecorLabel,
        function() return db().decor end, function(v) db().decor = v end)
    y = y - 30
    Slider(c, L.O_DECOR_SCALE, 20, y, 0.3, 2.0, 0.05, Times, SG("decorScale"), SS("decorScale"))
    y = y - 40

    -- Gesamtgröße -----------------------------------------------------------
    Header(c, L.H_SIZE, y); y = y - 34
    Slider(c, L.O_BASESIZE, 20, y, 60, 300, 5, "%d px",
        function() return db().size end, function(v) db().size = v end)
    y = y - 28
    Slider(c, L.O_SCALE, 20, y, 0.5, 2.0, 0.05, Times,
        function() return db().scale end, function(v) db().scale = v end)
    y = y - 28
    Slider(c, L.O_ALPHA, 20, y, 0.1, 1.0, 0.05, Pct,
        function() return db().alpha end, function(v) db().alpha = v end)
    y = y - 40

    -- Ringe ----------------------------------------------------------------------
    local function RingSection(header, prefix, which, countMin, countMax, radMin, radMax)
        Header(c, header, y); y = y - 34
        Cycler(c, L.O_STYLE, 20, y, function() return RING_STYLES end, Lookup(L.RING_STYLES),
            SG(prefix .. "Style"), SS(prefix .. "Style"))
        y = y - 30
        Cycler(c, L.O_SHAPE, 20, y, ShapeValues, ShapeLabel(which), SG(prefix .. "Shape"), SS(prefix .. "Shape"))
        y = y - 30
        Slider(c, L.O_COUNT, 20, y, countMin, countMax, 1, "%d", SG(prefix .. "Count"), SS(prefix .. "Count"))
        y = y - 28
        Slider(c, L.O_SYMSIZE, 20, y, 0.3, 3.0, 0.05, Times, SG(prefix .. "Size"), SS(prefix .. "Size"))
        y = y - 28
        Slider(c, L.O_RADIUS, 20, y, radMin, radMax, 0.01, Pct, SG(prefix .. "Radius"), SS(prefix .. "Radius"))
    end
    RingSection(L.H_OUTER, "outer", "outer", 8, 120, 0.15, 0.7)
    y = y - 40
    RingSection(L.H_INNER, "inner", "inner", 6, 100, 0.1, 0.6)
    y = y - 34
    Check(c, L.O_ROTATE, 20, y, SG("rotateSymbols"), SS("rotateSymbols"))
    y = y - 28
    Slider(c, L.O_EMPTY_ALPHA, 20, y, 0, 1, 0.05, Pct, SG("emptyAlpha"), SS("emptyAlpha"))
    y = y - 40

    -- Hintergrund -----------------------------------------------------------
    Header(c, L.H_BG, y); y = y - 34
    Cycler(c, L.O_BG_SHAPE, 20, y, function() return BG_SHAPES end, Lookup(L.BG_SHAPES),
        SG("bgShape"), SS("bgShape"))
    y = y - 30
    Slider(c, L.O_BG_SIZE, 20, y, 0.2, 2.0, 0.05, Times, SG("bgSize"), SS("bgSize"))
    y = y - 28
    Slider(c, L.O_BG_ALPHA, 20, y, 0, 1, 0.05, Pct, SG("bgAlpha"), SS("bgAlpha"))
    y = y - 28
    Slider(c, L.O_RIM_SIZE, 20, y, 0.5, 1.8, 0.02, Times, SG("rimSize"), SS("rimSize"))
    y = y - 28
    Slider(c, L.O_RIM_ALPHA, 20, y, 0, 1, 0.05, Pct, SG("rimAlpha"), SS("rimAlpha"))
    y = y - 40

    -- Text & Funke -----------------------------------------------------------
    Header(c, L.H_TEXT, y); y = y - 34
    Cycler(c, L.O_TEXTMODE, 20, y, function() return TEXT_MODES end, Lookup(L.TEXT_MODES),
        function() return db().textMode end, function(v) db().textMode = v end)
    y = y - 30
    Slider(c, L.O_TEXTSCALE, 20, y, 0.4, 2.5, 0.05, Times, SG("textScale"), SS("textScale"))
    y = y - 28
    Slider(c, L.O_SPARKSIZE, 20, y, 0.3, 3.0, 0.05, Times, SG("sparkSize"), SS("sparkSize"))
    y = y - 40

    -- Farben -----------------------------------------------------------------
    Header(c, L.H_COLORS, y); y = y - 34
    Label(c, L.O_COLOR_HINT, 20, y, "GameFontDisableSmall")
    y = y - 22
    for i, ck in ipairs(ns.colorKeys) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        Swatch(c, ck[2], ck[1], 20 + col * 195, y - row * 30)
    end
    y = y - math.ceil(#ns.colorKeys / 3) * 30 - 4
    Button(c, L.O_COLORS_RESET, 20, y, 200, function()
        wipe(ns.db.colors); O:RefreshWidgets(); Changed()
    end)
    y = y - 44

    -- Module -------------------------------------------------------------------
    Header(c, L.H_MODULES, y); y = y - 34
    for i, key in ipairs(MODULE_ORDER) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        Check(c, L.MODULES[key], 20 + col * 290, y - row * 28,
            function() return db().modules[key] end,
            function(v) db().modules[key] = v end)
    end
    y = y - math.ceil(#MODULE_ORDER / 2) * 28 - 14

    -- Verhalten ----------------------------------------------------------------
    Header(c, L.H_BEHAVIOR, y); y = y - 34
    Check(c, L.O_ENABLED, 20, y,
        function() return db().enabled end, function(v) db().enabled = v; ns.Minimap:Refresh() end)
    Check(c, L.O_MINIMAP, 310, y,
        function() return not db().minimap.hide end, function(v) db().minimap.hide = not v; ns.Minimap:Refresh() end)
    y = y - 28
    Check(c, L.O_LOCK, 20, y,
        function() return db().locked end, function(v) db().locked = v end)
    y = y - 28
    Check(c, L.O_HIDEFULL, 20, y,
        function() return db().hideWhenFull end, function(v) db().hideWhenFull = v end)
    y = y - 28
    Check(c, L.O_ONLYMANA, 20, y,
        function() return db().onlyManaClasses end, function(v) db().onlyManaClasses = v end)
    y = y - 44

    -- Werkzeuge ----------------------------------------------------------------
    Header(c, L.H_TOOLS, y); y = y - 34
    Button(c, L.B_TEST, 20, y, 180, function()
        ns.Tracker:StartFSR(); ns.Display:Show(true)
    end)
    Button(c, L.B_POS_RESET, 210, y, 180, function()
        ns.db.point = { "CENTER", "UIParent", "CENTER", 0, -160 }; Changed()
    end)
    Button(c, L.B_STYLE_RESET, 400, y, 200, function()
        wipe(ns.db.style)
        for k, v in pairs(ns.defaults.style) do ns.db.style[k] = v end
        O:RefreshWidgets(); Changed()
    end)
    y = y - 34
    Label(c, L.O_COMMANDS, 20, y, "GameFontDisableSmall")
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
        ns.Print(L.OPTIONS_AFTER_COMBAT)
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

-- ManaSigil – Optionsmenü (Spieloptionen > AddOns > ManaSigil)
-- Jede Zeile hat einen Tooltip; Einstellungen ohne Wirkung im aktuellen Modus werden ausgegraut.
local _, ns = ...
local L = ns.L

local O = {}
ns.Options = O
O.widgets = {}
O.rows = {}

local LABEL_W = 180   -- Breite der Beschriftungsspalte
local ROW_W = 590

-- Zustandsabfragen für das Ausgrauen ---------------------------------------------
local function db() return ns.db end
local function style() return ns.db.style end
local function Mode() return ns.db.mode end
local function IsBar() return Mode() == "bar" end
local function IsRing() return Mode() == "ring" end
local function IsCircle() return Mode() ~= "bar" end
local function OuterSymbols() return IsRing() and style().outerStyle == "symbols" end
local function InnerSymbols() return IsCircle() and style().innerStyle == "symbols" end
local function TimerOn() return db().modules.fsr or db().modules.ticks end

local function Changed()
    local ok, err = pcall(ns.Display.Refresh, ns.Display)
    if not ok then ns.ReportError("Refresh", err) end
    ok, err = pcall(O.RefreshWidgets, O)
    if not ok then ns.ReportError("Options", err) end   -- Beschriftungen (z. B. Laufrichtung) hängen vom Modus ab
end

-- Tooltip ---------------------------------------------------------------------------
local function ShowTip(row)
    if not row or not row.tipTitle then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(row.tipTitle, 1, 0.82, 0)
    if row.tip then GameTooltip:AddLine(row.tip, 1, 1, 1, true) end
    if row.inactive then GameTooltip:AddLine(L.TIP_INACTIVE, 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end
local function HideTip() GameTooltip:Hide() end

-- Eine Zeile mit Tooltip und optionaler Aktiv-Bedingung
local function Row(parent, x, y, title, tip, active, w)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", x, y + 4)
    row:SetSize(w or ROW_W, 26)
    row:EnableMouse(true)
    row.tipTitle, row.tip, row.active = title, tip, active
    row.controls = {}
    row:SetScript("OnEnter", ShowTip)
    row:SetScript("OnLeave", HideTip)
    O.rows[#O.rows + 1] = row
    return row
end

local function AddControl(row, c)
    row.controls[#row.controls + 1] = c
    c:HookScript("OnEnter", function() ShowTip(row) end)
    c:HookScript("OnLeave", HideTip)
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

local function Check(parent, text, x, y, get, set, tip, active, w)
    local row = Row(parent, x, y, text, tip, active, w)
    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetPoint("LEFT", row, "LEFT", 0, 0)
    local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    lbl:SetText(text)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); Changed() end)
    AddControl(row, cb)
    local holder = { Refresh = function() cb:SetChecked(get() and true or false) end }
    O.widgets[#O.widgets + 1] = holder
    return holder
end

-- Zahleneingabe (Enter übernimmt, Esc verwirft)
local function NumberInput(parent, text, x, y, get, set, unitFn, tip, active)
    local row = Row(parent, x, y, text, tip, active)
    local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("LEFT", row, "LEFT", 0, 0)
    lbl:SetText(text)
    local eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    eb:SetSize(80, 20)
    eb:SetPoint("LEFT", row, "LEFT", LABEL_W + 10, 0)
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetMaxLetters(6)
    local unit = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    unit:SetPoint("LEFT", eb, "RIGHT", 8, 0)
    local holder
    local function Commit()
        local v = tonumber(eb:GetText())
        if v and v ~= get() then set(v); Changed() end
        eb:SetText(tostring(get()))
    end
    eb:SetScript("OnEnterPressed", function(self) Commit(); self:ClearFocus() end)
    eb:SetScript("OnEscapePressed", function(self) self:SetText(tostring(get())); self:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", Commit)
    AddControl(row, eb)
    holder = { Refresh = function()
        if not eb:HasFocus() then eb:SetText(tostring(get())) end
        unit:SetText(unitFn and unitFn() or "")
    end }
    O.widgets[#O.widgets + 1] = holder
    return holder
end

-- Auswahl mit < > Pfeilen
local function Cycler(parent, text, x, y, valuesFn, labelFn, get, set, tip, active)
    local row = Row(parent, x, y, text, tip, active)
    local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("LEFT", row, "LEFT", 0, 0)
    lbl:SetText(text)
    local prev = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    prev:SetSize(26, 22); prev:SetPoint("LEFT", row, "LEFT", LABEL_W, 0); prev:SetText("<")
    local box = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    box:SetPoint("LEFT", prev, "RIGHT", 6, 0); box:SetWidth(240); box:SetJustifyH("CENTER")
    local nextB = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    nextB:SetSize(26, 22); nextB:SetPoint("LEFT", box, "RIGHT", 6, 0); nextB:SetText(">")
    AddControl(row, prev); AddControl(row, nextB)

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

local function Slider(parent, text, x, y, minV, maxV, step, fmt, get, set, tip, active)
    local row = Row(parent, x, y, text, tip, active)
    local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("LEFT", row, "LEFT", 0, 0)
    lbl:SetText(text)
    local s = CreateFrame("Slider", nil, row, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(240, 16)
    s:SetPoint("LEFT", row, "LEFT", LABEL_W + 4, 0)
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
    local val = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    val:SetPoint("LEFT", s, "RIGHT", 8, 0)
    local updating = false
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        val:SetText(FormatValue(fmt, v))
        if updating then return end
        set(v); Changed()
    end)
    AddControl(row, s)
    local holder = { Refresh = function()
        updating = true
        s:SetValue(get())
        val:SetText(FormatValue(fmt, get()))
        updating = false
    end }
    O.widgets[#O.widgets + 1] = holder
    return holder
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

local function Swatch(parent, text, key, x, y, modeKey, modeValue)
    local tip = L.TT_COLOR_PICK .. "\n" .. L.TT_COLOR_RESET
    if L.TT_COLOR_EXTRA and L.TT_COLOR_EXTRA[key] then tip = tip .. "\n\n" .. L.TT_COLOR_EXTRA[key] end
    local row = Row(parent, x, y, text, tip, nil, 185)
    local b = CreateFrame("Button", nil, row, "BackdropTemplate")
    b:SetSize(22, 22)
    b:SetPoint("LEFT", row, "LEFT", 0, 0)
    b:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 3, -3); tex:SetPoint("BOTTOMRIGHT", -3, 3)
    tex:SetColorTexture(1, 1, 1)
    local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("LEFT", b, "RIGHT", 6, 0)
    lbl:SetText(text)
    local mark = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    mark:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
    local holder = { Refresh = function()
        local r, g, bl = ns.GetColor(key)
        tex:SetColorTexture(r, g, bl)
        mark:SetText(ns.db.colors[key] and "*" or "")   -- * = eigene Farbe
    end }
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then          -- Rechtsklick: zurück zur Themenfarbe
            ns.db.colors[key] = nil
            holder.Refresh(); Changed()
            return
        end
        local r, g, bl = ns.GetColor(key)
        OpenColorPicker(r, g, bl, function(nr, ng, nb)
            ns.db.colors[key] = { nr, ng, nb }
            -- Wer die Textfarbe wählt, will sie auch sehen: Verlauf dafür abschalten
            -- (und umgekehrt bei den Verlaufsfarben wieder einschalten)
            if modeKey then
                ns.db.style[modeKey] = modeValue      -- Leisten: feste Farbe bzw. Verlauf
            elseif key == "text" then
                ns.db.style.textColorMode = "fixed"
            elseif key == "high" or key == "mid" then
                ns.db.style.textColorMode = "gradient"
            end
            holder.Refresh(); Changed()
        end)
    end)
    AddControl(row, b)
    O.widgets[#O.widgets + 1] = holder
    return holder
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

-- Stückzahl der Torte: von Hälften bis Tausendstel
local SEGMENT_STEPS = { 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 30, 36, 48, 60, 100, 250, 500, 1000 }
local function SegmentLabel(v)
    local name = L.SEGMENT_NAMES and L.SEGMENT_NAMES[v]
    return name and string.format("%d (%s)", v, name) or tostring(v)
end

-- Laufrichtung: im Kreis/in der Torte cw/ccw/up/down, beim Balken forward/reverse
local function IsVertBar() return IsBar() and style().barOrientation == "vertical" end
local function DirValues()
    if IsBar() then return { "forward", "reverse" } end
    return { "cw", "ccw", "ltr", "rtl", "up", "down" }
end
local function DirLabel(v)
    if v == "forward" then return IsVertBar() and L.DIRS.up or L.DIR_RIGHT end
    if v == "reverse" then return IsVertBar() and L.DIRS.down or L.DIR_LEFT end
    return L.DIRS[v] or v
end
-- Liest/schreibt je nach Modus das passende Feld (Kreis/Torte oder Balken)
local function DirGet(circleKey, barKey)
    return function() return IsBar() and style()[barKey] or style()[circleKey] end
end
local function DirSet(circleKey, barKey)
    return function(v)
        if IsBar() then style()[barKey] = v else style()[circleKey] = v end
    end
end

local function DecorPartPresent(part)
    if not db().modules.decor or db().decor == "none" then return false end
    for _, d in ipairs(ns.GetDecorSource().decor or {}) do
        if d.part == part then return true end
    end
    return false
end

local function Lookup(tbl) return function(v) return tbl[v] or v end end
local function List(...) local t = { ... }; return function() return t end end

local MODULE_ORDER = { "ring", "fsr", "ticks", "spark", "decor", "text", "background", "rim", "animations", "fallback" }

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
    c:SetSize(640, 100)
    scroll:SetScrollChild(c)

    local function SG(key) return function() return style()[key] end end
    local function SS(key) return function(v) style()[key] = v end end
    local y = -12

    local title = c:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, y)
    title:SetText("|cff7fb2ffMana|r|cffffd166Sigil|r")
    local sub = Label(c, L.OPT_SUBTITLE, 16, y - 30, "GameFontHighlightSmall")
    sub:SetWidth(600); sub:SetJustifyH("LEFT")
    y = y - 64

    -- Anordnung (Sandbox) -----------------------------------------------------
    Header(c, L.H_SANDBOX, y); y = y - 34
    -- ein Knopf: Bearbeitungsmodus an / Anordnung speichern
    local editBtn = Button(c, L.EDIT_START, 20, y + 2, 260, function() ns.Sandbox:ToggleEditing() end)
    editBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine(s:GetText(), 1, 0.82, 0)
        GameTooltip:AddLine(L.TIP_SANDBOX, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    editBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    O.widgets[#O.widgets + 1] = { Refresh = function()
        editBtn:SetText(ns.Sandbox.editing and L.EDIT_SAVE or L.EDIT_START)
    end }
    Button(c, L.O_SANDBOX_RESET, 320, y + 2, 200, function() ns.Sandbox:ResetAll(); O:RefreshWidgets() end)
    y = y - 28
    local hint = Label(c, L.SANDBOX_HINT, 20, y, "GameFontDisableSmall")
    hint:SetWidth(600); hint:SetJustifyH("LEFT")
    y = y - 40

    -- Darstellung -----------------------------------------------------------
    Header(c, L.H_DISPLAY, y); y = y - 34
    Cycler(c, L.O_MODE, 20, y, List("ring", "pie", "bar"), Lookup(L.MODES),
        function() return db().mode end, function(v) db().mode = v end, L.TIP_MODE)
    y = y - 30
    Slider(c, L.O_BASESIZE, 20, y, 60, 300, 5, "%d px",
        function() return db().size end, function(v) db().size = v end, L.TIP_SIZE)
    y = y - 28
    Slider(c, L.O_ALPHA, 20, y, 0.1, 1.0, 0.05, Pct,
        function() return db().alpha end, function(v) db().alpha = v end, L.TIP_ALPHA)
    y = y - 40

    -- Thema & Deko -----------------------------------------------------------
    Header(c, L.H_THEME, y); y = y - 34
    Cycler(c, L.O_THEME, 20, y, ThemeValues, ThemeLabel,
        function() return db().theme end, function(v) db().theme = v end, L.TIP_THEME)
    y = y - 30
    Cycler(c, L.O_DECOR, 20, y, DecorValues, DecorLabel,
        function() return db().decor end, function(v) db().decor = v end, L.TIP_DECOR,
        function() return db().modules.decor end)
    y = y - 30
    Slider(c, L.O_DECOR_SCALE, 20, y, 0.3, 2.0, 0.05, Times, SG("decorScale"), SS("decorScale"),
        L.TIP_DECOR_SCALE, function() return db().modules.decor and db().decor ~= "none" end)
    y = y - 30
    Label(c, L.O_DECOR_PARTS, 20, y)
    y = y - 22
    for i, part in ipairs(ns.decorParts) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        Check(c, L.DECOR_PARTS[part], 30 + col * 195, y - row * 26,
            function() return not db().decorOff[part] end,
            function(v) db().decorOff[part] = (not v) or nil end,
            L.TIP_DECOR_PARTS, function() return DecorPartPresent(part) end, 190)
    end
    y = y - math.ceil(#ns.decorParts / 3) * 26 - 16

    -- Mana-Anzeige ----------------------------------------------------------------
    Header(c, L.H_OUTER, y); y = y - 34
    Cycler(c, L.O_STYLE, 20, y, List("symbols", "solid"), Lookup(L.RING_STYLES),
        SG("outerStyle"), SS("outerStyle"), L.TIP_STYLE, IsRing)
    y = y - 30
    Cycler(c, L.O_SHAPE, 20, y, ShapeValues, ShapeLabel("outer"), SG("outerShape"), SS("outerShape"),
        L.TIP_SHAPE, OuterSymbols)
    y = y - 30
    Slider(c, L.O_COUNT, 20, y, 8, 120, 1, "%d", SG("outerCount"), SS("outerCount"), L.TIP_COUNT, OuterSymbols)
    y = y - 28
    Slider(c, L.O_SYMSIZE, 20, y, 0.3, 3.0, 0.05, Times, SG("outerSize"), SS("outerSize"), L.TIP_SYMSIZE, IsRing)
    y = y - 28
    Slider(c, L.O_RADIUS, 20, y, 0.15, 0.7, 0.01, Pct, SG("outerRadius"), SS("outerRadius"), L.TIP_RADIUS, IsCircle)
    y = y - 30
    Cycler(c, L.O_DIRECTION, 20, y, DirValues, DirLabel, DirGet("outerDir", "barDir"), DirSet("outerDir", "barDir"),
        L.TIP_DIRECTION)
    y = y - 30
    Cycler(c, L.O_PIE_STYLE, 20, y, List("smooth", "segments"), Lookup(L.PIE_STYLES),
        SG("pieStyle"), SS("pieStyle"), L.TIP_PIE_STYLE, function() return Mode() == "pie" end)
    y = y - 30
    Cycler(c, L.O_PIE_SEGMENTS, 20, y, function() return SEGMENT_STEPS end, SegmentLabel,
        SG("pieSegments"), SS("pieSegments"), L.TIP_PIE_SEGMENTS,
        function() return Mode() == "pie" and style().pieStyle == "segments" end)
    y = y - 30
    Cycler(c, L.O_ORIENT, 20, y, List("horizontal", "vertical"), Lookup(L.ORIENTS),
        SG("barOrientation"),
        function(v)
            -- beim Umschalten Breite und Höhe tauschen, damit der Balken lang bleibt
            if v ~= style().barOrientation then
                style().barWidth, style().barHeight = style().barHeight, style().barWidth
            end
            style().barOrientation = v
        end, L.TIP_ORIENT, IsBar)
    y = y - 30
    Slider(c, L.O_BAR_WIDTH, 20, y, 0.05, 4.0, 0.05, Times, SG("barWidth"), SS("barWidth"), L.TIP_BAR, IsBar)
    y = y - 28
    Slider(c, L.O_BAR_HEIGHT, 20, y, 0.05, 4.0, 0.05, Times, SG("barHeight"), SS("barHeight"), L.TIP_BAR, IsBar)
    y = y - 30
    Cycler(c, L.O_BAR_TEXTURE, 20, y, List("smooth", "flat", "blizzard"), Lookup(L.BAR_TEXTURES),
        SG("barTexture"), SS("barTexture"), L.TIP_BAR, IsBar)
    y = y - 40

    -- 5-Sek.-Regel & Ticks -----------------------------------------------------------
    Header(c, L.H_INNER, y); y = y - 34
    Cycler(c, L.O_FSR_FILL, 20, y, List("drain", "fill"), Lookup(L.FILL_MODES), SG("fsrFill"), SS("fsrFill"),
        L.TIP_FSR_FILL, function() return db().modules.fsr end)
    y = y - 30
    Cycler(c, L.O_TICK_FILL, 20, y, List("fill", "drain"), Lookup(L.FILL_MODES), SG("tickFill"), SS("tickFill"),
        L.TIP_TICK_FILL, function() return db().modules.ticks end)
    y = y - 30
    Cycler(c, L.O_DIRECTION, 20, y, DirValues, DirLabel, DirGet("innerDir", "innerBarDir"),
        DirSet("innerDir", "innerBarDir"), L.TIP_DIRECTION, TimerOn)
    y = y - 30
    Cycler(c, L.O_STYLE, 20, y, List("symbols", "solid"), Lookup(L.RING_STYLES),
        SG("innerStyle"), SS("innerStyle"), L.TIP_STYLE, function() return IsCircle() and TimerOn() end)
    y = y - 30
    Cycler(c, L.O_SHAPE, 20, y, ShapeValues, ShapeLabel("inner"), SG("innerShape"), SS("innerShape"),
        L.TIP_SHAPE, function() return InnerSymbols() and TimerOn() end)
    y = y - 30
    Slider(c, L.O_COUNT, 20, y, 6, 100, 1, "%d", SG("innerCount"), SS("innerCount"), L.TIP_COUNT,
        function() return InnerSymbols() and TimerOn() end)
    y = y - 28
    Slider(c, L.O_SYMSIZE, 20, y, 0.3, 3.0, 0.05, Times, SG("innerSize"), SS("innerSize"), L.TIP_SYMSIZE,
        function() return IsCircle() and TimerOn() end)
    y = y - 28
    Slider(c, L.O_RADIUS, 20, y, 0.1, 0.6, 0.01, Pct, SG("innerRadius"), SS("innerRadius"), L.TIP_RADIUS,
        function() return IsRing() and TimerOn() end)
    y = y - 32
    Check(c, L.O_HIDE_IDLE, 20, y, SG("innerHideIdle"), SS("innerHideIdle"), L.TIP_HIDE_IDLE, TimerOn)
    y = y - 28
    Check(c, L.O_ROTATE, 20, y, SG("rotateSymbols"), SS("rotateSymbols"), L.TIP_ROTATE,
        function() return OuterSymbols() or InnerSymbols() end)
    y = y - 28
    Slider(c, L.O_EMPTY_ALPHA, 20, y, 0, 1, 0.05, Pct, SG("emptyAlpha"), SS("emptyAlpha"), L.TIP_EMPTY_ALPHA)
    y = y - 40

    -- Hintergrund & Rand -----------------------------------------------------------
    Header(c, L.H_BG, y); y = y - 34
    Cycler(c, L.O_BG_SHAPE, 20, y, List("disc", "soft", "ring"), Lookup(L.BG_SHAPES),
        SG("bgShape"), SS("bgShape"), L.TIP_BG_SHAPE, function() return IsCircle() and db().modules.background end)
    y = y - 30
    Slider(c, L.O_BG_SIZE, 20, y, 0.5, 2.0, 0.05, Times, SG("bgSize"), SS("bgSize"), L.TIP_BG_SIZE,
        function() return IsCircle() and db().modules.background end)
    y = y - 28
    Slider(c, L.O_BG_ALPHA, 20, y, 0, 1, 0.05, Pct, SG("bgAlpha"), SS("bgAlpha"), L.TIP_BG_ALPHA,
        function() return db().modules.background end)
    y = y - 28
    local rimActive = function() return IsCircle() and db().modules.rim end
    Slider(c, L.O_RIM_SIZE, 20, y, 0.8, 1.5, 0.01, Times, SG("rimSize"), SS("rimSize"), L.TIP_RIM, rimActive)
    y = y - 28
    Slider(c, L.O_RIM_ALPHA, 20, y, 0, 1, 0.05, Pct, SG("rimAlpha"), SS("rimAlpha"), L.TIP_RIM, rimActive)
    y = y - 32
    Check(c, L.O_RIM_FSR, 20, y, SG("rimFSR"), SS("rimFSR"), L.TIP_RIM_FSR, rimActive)
    y = y - 40

    -- Text, MP5 & Funke -----------------------------------------------------------
    local textOn = function() return db().modules.text end
    Header(c, L.H_TEXT, y); y = y - 34
    Cycler(c, L.O_TEXTMODE, 20, y, List("percent", "value", "both", "none"), Lookup(L.TEXT_MODES),
        function() return db().textMode end, function(v) db().textMode = v end, L.TIP_TEXTMODE, textOn)
    y = y - 30
    Cycler(c, L.O_MP5, 20, y, List("current", "both", "off"), Lookup(L.MP5_MODES),
        SG("mp5Mode"), SS("mp5Mode"), L.TIP_MP5, textOn)
    y = y - 30
    Slider(c, L.O_TEXTSCALE, 20, y, 0.4, 2.5, 0.05, Times, SG("textScale"), SS("textScale"), L.TIP_TEXTSCALE, textOn)
    y = y - 28
    Slider(c, L.O_SPARKSIZE, 20, y, 0.3, 3.0, 0.05, Times, SG("sparkSize"), SS("sparkSize"), L.TIP_SPARKSIZE,
        function() return db().modules.spark end)
    y = y - 40

    -- Farbverlauf & Warnung ---------------------------------------------------
    Header(c, L.H_WARN, y); y = y - 34
    Cycler(c, L.O_TEXTCOLOR, 20, y, List("gradient", "fixed"), Lookup(L.TEXTCOLOR_MODES),
        SG("textColorMode"), SS("textColorMode"), L.TIP_TEXTCOLOR, textOn)
    y = y - 30
    Slider(c, L.O_GRAD_MID, 20, y, 10, 90, 5, "%d%%", SG("gradMidPct"), SS("gradMidPct"), L.TIP_GRAD_MID,
        function() return style().textColorMode == "gradient" end)
    y = y - 32
    Check(c, L.O_WARN, 20, y, SG("warnEnabled"), SS("warnEnabled"), L.TIP_WARN)
    y = y - 30
    local warnOn = function() return style().warnEnabled end
    Cycler(c, L.O_WARN_UNIT, 20, y, List("percent", "mana"), Lookup(L.WARN_UNITS),
        SG("warnUnit"),
        function(v)
            -- beim Wechsel einen sinnvollen Wert vorschlagen
            if v ~= style().warnUnit then style().warnValue = (v == "mana") and 500 or 20 end
            style().warnUnit = v
        end, L.TIP_WARN_UNIT, warnOn)
    y = y - 30
    NumberInput(c, L.O_WARN_VALUE, 20, y, SG("warnValue"),
        function(v)
            if style().warnUnit == "percent" then v = math.max(1, math.min(99, v)) else v = math.max(1, v) end
            style().warnValue = v
        end,
        function() return style().warnUnit == "mana" and L.UNIT_MANA or "%" end, L.TIP_WARN_VALUE, warnOn)
    y = y - 30
    Cycler(c, L.O_WARN_BLINK, 20, y, List("text", "all", "off"), Lookup(L.BLINK_MODES),
        SG("warnBlink"), SS("warnBlink"), L.TIP_WARN_BLINK, warnOn)
    y = y - 30
    local soundValues = { "off" }
    for _, k in ipairs(ns.warnSoundOrder) do soundValues[#soundValues + 1] = k end
    Cycler(c, L.O_WARN_SOUND, 20, y, function() return soundValues end, Lookup(L.SOUNDS),
        SG("warnSound"), function(v) style().warnSound = v; ns.PlayWarnSound(v) end, L.TIP_WARN_SOUND, warnOn)
    y = y - 30
    Slider(c, L.O_WARN_REPEAT, 20, y, 0, 30, 1, function(v) return v == 0 and L.ONCE or string.format("%d s", v) end,
        SG("warnRepeat"), SS("warnRepeat"), L.TIP_WARN_REPEAT,
        function() return style().warnEnabled and style().warnSound ~= "off" end)
    y = y - 32
    Check(c, L.O_WARN_COMBAT, 20, y, SG("warnCombatOnly"), SS("warnCombatOnly"), L.TIP_WARN_COMBAT, warnOn)
    y = y - 40

    -- Farben der beiden Leisten -----------------------------------------------
    Header(c, L.H_BARCOLORS, y); y = y - 34
    local function BarBlock(which, modeKey, midKey, fixedKeys, active)
        local g = ns.gradients[which]
        Label(c, L["BARCOL_" .. which:upper()], 20, y, "GameFontNormal")
        y = y - 26
        Cycler(c, L.O_BARCOL_MODE, 20, y, List("fixed", "gradient"), Lookup(L["BARCOL_MODES_" .. which:upper()]),
            SG(modeKey), SS(modeKey), L["TIP_BARCOL_" .. which:upper()], active)
        y = y - 30
        local gradOn = function() return active() and style()[modeKey] == "gradient" end
        Slider(c, L.O_BARCOL_MID, 20, y, 10, 90, 5, "%d%%", SG(midKey), SS(midKey), L.TIP_BARCOL_MID, gradOn)
        y = y - 30
        -- feste Farbe(n) zuerst, dann die drei Verlaufsfarben
        local keys = {}
        for _, k in ipairs(fixedKeys) do keys[#keys + 1] = { k, "fixed" } end
        for i = 1, 3 do keys[#keys + 1] = { g[i], "gradient" } end
        for i, kk in ipairs(keys) do
            local col = (i - 1) % 3
            local row = math.floor((i - 1) / 3)
            Swatch(c, L.COLORS[kk[1]], kk[1], 20 + col * 195, y - row * 30, modeKey, kk[2])
        end
        y = y - math.ceil(#keys / 3) * 30 - 10
    end
    BarBlock("mana", "manaColorMode", "manaGradMid", { "ring" }, function() return db().modules.ring end)
    BarBlock("timer", "timerColorMode", "timerGradMid", { "tick", "fsr" },
        function() return db().modules.ticks or db().modules.fsr end)
    y = y - 10

    -- Farben -----------------------------------------------------------------
    Header(c, L.H_COLORS, y); y = y - 34
    Label(c, L.O_COLOR_HINT, 20, y, "GameFontDisableSmall")
    y = y - 24
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
        Check(c, L.MODULES[key], 20 + col * 300, y - row * 28,
            function() return db().modules[key] end,
            function(v) db().modules[key] = v end, nil, nil, 295)
    end
    y = y - math.ceil(#MODULE_ORDER / 2) * 28 - 14

    -- Visuelle Effekte ---------------------------------------------------------
    Header(c, L.H_EFFECTS, y); y = y - 34
    local animOn = function() return db().modules.animations and db().modules.decor end
    local effects = {
        { "fxRotate", animOn }, { "fxBob", animOn },
        { "fxPulse", animOn }, { "fxFlicker", animOn },
        { "fxSparkPulse", function() return db().modules.spark end },
        { "fxRimPulse", function() return IsCircle() and db().modules.rim and style().rimFSR end },
        { "fxTickFlash", function() return db().modules.ticks end },
    }
    for i, e in ipairs(effects) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        Check(c, L.EFFECTS[e[1]], 20 + col * 300, y - row * 28, SG(e[1]), SS(e[1]), L.TIP_EFFECTS[e[1]], e[2], 295)
    end
    y = y - math.ceil(#effects / 2) * 28 - 14

    -- Verhalten ----------------------------------------------------------------
    Header(c, L.H_BEHAVIOR, y); y = y - 34
    Check(c, L.O_ENABLED, 20, y,
        function() return db().enabled end, function(v) db().enabled = v; ns.Minimap:Refresh() end, nil, nil, 295)
    Check(c, L.O_MINIMAP, 320, y,
        function() return not db().minimap.hide end,
        function(v) db().minimap.hide = not v; ns.Minimap:Refresh() end, nil, nil, 295)
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

-- Zeilen ohne Wirkung ausgrauen
function O:RefreshActive()
    if not ns.db then return end
    for _, row in ipairs(self.rows) do
        local on = (row.active == nil) or (row.active() and true or false)
        row.inactive = not on
        row:SetAlpha(on and 1 or 0.4)
        for _, ctl in ipairs(row.controls) do
            if on then ctl:Enable() else ctl:Disable() end
        end
    end
end

function O:RefreshWidgets()
    if not ns.db then return end
    for _, w in ipairs(self.widgets) do
        if w.Refresh then w:Refresh() end
    end
    self:RefreshActive()
end

function O:Open()
    -- Auch im Kampf erlaubt. Sollte das Spiel das Öffnen im Kampf verweigern,
    -- öffnen sich die Optionen automatisch nach dem Kampf.
    local ok = pcall(function()
        if self.category and Settings and Settings.OpenToCategory then
            local id = self.category.GetID and self.category:GetID() or self.category.ID
            Settings.OpenToCategory(id)
        elseif InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(self.panel)
            InterfaceOptionsFrame_OpenToCategory(self.panel)
        end
    end)
    if not ok and InCombatLockdown() then
        ns.pendingOptions = true
        ns.Print(L.OPTIONS_AFTER_COMBAT)
    end
end

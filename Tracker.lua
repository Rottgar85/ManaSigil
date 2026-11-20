-- ManaSigil – Logik: 5-Sekunden-Regel und Mana-Ticks
local _, ns = ...

local T = {}
ns.Tracker = T

local FSR_DURATION = 5     -- Sekunden ohne Manaverbrauch bis zur vollen Regeneration
local TICK_INTERVAL = 2    -- Server-Tick der Mana-Regeneration
local MIN_TICK_GAP = 1.5   -- kleinere Abstände gelten nicht als neuer Tick (z. B. Tränke)
local TICK_TIMEOUT = 4.5   -- so lange ohne neuen Tick: Regeneration ruht (z. B. Mana voll), Timer stoppt
local CAST_WINDOW = 0.5    -- Manaänderung so kurz nach einem Zauber = Verbrauch (bei geheimen Werten)

T.FSR_DURATION = FSR_DURATION
T.TICK_INTERVAL = TICK_INTERVAL

function T:Init()
    self:Reset()
end

function T:Reset()
    self.fsrEnd     = 0
    self.lastTick   = nil
    self.tickAmount = nil
    self.lastMana   = nil
    self.secret     = false
    self.est        = nil      -- geschätztes Mana bei geheimen Werten (nil = unbekannt)
    self.resetTime  = GetTime()
    self:OnPower()
end

function T:StartFSR(now)
    self.fsrEnd = (now or GetTime()) + FSR_DURATION
    ns.Display:OnFSRStart()
end

-- Mana aktuell / maximal (kann im neuen Client ein "secret value" sein)
function T:GetMana()
    return UnitPower("player", ns.MANA), UnitPowerMax("player", ns.MANA)
end

-- Statistik der Mana-Events für /msig debug (Anzahl je Typ, Abstände der UPDATE-Events)
function T:CountEvent(event, now)
    local s = self.stats
    if not s or now - s.start > 10 then
        s = { start = now, update = 0, frequent = 0, gaps = {} }
        self.stats = s
    end
    if event == "UNIT_POWER_FREQUENT" then
        s.frequent = s.frequent + 1
    else
        s.update = s.update + 1
        if s.lastUpdate then
            table.insert(s.gaps, 1, now - s.lastUpdate)
            s.gaps[8] = nil
        end
        s.lastUpdate = now
    end
end

function T:OnPower(event)
    local cur = UnitPower("player", ns.MANA)
    local now = GetTime()
    if event then self:CountEvent(event, now) end
    if not ns.Readable(cur) then
        -- Geheimer Wert: nicht vergleichen. Das Event selbst ist aber ein Signal.
        -- UNIT_POWER_FREQUENT kommt bei fließender Regeneration fast ständig, daher
        -- zählen nur UNIT_POWER_UPDATE-Events (Server-Aktualisierung) als Tick.
        self.secret = true
        self.lastMana = nil
        if event == "UNIT_POWER_FREQUENT" then return end
        if self.lastCast and now - self.lastCast < CAST_WINDOW then
            if now >= self.fsrEnd then self:StartFSR(now) end
        elseif now >= self.fsrEnd then
            if self:RegisterTick(now, nil) then self:AddEstimate("base") end
        elseif not self.lastFsrTick or now - self.lastFsrTick >= MIN_TICK_GAP then
            self.lastFsrTick = now         -- Tick während der 5-Sek.-Regel (Zauber-Regeneration)
            self:AddEstimate("cast")
        end
        return
    end
    self.secret = false
    self.est = cur
    local last = self.lastMana
    if last then
        if cur < last then
            self:StartFSR(now)
        elseif cur > last and now >= self.fsrEnd then
            self:RegisterTick(now, cur - last)
        end
    end
    self.lastMana = cur
end

-- Tick merken (Abstände der letzten Ticks für /msig debug)
function T:RegisterTick(now, amount)
    if self.lastTick and (now - self.lastTick) < MIN_TICK_GAP then return false end
    if self.lastTick then
        self.gaps = self.gaps or {}
        table.insert(self.gaps, 1, now - self.lastTick)
        self.gaps[6] = nil
    end
    self.lastTick = now
    if amount then self.tickAmount = amount end
    ns.Display:OnTick(amount)
    return true
end

-- Geschätztes Mana ----------------------------------------------------------------
-- Verbirgt das Spiel Mana und Prozentwert, rechnet ManaSigil selbst mit:
-- voll, sobald keine Ticks mehr kommen; minus lesbare Zauberkosten; plus Regeneration je Tick.
local function MaxMana()
    local mx = UnitPowerMax("player", ns.MANA)
    if ns.Readable(mx) and type(mx) == "number" and mx > 0 then return mx end
end

function T:AddEstimate(kind)
    if not self.est then return end
    local base, cast = self:GetMP5()
    local per5 = (kind == "cast") and cast or base
    local mx = MaxMana()
    if not (per5 and mx) then return end
    self.est = math.min(mx, self.est + per5 * TICK_INTERVAL / 5)
end

-- regelmäßig aufrufen: erkennt volles Mana (lange kein Tick, außerhalb der 5-Sek.-Regel)
function T:UpdateEstimate(now)
    if not self.secret then return end
    now = now or GetTime()
    local quietSince = math.max(self.lastTick or 0, self.fsrEnd or 0, self.lastCast or 0, self.resetTime or 0)
    if now - quietSince > TICK_TIMEOUT then
        local mx = MaxMana()
        if mx then self.est = mx end
    end
end

-- geschätzter Mana-Anteil 0..1 oder nil
function T:EstimatedFraction()
    local mx = MaxMana()
    if not (self.est and mx) then return nil end
    return math.max(0, math.min(1, self.est / mx))
end

-- Kostet der Zauber Mana? true = ja, false = sicher nicht (Reittier, Nahkampf,
-- Wut/Energie), nil = unbekannt (Kosten nicht abfragbar)
-- Manakosten eines Zaubers als Zahl, wenn lesbar; sonst nil
local function SpellManaCost(spellID)
    local getter = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
    if not getter or not spellID then return nil end
    local ok, total = pcall(function()
        local costs = getter(spellID)
        if type(costs) ~= "table" then return nil end
        local sum, found = 0, false
        for _, c in ipairs(costs) do
            if ns.Readable(c.type) and c.type == ns.MANA then
                local v = c.cost
                if not (ns.Readable(v) and type(v) == "number") then return nil end
                sum, found = sum + v, true
            end
        end
        return found and sum or nil
    end)
    if ok then return total end
end
T.SpellManaCost = SpellManaCost

local function SpellCostsMana(spellID)
    local getter = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
    if not getter or not spellID then return nil end
    local ok, result = pcall(function()
        local costs = getter(spellID)
        if costs == nil then return false end          -- Zauber ohne Kosten
        if type(costs) ~= "table" then return nil end
        local unknown = false
        for _, c in ipairs(costs) do
            if not ns.Readable(c.type) then
                unknown = true
            elseif c.type == ns.MANA then
                for _, field in ipairs({ "cost", "minCost", "costPercent" }) do
                    local v = c[field]
                    if not ns.Readable(v) then unknown = true
                    elseif v > 0 then return true end
                end
            end
        end
        if unknown then return nil end
        return false
    end)
    if not ok then return nil end
    return result
end
T.SpellCostsMana = SpellCostsMana

function T:OnSpellCast(spellID)
    local costs = SpellCostsMana(spellID)
    if costs == false then return end   -- kostet kein Mana: zählt nicht (z. B. Reittier, Nahkampf)
    if costs == nil then
        -- Kosten unbekannt: die nächste Manaänderung entscheidet (siehe OnPower)
        self.lastCast = GetTime()
        if self.secret then self.est = nil end
        return
    end
    self.lastCast = GetTime()
    -- Bei lesbaren Werten erkennt OnPower den Verbrauch zuverlässiger (z. B. Freizauber).
    if self.secret then
        self:StartFSR()
        local cost = SpellManaCost(spellID)
        if self.est and cost then
            self.est = math.max(0, self.est - cost)
        else
            self.est = nil          -- Kosten unbekannt: Schätzung erst bei vollem Mana wieder
        end
    end
end

-- Abfragen für die Anzeige ---------------------------------------------------
function T:InFSR(now)
    return (now or GetTime()) < self.fsrEnd
end

function T:FSRRemaining(now)
    return math.max(0, self.fsrEnd - (now or GetTime()))
end

-- Mana-Regeneration pro 5 Sekunden: außerhalb und innerhalb der 5-Sek.-Regel.
-- GetManaRegen liefert Mana pro Sekunde (normal, beim Zaubern). Ohne lesbare Werte
-- wird die normale Regeneration aus dem letzten Tick geschätzt (Tick alle 2 s).
function T:GetMP5()
    local base, casting
    if GetManaRegen then
        local ok, b, c = pcall(GetManaRegen)
        if ok and ns.Readable(b) and ns.Readable(c) then
            base, casting = b * 5, c * 5
            self.lastMP5Base, self.lastMP5Cast = base, casting
        end
    end
    -- Im Kampf hält das Spiel die Regeneration geheim: die letzten lesbaren Werte zeigen
    if not base then base = self.lastMP5Base end
    if not casting then casting = self.lastMP5Cast end
    if not base and ns.Readable(self.tickAmount) and type(self.tickAmount) == "number" then
        base = self.tickAmount * (5 / TICK_INTERVAL)
    end
    return base, casting
end

-- Fortschritt bis zum nächsten Tick (0..1) oder nil, wenn noch kein Tick bekannt ist
-- oder seit TICK_TIMEOUT keiner mehr kam (volles Mana, auch bei geheimen Werten)
function T:TickProgress(now)
    if not self.lastTick then return nil end
    local dt = (now or GetTime()) - self.lastTick
    if dt > TICK_TIMEOUT then return nil end
    return (dt % TICK_INTERVAL) / TICK_INTERVAL
end

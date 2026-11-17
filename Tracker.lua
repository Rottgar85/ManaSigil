-- ManaSigil – Logik: 5-Sekunden-Regel und Mana-Ticks
local _, ns = ...

local T = {}
ns.Tracker = T

local FSR_DURATION = 5     -- Sekunden ohne Manaverbrauch bis zur vollen Regeneration
local TICK_INTERVAL = 2    -- Server-Tick der Mana-Regeneration
local MIN_TICK_GAP = 1.5   -- kleinere Abstände gelten nicht als neuer Tick (z. B. Tränke)

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

function T:OnPower()
    local cur = UnitPower("player", ns.MANA)
    if not ns.Readable(cur) then
        -- Geheimer Wert: nicht vergleichen; FSR wird dann über Zauberkosten erkannt.
        self.secret = true
        self.lastMana = nil
        return
    end
    self.secret = false
    local now = GetTime()
    local last = self.lastMana
    if last then
        if cur < last then
            self:StartFSR(now)
        elseif cur > last and now >= self.fsrEnd then
            if not self.lastTick or (now - self.lastTick) >= MIN_TICK_GAP then
                self.lastTick = now
                self.tickAmount = cur - last
                ns.Display:OnTick(self.tickAmount)
            end
        end
    end
    self.lastMana = cur
end

-- Fallback, falls Manawerte geheim sind: Kostet der Zauber Mana?
local function SpellCostsMana(spellID)
    local getter = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
    if not getter or not spellID then return false end
    local ok, result = pcall(function()
        local costs = getter(spellID)
        if type(costs) ~= "table" then return false end
        for _, c in ipairs(costs) do
            if ns.Readable(c.type) and c.type == ns.MANA then
                for _, field in ipairs({ "cost", "minCost", "costPercent" }) do
                    local v = c[field]
                    if ns.Readable(v) and v > 0 then return true end
                end
            end
        end
        return false
    end)
    return ok and result
end

function T:OnSpellCast(spellID)
    -- Bei lesbaren Werten erkennt OnPower den Verbrauch zuverlässiger (z. B. Freizauber).
    if self.secret and SpellCostsMana(spellID) then
        self:StartFSR()
    end
end

-- Abfragen für die Anzeige ---------------------------------------------------
function T:InFSR(now)
    return (now or GetTime()) < self.fsrEnd
end

function T:FSRRemaining(now)
    return math.max(0, self.fsrEnd - (now or GetTime()))
end

-- Fortschritt bis zum nächsten Tick (0..1) oder nil, wenn noch kein Tick bekannt ist
function T:TickProgress(now)
    if not self.lastTick then return nil end
    local dt = (now or GetTime()) - self.lastTick
    return (dt % TICK_INTERVAL) / TICK_INTERVAL
end

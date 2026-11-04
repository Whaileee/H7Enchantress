-- Creature stats: Heroes VII strength, Heroes II shape.
--
-- A new creature starts as a copy of its donor (model, abilities, stats). Its strength must fit the town slot it
-- takes (the Sylvan creature it replaces: same tier, cost, power value), and its character should be Heroes II's:
--   * hit points and damage: the donor's, scaled by (slot power value / donor power value)
--   * attack/defence: the slot creature's attack + defence, split in the Heroes II attack:defence ratio
--   * damage spread: the Heroes II min:max ratio around the scaled average
--   * movement and initiative: the slot creature's, adjusted by the Heroes II speed rank
--     (1 very slow, 2 average, 3 fast, 4 very fast, 5 ultra fast, 6 faster still)
-- Heroes VII keeps a second set of stats for skirmish games (mSkirmish*); both sets are derived the same way.

local S = {}

local function get(o, k)
    local ok, v = pcall(function() return o[k] end)
    if ok then return v end
end

local function set(o, k, v)
    return (pcall(function() o[k] = v end))
end

local function round(x) return math.floor(x + 0.5) end

-- Stat name -> property name, for the campaign set and the skirmish set.
local NAMES = {
    [""] = { Hitpoints = "mHitpoints", Min = "mMinimumDamage", Max = "mMaximumDamage", Attack = "mAttack",
             Defense = "mDefense", Move = "mMovementPoints", Init = "mInitiative", Power = "mPowerValue",
             Xp = "mXp", Growth = "mGrowthratePercent", Cost = "mUnitCost" },
    Skirmish = { Hitpoints = "mSkirmishHitpoints", Min = "mSkirmishMinimumDamage", Max = "mSkirmishMaximumDamage",
             Attack = "mSkirmishAttack", Defense = "mSkirmishDefense", Move = "mSkirmishMovementPoints",
             Init = "mSkirmishInitiative", Power = "mSkirmishPowerValue", Xp = "mSkirmishXp",
             Growth = "mSkirmishGrowthRatePercent", Cost = "mSkirmishUnitCost" },
}

-- Fields that describe the slot rather than the creature: copied from the replaced Sylvan creature.
S.slot_fields = { "mTier", "mCreatureLevel" }

local function apply_set(creature, donor, slot, h2, N)
    for _, k in ipairs({ "Power", "Xp", "Growth" }) do
        local v = get(slot, N[k])
        if v ~= nil then set(creature, N[k], v) end
    end
    local ok, cost = pcall(function() return h7.to_table(slot[N.Cost]) end)
    if ok and cost then set(creature, N.Cost, cost) end

    local dpow, spow = get(donor, N.Power) or 0, get(slot, N.Power) or 0
    local f = (dpow > 0 and spow > 0) and math.max(0.5, math.min(3.0, spow / dpow)) or 1.0

    local hp = math.max(1, round((get(donor, N.Hitpoints) or 1) * f))
    set(creature, N.Hitpoints, hp)

    local avg = ((get(donor, N.Min) or 1) + (get(donor, N.Max) or 1)) / 2 * f
    local lo = math.max(1, round(2 * avg * h2.min / (h2.min + h2.max)))
    local hi = math.max(lo, round(2 * avg * h2.max / (h2.min + h2.max)))
    set(creature, N.Min, lo)
    set(creature, N.Max, hi)

    local total = (get(slot, N.Attack) or 1) + (get(slot, N.Defense) or 1)
    local atk = math.max(1, round(total * h2.atk / (h2.atk + h2.def)))
    set(creature, N.Attack, atk)
    set(creature, N.Defense, math.max(1, total - atk))

    local speedFactor = 0.8 + 0.1 * h2.speed
    local move, init = get(slot, N.Move), get(slot, N.Init)
    if move then set(creature, N.Move, math.max(1, round(move * speedFactor))) end
    if init then set(creature, N.Init, math.max(1, round(init * speedFactor))) end

    return ("x%.2f hp=%d dmg=%d-%d atk=%d def=%d move=%s init=%s"):format(f, hp, lo, hi, atk, total - atk,
        tostring(get(creature, N.Move)), tostring(get(creature, N.Init)))
end

-- Returns a short text describing the result (for the log).
function S.apply(creature, donor, slot, h2)
    for _, n in ipairs(S.slot_fields) do
        local v = get(slot, n)
        if v ~= nil then set(creature, n, v) end
    end
    local main = apply_set(creature, donor, slot, h2, NAMES[""])
    apply_set(creature, donor, slot, h2, NAMES.Skirmish)
    return main
end

return S

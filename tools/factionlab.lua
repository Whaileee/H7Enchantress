-- Faction lab: dumps everything the Enchantress mod needs to know about Sylvan (and the donor creatures) and
-- tests the object factory. Run at the main menu: copy into <Game>\H7ModEngine\exec\.
-- Output: <Game>\H7ModEngine\dumps\factionlab.txt (+ a short summary in logs\engine.log).

local out = {}
local function w(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end out[#out + 1] = table.concat(t, " ") end

local function short(v)
    if type(v) == "userdata" then
        local ok, n = pcall(function() return v:get_full_name() end)
        if ok then return n end
        local ok2, props = pcall(h7.properties, v)
        if ok2 and type(props) == "table" then
            local parts = {}
            for _, p in ipairs(props) do
                local okv, x = pcall(function() return v[p.name] end)
                local sx
                if not okv then sx = "?"
                elseif type(x) == "userdata" then
                    local okn, n = pcall(function() return x:get_name() end)
                    if okn then sx = n else
                        local okl, len = pcall(function() return #x end)
                        sx = okl and ("array[" .. tostring(len) .. "]") or "{...}"
                    end
                else sx = tostring(x) end
                parts[#parts + 1] = p.name .. "=" .. sx
                if #parts > 12 then parts[#parts + 1] = "..." break end
            end
            return "{" .. table.concat(parts, ", ") .. "}"
        end
    end
    return tostring(v)
end

local function dump_value(prefix, v, depth)
    depth = depth or 0
    local ok, len = pcall(function() return #v end)
    if type(v) == "userdata" and ok and type(len) == "number" and not pcall(function() return v:get_name() end) then
        w(prefix, "array[" .. len .. "]")
        for i = 1, math.min(len, 40) do dump_value(prefix .. "  [" .. i .. "]", v[i], depth + 1) end
        return
    end
    w(prefix, short(v))
end

local function dump_object(o, title)
    w("")
    w("=== " .. (title or "") .. " " .. (o and o:get_full_name() or "nil"))
    if not o then return end
    for _, p in ipairs(h7.properties(o)) do
        if p.owner ~= "Object" and p.owner ~= "Actor" and not p.name:match("^VfTable") then
            local ok, v = pcall(function() return o[p.name] end)
            if ok then dump_value(("  %-28s %-16s"):format(p.name, p.type), v) else w("  " .. p.name, "<error " .. tostring(v) .. ">") end
        end
    end
end

local Object = h7.find_class("Core.Object"):get_default()
local function load(path, cls)
    local o = h7.find(path)
    if o then return o end
    local ok, r = pcall(function() return Object:DynamicLoadObject(path, h7.find_class(cls), true) end)
    w("load", path, ok and tostring(r) or ("error " .. tostring(r)))
    return ok and r or nil
end

local gd = h7.find("H7Config.H7GameData")
w("GameData", gd)
local sylvan = h7.find("H7Factions.H7FactionSylvan")

-- Factions and per-faction lists
for i = 1, #gd.mFactions do local f = gd.mFactions[i]; w("faction", i, f and f:get_full_name()) end
w("neutral", gd.mNeutralFaction, "random", gd.mRandomFaction)
for i = 1, #gd.mCreatureLists do
    local e = gd.mCreatureLists[i]
    w("creatureList", i, short(e.Faction))
    dump_value("   ", e.CreatureList)
end
local heroCount = 0
for i = 1, #gd.mHeroPool do
    local h = gd.mHeroPool[i]
    local ok, f = pcall(function() return h:GetFaction() end)
    if ok and f == sylvan then heroCount = heroCount + 1; w("sylvanHero", h:get_full_name()) end
end
w("sylvan heroes in mHeroPool:", heroCount, "of", #gd.mHeroPool)
for i = 1, #gd.mGenericTownNames do w("townNames", i, short(gd.mGenericTownNames[i])) end

dump_object(sylvan, "FACTION")
local okTown, town = pcall(function() return sylvan:GetStartTown() end)
w("GetStartTown", okTown, town)
if okTown and town then
    dump_object(town, "START TOWN")
    for i = 1, #town.mBuildingTemplates do
        local b = town.mBuildingTemplates[i].Building
        w("building", i, b and b:get_full_name(), "built=", town.mBuildingTemplates[i].IsBuilt)
    end
end

for _, name in ipairs({ "FaeryTrees", "FaeryWoods", "HuntersCabin", "HuntersLodge", "BladeDancerTerrace",
    "BladeDanceArena", "StoneCircle", "StoneRing", "SunGarden", "MoonGlade", "HallowGrove", "SacredGrove",
    "TreantRefuge", "TreantSanctum", "DragonAltar", "DragonShrine" }) do
    dump_object(h7.find("H7TownBuildingSylvan.A_Sylvan_" .. name), "DWELLING")
end

for _, p in ipairs({ "Creature_Pixie.A_CreaturePixie", "Creature_Sprite.A_CreatureSprite",
    "Creature_Hunter.A_CreatureHunter", "Creature_MasterHunter.A_CreatureMasterHunter",
    "Creature_Druid.A_CreatureDruid", "Creature_DruidElder.A_CreatureDruidElder",
    "Creature_SunDeer.A_CreatureSunDeer", "Creature_Defender.A_CreatureDefender",
    "Creature_Shieldguard.A_CreatureShieldguard", "Creature_Firebird.A_CreatureFirebird",
    "Creature_BladeDancer.A_CreatureBladeDancer", "Creature_GreenDragon.A_CreatureGreenDragon" }) do
    dump_object(load(p, "MMH7Game.H7Creature"), "CREATURE")
end

for _, c in ipairs({ "Might_Balanced", "Magic_Balanced" }) do
    dump_object(h7.find("H7HeroClasses.Sylvan.A_Sylvan_" .. c), "HEROCLASS")
end
if gd.mHeroPool[1] then dump_object(gd.mHeroPool[1], "HERO SAMPLE") end

-- Object factory
w("")
w("=== FACTORY can_create=", h7.can_create and h7.can_create())
if h7.can_create and h7.can_create() then
    local ok, pkg = pcall(h7.package, "H2EnchantressLab")
    w("package", ok, pkg)
    if ok then
        local ok2, f, created = pcall(h7.clone, sylvan, "LabFaction", pkg)
        w("clone faction", ok2, f, created)
        if ok2 then
            w("  path", f:get_path_name(), "name", f:GetName(), "color", short(f.mColor))
            w("  same layout", f.mTownBuildTreeLayout == sylvan.mTownBuildTreeLayout)
        end
        local pixie = h7.find("Creature_Pixie.A_CreaturePixie")
        local ok3, c, created3 = pcall(h7.clone, pixie, "LabSprite", pkg)
        w("clone creature", ok3, c, created3)
        if ok3 then
            w("  hp", c.mHitpoints, pixie.mHitpoints, "attack", c.mAttack, pixie.mAttack, "name", c:GetName())
            c.mNameInst = "Lab Sprite"
            w("  renamed", c:GetName(), "original", pixie:GetName())
        end
    end
end

local path = [[N:\Ubisoft\games\Might and Magic Heroes VII\H7ModEngine\dumps\factionlab.txt]]
local f = io.open(path, "w")
if f then f:write(table.concat(out, "\n")) f:close() h7.log("[factionlab] wrote", #out, "lines to", path)
else for _, l in ipairs(out) do h7.log("[factionlab]", l) end end
h7.log("[factionlab] DONE")

-- Builds the Enchantress faction by copying Sylvan's game objects and registering the copies with the game.
--
-- Steps (see build()):
--   1. preload   Sylvan keeps many references lazily (DynLoadObjectProperty); call their getters first so the
--                copies get real values
--   2. clone     faction, start town, level-1 fort, map dwellings, every town building, the new creatures,
--                hero classes, heroes, the random-hero placeholder and the town-name list
--   3. remap     every reference inside a copy that points at a copied Sylvan object is pointed at the copy
--   4. customise names, colours, stats, creature upgrade links, the build-tree layout
--   5. register  H7GameData lists: factions, creature lists, heroes, random heroes, town names
-- The game's "Del*" functions release lazy references to save memory; the copies can't reload them, so
-- hooks.lua stops those calls for our objects.

local D = mod.require("data")
local S = mod.require("stats")

local F = {}

local lang = "INT"
local function text(t) return t[lang] or t.INT end

local function addr(o) return o and o:get_address() end
local function isobj(v) return type(v) == "userdata" and pcall(function() return v:get_address() end) end

local function try(o, fn, ...)
    local args = table.pack(...)
    local ok, r = pcall(function() return o[fn](o, table.unpack(args, 1, args.n)) end)
    if ok then return r end
end
local function get(o, k) local ok, v = pcall(function() return o[k] end) if ok then return v end end
local function set(o, k, v)
    local ok, err = pcall(function() o[k] = v end)
    if not ok then h7.warn("set " .. tostring(k) .. " on " .. tostring(o) .. ": " .. tostring(err)) end
    return ok
end

F.map = {}      -- [address of a Sylvan/donor object] = its copy
F.ours = {}     -- [address of a copy] = copy
F.list = {}     -- copies in creation order
F.creatures = {} -- [address of a new creature] = { slot entry, "base" | "upg" }
F.stats = { cloned = 0, reused = 0, remapped = 0 }

local pkg, sylvan, gd

-- DynLoadObjectProperty fields (models, icons, town screens, start town...) are loaded on demand from the
-- object's package. A copy has no package, so it can never load them itself: load them on the original first,
-- then the copy inherits the pointers. Arrays of them need DynLoadObjectArrayProperty.
local DYN_ARRAYS = { mTownAssets = true }
local function dynload_all(o)
    local n = 0
    for _, p in ipairs(h7.properties(o)) do
        if p.type == "DynLoadObjectProperty" then
            if pcall(function() o:DynLoadObjectProperty(p.name) end) then n = n + 1 end
        elseif DYN_ARRAYS[p.name] then
            if pcall(function() o:DynLoadObjectArrayProperty(p.name) end) then n = n + 1 end
        end
    end
    return n
end
F.dynload_all = dynload_all

-- Loads every lazy field, then calls each named no-argument getter (some load more as a side effect).
local function preload(o, getters)
    if not o then return end
    dynload_all(o)
    for _, g in ipairs(getters) do try(o, g) end
end

-- After cloning: every lazy field set on the original must be set on the copy.
local function check_lazy(src, c)
    local missing = {}
    for _, p in ipairs(h7.properties(src)) do
        if p.type == "DynLoadObjectProperty" and get(src, p.name) ~= nil and get(c, p.name) == nil then
            if not set(c, p.name, get(src, p.name)) then missing[#missing + 1] = p.name end
        end
    end
    if #missing > 0 then h7.warn(c:get_name() .. " is missing " .. table.concat(missing, ", ")) end
end

F.sources = {} -- [address] = true for every object we copied from (their lazy fields must stay loaded)

local function raw_clone(src, name)
    F.sources[addr(src)] = true
    dynload_all(src)
    local c, created = h7.clone(src, name, pkg, h7.flags.RootSet)
    check_lazy(src, c)
    return c, created
end

local function clone(src, name)
    if not src then return nil end
    local key = addr(src)
    if F.map[key] then return F.map[key] end
    local c, created = raw_clone(src, name)
    F.map[key] = c
    if not F.ours[addr(c)] then
        F.ours[addr(c)] = c
        F.list[#F.list + 1] = c
    end
    if created then F.stats.cloned = F.stats.cloned + 1 else F.stats.reused = F.stats.reused + 1 end
    return c
end
F.clone = clone

function F.is_ours(o) return o ~= nil and F.ours[addr(o)] ~= nil end

local FACTION_GETTERS = {
    "GetFactionBannerIconPath", "GetDefaultGarrisonTown", "GetDefaultGarrisonFort", "GetFactionMarkerIcon",
    "GetFactionColorIcon", "GetFactionSepiaIcon", "GetFactionBanner", "GetFactionBannerStripes",
    "GetCaravanVisuals", "GetLoadscreenBackground", "GetStainedGlassGrid", "GetStainedGlassHighlight",
    "GetStainedGlassBase", "GetCouncilLeftStainedGlassGrid", "GetCouncilLeftStainedGlassHighlight",
    "GetCouncilLeftStainedGlassBase", "GetCouncilRightStainedGlassGrid", "GetCouncilRightStainedGlassHighlight",
    "GetCouncilRightStainedGlassBase", "GetPuzzle1", "GetPuzzle2", "GetPuzzle3", "GetPuzzle4", "GetPuzzle5",
    "GetPuzzle6", "GetPuzzle7", "GetPuzzle8", "GetDecalOuterTexture", "GetDecalInnerTexture",
    "GetDecalOuterTextureUPLAY", "GetDecalInnerTextureUPLAY", "GetFootprintUPLAY", "GetStartTown", "GetStartFort",
}
local TOWN_GETTERS = { "GetFactionBannerIconPath", "GetFactionWatermarkPath", "GetWallsIconPath", "GetGateIconPath",
    "GetTowerIconPath", "GetFactionPortalFramePath", "GetTownScreen", "GetIconPath" }
local BUILDING_GETTERS = { "GetTownAsset", "GetTownAssets", "GetFlashIconPath", "GetIcon" }
local UNIT_GETTERS = { "GetFlashArtworkPath", "GetFlashIconPath", "GetIcon", "GetFlashImagePath",
    "GetFactionSpecializationFrame" }

-- ---------------------------------------------------------------------------------------------------------
-- Remapping references inside the copies
-- ---------------------------------------------------------------------------------------------------------

local SKIP = { ObjectArchetype = true, Outer = true, Class = true, Name = true, ObjectFlags = true }
local remap_table = F.map -- what remap_object() replaces: F.map, or the army map for the army pass

local walk_struct

local function remap_slot(get_value, set_value, depth)
    local v = get_value()
    if v == nil then return end
    if isobj(v) then
        local r = remap_table[addr(v)]
        if r then set_value(r); F.stats.remapped = F.stats.remapped + 1 end
    elseif type(v) == "table" then -- static array: live element proxies, or values to write back
        local changed = false
        for i = 1, #v do
            local e = v[i]
            if isobj(e) then
                local r = remap_table[addr(e)]
                if r then v[i] = r; changed = true; F.stats.remapped = F.stats.remapped + 1 end
            elseif type(e) == "userdata" then
                walk_struct(e, depth + 1)
            end
        end
        if changed then set_value(v) end
    elseif type(v) == "userdata" then
        local okLen, n = pcall(function() return #v end)
        if okLen and type(n) == "number" then -- engine array
            for i = 1, n do
                remap_slot(function() return v[i] end, function(x) v[i] = x end, depth + 1)
            end
        else
            walk_struct(v, depth + 1)
        end
    end
end

walk_struct = function(s, depth)
    if depth > 6 then return end
    local ok, props = pcall(h7.properties, s)
    if not ok then return end
    for _, p in ipairs(props) do
        if not SKIP[p.name] then
            remap_slot(function() return get(s, p.name) end, function(x) set(s, p.name, x) end, depth)
        end
    end
end

-- Only game-defined members (H7* classes) of objects are walked: engine members (components, collision...) are
-- never remapped.
local function remap_object(o)
    for _, p in ipairs(h7.properties(o)) do
        if not SKIP[p.name] and p.owner:match("^A?H7") and not p.name:match("^VfTable") then
            remap_slot(function() return get(o, p.name) end, function(x) set(o, p.name, x) end, 0)
        end
    end
end

-- ---------------------------------------------------------------------------------------------------------
-- Build steps
-- ---------------------------------------------------------------------------------------------------------

local Utility = h7.find_class("MMH7Game.H7GameUtility"):get_default()
local ObjectCDO = h7.find_class("Core.Object"):get_default()

local function load(path)
    local o = h7.find(path)
    if o then return o end
    local cls = h7.find_class("Core.Object")
    local ok, r = pcall(function() return ObjectCDO:DynamicLoadObject(path, cls, true) end)
    if ok then return r end
end

local function first_loadable(paths)
    for _, p in ipairs(paths) do
        local o = load(p)
        if o then return o, p end
    end
end

-- The game's IsArchetype decides whether an object answers for itself or forwards to its ObjectArchetype.
local function ensure_archetype(o)
    local ok, is = pcall(function() return Utility:IsArchetype(o) end)
    if ok and is then return true end
    set(o, "ObjectArchetype", o:get_class():get_default())
    local ok2, is2 = pcall(function() return Utility:IsArchetype(o) end)
    h7.warn(("%s was not an archetype; ObjectArchetype reset -> IsArchetype=%s"):format(o:get_name(), tostring(ok2 and is2)))
    return ok2 and is2
end

local function suffix(o) return o:get_name() .. "_H2E" end

-- Every building reachable from the town's templates (upgrades, alternates, prerequisites).
local function collect_buildings(town)
    local seen, order = {}, {}
    local function visit(b)
        if not b or seen[addr(b)] then return end
        seen[addr(b)] = true
        order[#order + 1] = b
        visit(get(b, "mUpgrade"))
        visit(get(b, "mAlternate"))
        local pre = get(b, "mPrerequisites")
        if pre then for i = 1, #pre do visit(pre[i]) end end
    end
    local t = get(town, "mBuildingTemplates")
    for i = 1, (t and #t or 0) do visit(t[i].Building) end
    return order
end

local function sylvan_heroes()
    local list = {}
    for i = 1, #gd.mHeroPool do
        local h = gd.mHeroPool[i]
        local path = h:get_path_name()
        if try(h, "GetFaction") == sylvan and not path:find("Story") and not path:find("SCENARIO") then
            list[#list + 1] = h
        end
    end
    return list
end

local function class_kind(cls)
    local n = cls and cls:get_name() or ""
    return n:find("Might") and "might" or "magic"
end

function F.build()
    lang = (try(ObjectCDO, "GetLanguage") or "INT"):upper()
    gd = h7.find("H7Config.H7GameData")
    sylvan = h7.find("H7Factions.H7FactionSylvan")
    assert(gd, "H7Config.H7GameData not loaded")
    assert(sylvan, "Sylvan faction not loaded")
    assert(h7.can_create(), "this engine build cannot create objects")
    pkg = h7.package(D.package)

    -- 1. preload
    -- mStartTown, mLevel1Fort and the map dwellings are DynLoadObjectProperty fields (not visible to Lua), so the
    -- copies are reached through the getters, and hooks.lua makes the faction copy's getters return them.
    preload(sylvan, FACTION_GETTERS)
    local town = try(sylvan, "GetStartTown")
    assert(town, "Sylvan has no start town")
    local fort = try(sylvan, "GetStartFort")
    local dwellings = {}
    for _, t in ipairs({ 0, 1, 2, 3 }) do
        for _, c in ipairs({ 0, 1, 2 }) do
            local d = try(sylvan, "GetStartDwelling", t, c)
            if d then dwellings[#dwellings + 1] = { t, c, d } end
        end
    end
    preload(town, TOWN_GETTERS)
    local buildings = collect_buildings(town)
    for _, b in ipairs(buildings) do preload(b, BUILDING_GETTERS) end

    -- 2. clone: faction and its sites
    local faction = clone(sylvan, "H7FactionEnchantress")
    F.site = {}
    F.site.town = clone(town, "A_Town_Enchantress")
    if fort then preload(fort, TOWN_GETTERS); F.site.fort = clone(fort, "A_Fort_Enchantress") end
    F.site.dwellings = {}
    for _, e in ipairs(dwellings) do
        local d = e[3]
        F.site.dwellings[e[1] .. ":" .. e[2]] = clone(d, suffix(d))
    end
    for _, b in ipairs(buildings) do clone(b, suffix(b)) end

    -- creatures
    for _, e in ipairs(D.lineup) do
        local slotBase = load(e.replaces)
        local slotUpg = slotBase and get(slotBase, "mUpgradeOfCoreCreature")
        local donorB, pathB = first_loadable(e.base.donors)
        local donorU, pathU = first_loadable(e.upg.donors)
        if not (slotBase and donorB and donorU) then
            h7.warn(("%s: skipped (slot %s, donors %s / %s)"):format(e.key, tostring(slotBase), tostring(pathB), tostring(pathU)))
        else
            preload(donorB, UNIT_GETTERS); preload(donorU, UNIT_GETTERS)
            -- The donor may be the slot creature itself (Druid): clone() is keyed by source, so map explicitly.
            local b = raw_clone(donorB, e.base.id)
            local u = raw_clone(donorU, e.upg.id)
            for _, c in ipairs({ b, u }) do
                if not F.ours[addr(c)] then F.ours[addr(c)] = c; F.list[#F.list + 1] = c end
            end
            F.map[addr(slotBase)] = b
            if slotUpg then F.map[addr(slotUpg)] = u end
            e.created = { base = b, upg = u, slotBase = slotBase, slotUpg = slotUpg or slotBase, donorB = donorB, donorU = donorU }
            F.creatures[addr(b)] = { e, "base" }
            F.creatures[addr(u)] = { e, "upg" }
        end
    end

    -- heroes, classes, random hero, town names
    local heroes = sylvan_heroes()
    local byKind = { might = {}, magic = {} }
    for _, h in ipairs(heroes) do
        local cls = try(h, "GetHeroClass")
        if cls then
            clone(cls, suffix(cls))
            local k = class_kind(cls)
            byKind[k][#byKind[k] + 1] = h
        end
    end
    local used = { might = 0, magic = 0 }
    F.heroes = {}
    for _, hd in ipairs(D.heroes) do
        local pool = byKind[hd.class]
        if #pool == 0 then pool = heroes end
        if #pool > 0 then
            used[hd.class] = used[hd.class] + 1
            local donor = pool[(used[hd.class] - 1) % #pool + 1]
            preload(donor, UNIT_GETTERS)
            local h = raw_clone(donor, hd.id)
            if not F.ours[addr(h)] then F.ours[addr(h)] = h; F.list[#F.list + 1] = h end
            F.heroes[#F.heroes + 1] = { hero = h, data = hd, donor = donor }
        end
    end
    local randomHero
    for i = 1, #gd.mRandomHeroPool do
        local h = gd.mRandomHeroPool[i]
        if try(h, "GetFaction") == sylvan then randomHero = clone(h, "A_RandomHero_Enchantress") break end
    end
    local townNames
    for i = 1, #gd.mGenericTownNames do
        local t = gd.mGenericTownNames[i]
        -- (mods may point Sylvan's list at their own copy of the faction, so match the name too)
        local f = get(t, "mFaction")
        if f == sylvan or t:get_name() == "H7SylvanTownNames" then townNames = clone(t, "H7TownNames_Enchantress") break end
    end

    for _, c in ipairs(F.list) do ensure_archetype(c) end

    -- Localised texts are looked up by object name, which the copies don't have: copy the texts themselves.
    for _, b in ipairs(buildings) do
        local nb = F.map[addr(b)]
        local n, d = try(b, "GetName"), try(b, "GetDesc")
        if n then set(nb, "mName", n); set(nb, "mNameInst", n) end
        if d then set(nb, "mDesc", d); if get(nb, "mDescInst") ~= nil then set(nb, "mDescInst", d) end end
    end

    -- 3. remap
    for _, c in ipairs(F.list) do remap_object(c) end

    -- 4. customise
    local T = D.text
    set(faction, "mFactionName", text(T).faction)
    set(faction, "mFactionFortName", text(T).fort)
    set(faction, "mFactionArmyName", text(T).army)
    set(faction, "mColor", D.color)

    -- build-tree layout: it names buildings by object name
    local layout = get(sylvan, "mTownBuildTreeLayout") or ""
    for _, b in ipairs(buildings) do
        local old, new = b:get_name(), suffix(b)
        layout = layout:gsub("%f[%w_]" .. old:gsub("%p", "%%%0") .. "%f[^%w_]", (new:gsub("%%", "%%%%")))
    end
    set(faction, "mTownBuildTreeLayout", layout)
    local newTown = F.map[addr(town)]
    local gui = get(newTown, "mGUIconfig")
    if gui and gui ~= "" then
        for _, b in ipairs(buildings) do
            gui = gui:gsub("%f[%w_]" .. b:get_name():gsub("%p", "%%%0") .. "%f[^%w_]", (suffix(b):gsub("%%", "%%%%")))
        end
        set(newTown, "mGUIconfig", gui)
    end

    -- creatures: faction, names, upgrade links, stats
    for _, e in ipairs(D.lineup) do
        local c = e.created
        if c then
            for _, which in ipairs({ "base", "upg" }) do
                local cr, def = c[which], e[which]
                set(cr, "mFaction", faction)
                set(cr, "mName", text(def.name))
                set(cr, "mNameInst", text(def.name))
                set(cr, "mHeroPediaOverwrite", nil)
                local slot = which == "base" and c.slotBase or c.slotUpg
                local donor = which == "base" and c.donorB or c.donorU
                local ok, msg = pcall(S.apply, cr, donor, slot, def.h2)
                h7.log(("%-16s <- %-28s slot %-24s %s"):format(text(def.name), donor:get_name(), slot:get_name(),
                    ok and msg or ("stats failed: " .. tostring(msg))))
            end
            set(c.base, "mUpgradeOfCoreCreature", c.upg)
            set(c.base, "mBaseCreature", nil)
            set(c.upg, "mUpgradeOfCoreCreature", nil)
            set(c.upg, "mBaseCreature", c.base)
        end
    end

    -- buildings: dwelling names follow their creature
    local extra = {}
    for _, b in ipairs(buildings) do
        local nb = F.map[addr(b)]
        if nb:is_a("H7TownDwelling") then
            local pool = get(nb, "mCreaturePool")
            local cr = pool and pool.Creature
            local info = cr and F.creatures[addr(cr)]
            if info then
                local names = text(info[1].buildings)
                local n = info[2] == "base" and names[1] or names[2]
                set(nb, "mName", n)
                set(nb, "mNameInst", n)
            elseif cr then
                extra[addr(nb)] = nb
                h7.log("Extra dwelling " .. nb:get_name() .. " keeps " .. cr:get_name())
            end
        end
    end
    F.blocked_creatures = {}
    if D.extra_dwellings == "block" then
        -- block the extra dwellings, their upgrades, and every building that needs one of them
        local changed = true
        while changed do
            changed = false
            for _, b in ipairs(buildings) do
                local nb = F.map[addr(b)]
                if not extra[addr(nb)] then
                    local pre = get(nb, "mPrerequisites")
                    local needs = false
                    for i = 1, (pre and #pre or 0) do if pre[i] and extra[addr(pre[i])] then needs = true end end
                    for _, ob in ipairs(buildings) do
                        local o = F.map[addr(ob)]
                        if extra[addr(o)] and get(o, "mUpgrade") == nb then needs = true end
                    end
                    if needs then extra[addr(nb)] = nb; changed = true end
                end
            end
        end
        local t = newTown.mBuildingTemplates
        local n = 0
        for i = 1, #t do
            local b = t[i].Building
            if b and extra[addr(b)] then
                t[i].IsBlocked = true
                n = n + 1
                local pool = b:is_a("H7TownDwelling") and get(b, "mCreaturePool")
                if pool and pool.Creature then F.blocked_creatures[addr(pool.Creature)] = true end
            end
            -- an alternate that is blocked is no choice at all
            if b and get(b, "mAlternate") and extra[addr(get(b, "mAlternate"))] then set(b, "mAlternate", nil) end
        end
        h7.log(("Blocked %d buildings without a Heroes II counterpart"):format(n))
    end

    -- hero classes and heroes
    for _, c in ipairs(F.list) do
        if c:is_a("H7HeroClass") then
            local n = class_kind(c) == "might" and text(T).class_might or text(T).class_magic
            set(c, "mName", n)
        end
    end
    for _, h in ipairs(F.heroes) do
        set(h.hero, "mName", h.data.name)
        set(h.hero, "mNameInst", h.data.name)
        set(h.hero, "mGlobalName", nil)
        set(h.hero, "mTransientName", "")
    end
    if townNames then
        set(townNames, "mFaction", faction)
        set(townNames, "mTownNames", text(D.town_names))
    end
    if randomHero then
        set(randomHero, "mName", text(T).random_hero)
        set(randomHero, "mNameInst", text(T).random_hero)
        set(randomHero, "mGlobalName", nil)
    end

    -- 5. register
    local function add_unique(arr, o)
        for i = 1, #arr do if arr[i] == o then return false end end
        arr:add(o)
        return true
    end
    add_unique(gd.mFactions, faction)
    for _, h in ipairs(F.heroes) do
        add_unique(gd.mHeroPool, h.hero)
        add_unique(gd.mHeropediaHeroes, h.hero)
    end
    if randomHero then add_unique(gd.mRandomHeroPool, randomHero) end
    if townNames then add_unique(gd.mGenericTownNames, townNames) end

    local haveList = false
    for i = 1, #gd.mCreatureLists do if gd.mCreatureLists[i].Faction == faction then haveList = true end end
    if not haveList then
        for i = 1, #gd.mCreatureLists do
            local entry = gd.mCreatureLists[i]
            if entry.Faction == sylvan then
                local levels = {}
                local src = entry.CreatureList.Creatures
                for lv = 1, #src do
                    local list = {}
                    local arr = src[lv].Creatures
                    for k = 1, #arr do
                        local cr = arr[k]
                        if cr and not F.blocked_creatures[addr(cr)] then list[#list + 1] = F.map[addr(cr)] or cr end
                    end
                    levels[lv] = { Creatures = list }
                end
                gd.mCreatureLists:add({ Faction = faction, CreatureList = { Creatures = levels } })
                break
            end
        end
    end

    -- Armies (hero starting armies, duel armies, town guards): Sylvan creatures without a Heroes II counterpart
    -- (Dryads, Treants, mod creatures) become the lineup creature of the same tier.
    local armyMap = setmetatable({}, { __index = F.map })
    local byKey = {}
    for _, e in ipairs(D.lineup) do if e.created then byKey[e.key] = e.created end end
    local function fallback(cr)
        local key = D.army_fallback[get(cr, "mTier") or 0] or D.army_fallback[0]
        local c = byKey[key]
        if not c then return nil end
        return get(cr, "mBaseCreature") and c.upg or c.base
    end
    for i = 1, #gd.mCreatureLists do
        local entry = gd.mCreatureLists[i]
        if entry.Faction == sylvan then
            local src = entry.CreatureList.Creatures
            for lv = 1, #src do
                local arr = src[lv].Creatures
                for k = 1, #arr do
                    local cr = arr[k]
                    if cr and not F.map[addr(cr)] then armyMap[addr(cr)] = fallback(cr) end
                end
            end
        end
    end
    for k in pairs(F.blocked_creatures) do
        if not rawget(armyMap, k) then
            local cr = nil
            for _, b in ipairs(buildings) do
                local pool = get(F.map[addr(b)], "mCreaturePool")
                if pool and pool.Creature and addr(pool.Creature) == k then cr = pool.Creature end
            end
            if cr then armyMap[k] = fallback(cr) end
        end
    end

    -- Duel mode: armies are offered per faction (by their creatures' faction) and heroes come from mDuelHeroes.
    F.duel_armies, F.duel_heroes = {}, {}
    local n = 0
    for i = 1, #gd.mDuelArmies do
        local a = gd.mDuelArmies[i]
        local name = a:get_name()
        if name:find("Sylvan") and not a:get_path_name():find("boss") then
            n = n + 1
            F.duel_armies[#F.duel_armies + 1] = clone(a, ("H7_DuelArmy_Enchantress_%02d"):format(n))
        end
    end
    local k = 0
    for i = 1, #gd.mDuelHeroes do
        local h = gd.mDuelHeroes[i]
        if try(h, "GetFaction") == sylvan and k < #D.heroes then
            k = k + 1
            local hd = D.heroes[k]
            preload(h, UNIT_GETTERS)
            local dh = clone(h, "A_DuelHero_" .. hd.name .. "_H2")
            F.duel_heroes[#F.duel_heroes + 1] = { hero = dh, data = hd }
        end
    end
    for _, x in ipairs(F.duel_armies) do ensure_archetype(x); remap_object(x) end
    for _, x in ipairs(F.duel_heroes) do
        ensure_archetype(x.hero); remap_object(x.hero)
        set(x.hero, "mName", x.data.name)
        set(x.hero, "mNameInst", x.data.name)
        set(x.hero, "mGlobalName", nil)
        set(x.hero, "mTransientName", "")
    end

    remap_table = armyMap
    for _, c in ipairs(F.list) do
        if not c:is_a("H7TownDwelling") and not c:is_a("H7Creature") then remap_object(c) end
    end
    remap_table = F.map

    for _, x in ipairs(F.duel_armies) do add_unique(gd.mDuelArmies, x) end
    for _, x in ipairs(F.duel_heroes) do add_unique(gd.mDuelHeroes, x.hero) end

    F.faction, F.town, F.sylvan = faction, newTown, sylvan
    F.lang = lang
    h7.log(("Enchantress built: %d objects (%d new, %d reused), %d references remapped, %d heroes, %d duel armies, %d duel heroes, layout %d chars")
        :format(#F.list, F.stats.cloned, F.stats.reused, F.stats.remapped, #F.heroes, #F.duel_armies, #F.duel_heroes, #layout))
    return faction
end

return F

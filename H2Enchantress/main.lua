-- H2Enchantress: the Heroes II Enchantress (Sorceress) town as a new playable faction.
--
-- data.lua    lineup, names, heroes (edit this to tweak the faction)
-- stats.lua   how creature stats are derived (Heroes VII strength, Heroes II shape)
-- faction.lua builds the faction from copies of Sylvan's game objects and registers it
-- hooks.lua   keeps the copies working (names, lazily loaded assets, town music)

local F = mod.require("faction")
local H = mod.require("hooks")

if not h7.can_create or not h7.can_create() then
    h7.error("This engine build cannot create game objects; the Enchantress faction is not available.")
    return
end

local built = false
local function try_build()
    if built then return end
    built = true
    local ok, err = pcall(F.build)
    if not ok then
        h7.error("Building the faction failed: " .. tostring(err))
        return
    end
    local lang = (h7.find_class("Core.Object"):get_default():GetLanguage() or "INT"):upper()
    H.install(lang)
end

-- The game data is only complete once the boot map (h7logoentry) is gone: build at the main menu (or right away
-- when the mod is (re)loaded there or later).
local function ready() return h7.first("H7CouncilPlayerController") ~= nil or h7.first("H7AdventureController") ~= nil end
if ready() then
    try_build()
else
    h7.on("map_loaded", function(map)
        if map ~= "h7logoentry" then try_build() end
    end)
end

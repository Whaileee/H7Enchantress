-- H2Enchantress data: everything a player might want to tweak lives here.
--
-- The faction is built at runtime by copying Sylvan's game objects (faction, town, buildings, hero classes,
-- heroes) and creature archetypes from Sylvan, Fortress and the neutrals, then renaming and re-statting the
-- copies. Nothing of Sylvan itself is changed.

local D = {}

-- Name of the package that holds every object the mod creates. Save games refer to objects by path
-- ("H2Enchantress.A_CreatureDwarf"), so never rename it once people have saves with this faction.
D.package = "H2Enchantress"

-- Texts by game language (Object.GetLanguage(): "INT", "POL", ...). Missing languages fall back to INT.
D.text = {
    INT = {
        faction = "Enchantress",
        fort = "Enchantress Castle",
        army = "Enchantress Army",
        class_might = "Ranger",
        class_magic = "Sorceress",
        random_hero = "Random Enchantress Hero",
    },
    POL = {
        faction = "Czarodziejka",
        fort = "Zamek Czarodziejki",
        army = "Armia Czarodziejki",
        class_might = "Łowczyni",
        class_magic = "Czarodziejka",
        random_hero = "Losowy bohater Czarodziejki",
    },
}

-- Faction colour (banner/UI), H2 Sorceress green-gold.
D.color = { R = 46, G = 160, B = 92, A = 255 }

-- The Heroes II Sorceress town lineup, as stats from the original game for reference:
--   Sprite        4/2  1-2 dmg    2 HP  average    flies, no retaliation          growth 8   50 gold
--   Dwarf         6/5  2-4 dmg   20 HP  very slow  25% magic resistance           growth 6  200 gold
--   Battle Dwarf  6/6  2-4 dmg   20 HP  average    25% magic resistance                     250 gold
--   Elf           4/3  2-3 dmg   15 HP  average    archer                         growth 4  250 gold
--   Grand Elf     5/5  2-3 dmg   15 HP  very fast  archer, shoots twice                     300 gold
--   Druid         7/5  5-8 dmg   25 HP  fast       archer                         growth 3  350 gold
--   Greater Druid 7/7  5-8 dmg   25 HP  very fast  archer                                   400 gold
--   Unicorn      10/9  7-14 dmg  40 HP  fast       20% chance to blind            growth 2  500 gold
--   Phoenix     12/10 20-40 dmg 100 HP  ultra fast flies, hits 2 hexes, fire immune growth 1 1500 gold + 1 mercury
--
-- Each H7 slot has a base and an upgraded creature. `donor` is the H7 archetype that is copied (model,
-- animations, abilities); the alternatives in `donors` are tried in order (community packs first, vanilla last).
-- `replaces` is the Sylvan creature whose slot (tier, dwelling, cost, growth) the new creature takes over.
-- `h2` gives the Heroes II profile used to shape the copy's stats (see stats.lua): the copy keeps the donor's
-- overall strength for its tier, and its attack/defence/damage/HP/speed are redistributed in Heroes II's
-- proportions.
D.lineup = {
    {
        slot = "core1",
        -- the Sylvan creature (and, through its upgrade link, its upgrade) whose town slot this takes
        replaces = "Creature_Pixie.A_CreaturePixie",
        buildings = { INT = { "Treehouse", "Upg. Treehouse" }, POL = { "Domek na drzewie", "Ulepszony domek na drzewie" } },
        key = "Sprite",
        base = { id = "A_CreatureSprite_H2", donors = { "Creature_Pixie.A_CreaturePixie" },
                 name = { INT = "Sprite", POL = "Duszek" },
                 h2 = { atk = 4, def = 2, min = 1, max = 2, hp = 2, speed = 2 } },
        upg  = { id = "A_CreatureElderSprite_H2", donors = { "Creature_Sprite.A_CreatureSprite" },
                 name = { INT = "Elder Sprite", POL = "Starszy duszek" },
                 h2 = { atk = 5, def = 3, min = 1, max = 3, hp = 3, speed = 3 } },
    },
    {
        slot = "core2",
        -- the Sylvan creature (and, through its upgrade link, its upgrade) whose town slot this takes
        replaces = "Creature_BladeDancer.A_CreatureBladeDancer",
        buildings = { INT = { "Cottage", "Upg. Cottage" }, POL = { "Chatka", "Ulepszona chatka" } },
        key = "Dwarf",
        base = { id = "A_CreatureDwarf_H2", donors = { "Creature_Defender.A_CreatureDefender" },
                 name = { INT = "Dwarf", POL = "Krasnolud" },
                 h2 = { atk = 6, def = 5, min = 2, max = 4, hp = 20, speed = 1 } },
        upg  = { id = "A_CreatureBattleDwarf_H2", donors = { "Creature_Shieldguard.A_CreatureShieldguard" },
                 name = { INT = "Battle Dwarf", POL = "Krasnolud bojowy" },
                 h2 = { atk = 6, def = 6, min = 2, max = 4, hp = 20, speed = 2 } },
        magic_resistance = 25,
    },
    {
        slot = "core3",
        -- the Sylvan creature (and, through its upgrade link, its upgrade) whose town slot this takes
        replaces = "Creature_Hunter.A_CreatureHunter",
        buildings = { INT = { "Archery Range", "Upg. Archery Range" }, POL = { "Strzelnica", "Ulepszona strzelnica" } },
        key = "Elf",
        base = { id = "A_CreatureElf_H2", donors = { "Creature_Hunter.A_CreatureHunter" },
                 name = { INT = "Elf", POL = "Elf" },
                 h2 = { atk = 4, def = 3, min = 2, max = 3, hp = 15, speed = 2 } },
        upg  = { id = "A_CreatureGrandElf_H2", donors = { "Creature_MasterHunter.A_CreatureMasterHunter" },
                 name = { INT = "Grand Elf", POL = "Wielki elf" },
                 h2 = { atk = 5, def = 5, min = 2, max = 3, hp = 15, speed = 4 } },
    },
    {
        slot = "elite1",
        -- the Sylvan creature (and, through its upgrade link, its upgrade) whose town slot this takes
        replaces = "Creature_Druid.A_CreatureDruid",
        buildings = { INT = { "Stonehenge", "Upg. Stonehenge" }, POL = { "Kamienny krąg", "Ulepszony kamienny krąg" } },
        key = "Druid",
        base = { id = "A_CreatureDruid_H2", donors = { "Creature_Druid.A_CreatureDruid" },
                 name = { INT = "Druid", POL = "Druid" },
                 h2 = { atk = 7, def = 5, min = 5, max = 8, hp = 25, speed = 3 } },
        upg  = { id = "A_CreatureGreaterDruid_H2", donors = { "Creature_DruidElder.A_CreatureDruidElder" },
                 name = { INT = "Greater Druid", POL = "Wielki druid" },
                 h2 = { atk = 7, def = 7, min = 5, max = 8, hp = 25, speed = 4 } },
    },
    {
        slot = "elite2",
        -- the Sylvan creature (and, through its upgrade link, its upgrade) whose town slot this takes
        replaces = "Creature_MoonDoe.A_CreatureMoonDoe",
        buildings = { INT = { "Fenced Meadow", "Upg. Fenced Meadow" }, POL = { "Ogrodzona łąka", "Ulepszona ogrodzona łąka" } },
        key = "Unicorn",
        base = { id = "A_CreatureUnicorn_H2",
                 donors = { "New_Creatures_Sylvan.Sylvan_unicorn.A_Creature_Unicorn_extra_elite-sylvan",
                            "Creature_SunDeer.A_CreatureSunDeer" },
                 name = { INT = "Unicorn", POL = "Jednorożec" },
                 h2 = { atk = 10, def = 9, min = 7, max = 14, hp = 40, speed = 3 } },
        upg  = { id = "A_CreatureSilverUnicorn_H2",
                 donors = { "New_Creatures_Sylvan.Sylvan_unicorn.A_Creature_Unicorn_extra_elite-sylvan",
                            "Creature_SunDeer.A_CreatureSunDeer" },
                 name = { INT = "Silver Unicorn", POL = "Srebrny jednorożec" },
                 h2 = { atk = 11, def = 10, min = 8, max = 15, hp = 45, speed = 4 } },
        blind_chance = 20,
    },
    {
        slot = "champion1",
        -- the Sylvan creature (and, through its upgrade link, its upgrade) whose town slot this takes
        replaces = "Creature_GreenDragon.A_CreatureGreenDragon",
        buildings = { INT = { "Red Tower", "Upg. Red Tower" }, POL = { "Czerwona wieża", "Ulepszona czerwona wieża" } },
        key = "Phoenix",
        base = { id = "A_CreaturePhoenix_H2", donors = { "Creature_Firebird.A_CreatureFirebird" },
                 name = { INT = "Phoenix", POL = "Feniks" },
                 h2 = { atk = 12, def = 10, min = 20, max = 40, hp = 100, speed = 5 } },
        upg  = { id = "A_CreatureGreaterPhoenix_H2", donors = { "Creature_Firebird.A_CreatureFirebird" },
                 name = { INT = "Greater Phoenix", POL = "Wielki feniks" },
                 h2 = { atk = 13, def = 11, min = 22, max = 42, hp = 110, speed = 6 } },
        fire_immune = true,
    },
}

-- Town names for new Enchantress towns.
D.town_names = {
    INT = { "Bramblewood", "Faerie Glen", "Rainbow Hollow", "Silverleaf", "Moonwell", "Stonehenge Vale",
            "Sprite's Rest", "Unicorn Meadow", "Emerald Spring", "Phoenix Roost" },
    POL = { "Jeżynowy Gaj", "Dolina Wróżek", "Tęczowa Kotlina", "Srebrny Liść", "Księżycowa Studnia",
            "Dolina Kamiennego Kręgu", "Przystań Duszków", "Łąka Jednorożców", "Szmaragdowe Źródło",
            "Gniazdo Feniksa" },
}

-- Sylvan town buildings with creatures that have no Heroes II counterpart (e.g. the Treant dwelling):
--   "keep"  - they stay in the town with their Sylvan creatures
--   "block" - they are marked unavailable in new Enchantress towns (Heroes II had six dwellings)
D.extra_dwellings = "block"

-- In armies (starting armies, duel armies, town guards) Sylvan creatures without a counterpart are replaced by the
-- lineup creature (by `key`) of the same tier (0 core, 1 elite, 2 champion); upgraded ones by its upgrade.
D.army_fallback = { [0] = "Dwarf", [1] = "Unicorn", [2] = "Phoenix" }

-- Heroes II Sorceress heroes (copies of Sylvan heroes with these names). `class` is "magic" or "might".
D.heroes = {
    { id = "A_Hero_Ariel_H2", name = "Ariel", class = "magic" },
    { id = "A_Hero_Astra_H2", name = "Astra", class = "magic" },
    { id = "A_Hero_Carlawn_H2", name = "Carlawn", class = "magic" },
    { id = "A_Hero_Luna_H2", name = "Luna", class = "magic" },
    { id = "A_Hero_Natasha_H2", name = "Natasha", class = "might" },
    { id = "A_Hero_Rebecca_H2", name = "Rebecca", class = "might" },
    { id = "A_Hero_Troyan_H2", name = "Troyan", class = "might" },
    { id = "A_Hero_Vatawna_H2", name = "Vatawna", class = "might" },
}

return D

# H2Enchantress

A [H7ModEngine](https://github.com/Whaileee/H7ModEngine) mod for Might & Magic Heroes VII (v2.2.1) that adds the
**Heroes II Enchantress (Sorceress) town as a new playable faction**, built at runtime from existing Heroes VII
content. No game files are changed.

| Heroes II | Model | Town slot (taken from Sylvan) |
|---|---|---|
| Sprite / Elder Sprite | Pixie / Sprite | Pixie |
| Dwarf / Battle Dwarf | Fortress Defender / Shieldguard | Blade Dancer |
| Elf / Grand Elf | Hunter / Master Hunter | Hunter |
| Druid / Greater Druid | Druid / Druid Elder | Druid |
| Unicorn / Silver Unicorn | community Unicorn if installed, else Sun Deer | Moon Doe |
| Phoenix / Greater Phoenix | Firebird | Green Dragon |

Each creature keeps the strength of its town slot, with attack/defence, damage spread and speed in Heroes II
proportions (both the campaign and the skirmish stat sets). Dwellings carry the Heroes II names (Treehouse,
Cottage, Archery Range, Stonehenge, Fenced Meadow, Red Tower); Sylvan buildings without a Heroes II counterpart
are unavailable. Eight Heroes II heroes (Ariel, Astra, Carlawn, Luna, Natasha, Rebecca, Troyan, Vatawna), duel
armies and duel heroes are included. Texts in English and Polish.

## Requirements

- Heroes VII v2.2.1 with the Trial by Fire content (Fortress creatures)
- H7ModEngine with object creation (`h7.can_create()`, branch `feature/object-factory` or later)

## Install

Copy the `H2Enchantress` folder to `<Game>\H7ModEngine\mods\`, or run `deploy.bat`. The mod ships disabled: turn
it on in the game's **Mods** menu, then restart the game (the faction is built at the main menu).

## How it works

- `H2Enchantress/data.lua`: lineup, names, heroes, town names, options. Edit this to tweak the faction.
- `H2Enchantress/stats.lua`: how creature stats are derived.
- `H2Enchantress/faction.lua`: copies Sylvan's faction, town, fort, map dwellings, town buildings, hero classes,
  heroes and duel data into the package `H2Enchantress`, points every reference at the copies, and registers them
  in `H7Config.H7GameData`.
- `H2Enchantress/hooks.lua`: keeps the copies working: stops the game releasing lazily loaded assets (models,
  icons, town screens) the copies can't reload, and answers name lookups.
- `tools/factionlab.lua`: a lab script for the engine's `exec` folder that dumps Sylvan's structure.

## Status

Experimental. Verified: the faction appears in the faction lists and a duel with it runs. Not yet verified:
skirmish and adventure maps (town screen, recruiting, AI), save/load. Planned: Heroes II abilities (dwarf
magic resistance, unicorn blinding, phoenix fire immunity), stat balance, hero portraits and biographies.

Save games refer to the faction's objects by name (`H2Enchantress.*`): keep the mod enabled to load them.

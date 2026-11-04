-- Hooks that keep the copied objects working.

local D = mod.require("data")
local F = mod.require("faction")

local H = {}

-- The game frees lazily loaded references (textures, town screen prefabs, start town...) with Del* functions and
-- reloads them on demand with DynLoadObjectProperty, which only works for objects loaded from a package. For our
-- copies the reference would be gone for good, so those calls are skipped for them.
local DEL_CLASSES = { "H7Faction", "H7Town", "H7Fort", "H7Dwelling", "H7TownBuilding", "H7EditorHero", "H7Creature",
    "H7HeroClass" }
local NOT_RELEASE = { DeleteCaravan = true, DeleteRefundBuffer = true }

local function hook_releases()
    local seen, n = {}, 0
    for _, cls in ipairs(DEL_CLASSES) do
        local ok, fns = pcall(h7.functions, "MMH7Game." .. cls)
        if ok then
            for _, f in ipairs(fns) do
                local path = "MMH7Game." .. f.owner .. "." .. f.name
                if f.name:match("^Del") and not NOT_RELEASE[f.name] and not seen[path] then
                    seen[path] = true
                    -- Also for the originals we copied from: their assets are shared with our copies.
                    local okHook, err = pcall(h7.hook, path, function(self)
                        if F.is_ours(self) or F.sources[self:get_address()] then return true end
                    end)
                    if okHook then n = n + 1 else h7.warn("hook " .. path .. ": " .. tostring(err)) end
                end
            end
        end
    end
    return n
end

function H.install(lang)
    local T = D.text[lang] or D.text.INT
    local n = hook_releases()

    -- Names that go through the localisation tables: answer with ours for our objects.
    h7.hook_post("MMH7Game.H7Faction.GetName", function(self, args, ret)
        if F.is_ours(self) then return T.faction end
    end)
    pcall(h7.hook_post, "MMH7Game.H7Faction.GetDefaultFortName", function(self, args, ret)
        if F.is_ours(self) then return T.fort end
    end)
    h7.hook_post("MMH7Game.H7HeroClass.GetName", function(self, args, ret)
        if F.is_ours(self) then
            return self:get_name():find("Might") and T.class_might or T.class_magic
        end
    end)

    -- The faction's sites are DynLoadObjectProperty fields Lua can't write: answer from the getters.
    h7.hook_post("MMH7Game.H7Faction.GetStartTown", function(self, args, ret)
        if F.faction and self == F.faction then return F.site.town end
    end)
    h7.hook_post("MMH7Game.H7Faction.GetStartFort", function(self, args, ret)
        if F.faction and self == F.faction and F.site.fort then return F.site.fort end
    end)
    h7.hook_post("MMH7Game.H7Faction.GetStartDwelling", function(self, args, ret)
        if F.faction and self == F.faction then
            local d = F.site.dwellings[tostring(args.Type) .. ":" .. tostring(args.championChoice)]
            if d then return d end
        end
    end)

    -- Town screen music is chosen by faction name; use Sylvan's.
    pcall(h7.hook, "MMH7Game.H7SoundController.SwitchTownScreenMusic", function(self, args)
        if args.Faction == "H7FACTIONENCHANTRESS" then args.Faction = "H7FACTIONSYLVAN" end
    end)

    h7.log(("Hooks installed: %d release functions guarded"):format(n))
end

return H

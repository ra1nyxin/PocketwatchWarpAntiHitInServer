local postinit
GLOBAL = {
    TUNING = { POCKETWATCH_WARP_COOLDOWN = 2 },
    TECH = { NONE = {} },
    TheWorld = { ismastersim = true },
    STRINGS = { NAMES = {}, RECIPE_DESC = {}, CHARACTERS = { GENERIC = { DESCRIBE = {} }, WANDA = { DESCRIBE = {} } } },
}
Ingredient = function() return {} end
Asset = function() return {} end
RegisterInventoryItemAtlas = function() end
AddRecipe2 = function() end
AddPrefabPostInit = function(_, fn) postinit = fn end
dofile("modmain.lua")

local function run(current_api)
    local original_calls, cooldowns, state_changes = 0, 0, 0
    local charged, has_history, blocked_state, riding = true, true, false, false
    local function original(self, attacker, damage, weapon, stimuli, spdamage, ...)
        original_calls = original_calls + 1
        return "original", ...
    end
    local combat = {}
    if current_api then
        combat.GetAttacked_Internal = original
        function combat:GetAttacked(...)
            return self:GetAttacked_Internal(...)
        end
    else
        combat.GetAttacked = original
    end
    local watch = {
        prefab = "pocketwatch_bloodbound",
        components = {
            pocketwatch = { CanCast = function() return charged end },
            rechargeable = {
                IsCharged = function() return charged end,
                Discharge = function(_, time) assert(time == 2); cooldowns = cooldowns + 1; charged = false end,
            },
        },
    }
    local inst = {
        components = {
            combat = combat,
            health = { IsDead = function() return false end, IsInvincible = function() return false end },
            rider = { IsRiding = function() return riding end },
            inventory = { FindItem = function(_, predicate) return predicate(watch) and watch or nil end },
            positionalwarp = { GetHistoryPosition = function() if has_history then return 10, 0, 20 end end },
        },
        sg = {
            HasStateTag = function(_, tag) return tag == "nointerrupt" and blocked_state end,
            GoToState = function(_, name, data)
                assert(name == "pocketwatch_warpback_pst")
                assert(data.warpback_data.dest_x == 10 and data.warpback_data.dest_z == 20)
                state_changes = state_changes + 1
            end,
        },
        ListenForEvent = function() end,
    }
    postinit(inst)
    local attack = current_api and combat.GetAttacked_Internal or combat.GetAttacked
    assert(attack(combat, {}, 50, nil, nil, nil, true) == false)
    assert(cooldowns == 1 and state_changes == 1 and original_calls == 0)
    assert(attack(combat, {}, 50, nil, nil, nil, true) == "original")
    charged, has_history = true, false
    assert(attack(combat, {}, 50) == "original")
    has_history, blocked_state = true, true
    assert(attack(combat, {}, 50) == "original")
    blocked_state, riding = false, true
    assert(attack(combat, {}, 50) == "original")
    riding = false
    assert(combat:GetAttacked(nil, 50, nil, "darkness") == false)
    assert(cooldowns == 2 and state_changes == 2 and original_calls == 4)
end

run(true)
run(false)
print("attack hook regression tests passed")

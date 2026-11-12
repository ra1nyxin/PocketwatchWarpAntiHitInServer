local _G = GLOBAL
local TUNING = _G.TUNING

PrefabFiles = { "pocketwatch_bloodbound" }
Assets = { Asset("ATLAS", "images/inventoryimages/pocketwatch_bloodbound.xml") }
RegisterInventoryItemAtlas("images/inventoryimages/pocketwatch_bloodbound.xml", "pocketwatch_bloodbound.tex")

_G.STRINGS.NAMES.POCKETWATCH_BLOODBOUND = "血刻表"
_G.STRINGS.RECIPE_DESC.POCKETWATCH_BLOODBOUND = "给危险一个扑空的机会。"
_G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.POCKETWATCH_BLOODBOUND = "它好像比我更怕挨打。"
_G.STRINGS.CHARACTERS.WANDA.DESCRIBE.POCKETWATCH_BLOODBOUND = "哎呀，看来你来晚了一步！"

AddRecipe2("pocketwatch_bloodbound", {
    Ingredient("horrorfuel", 5),
    Ingredient("voidcloth", 2),
    Ingredient("redgem", 1),
    Ingredient("pocketwatch_parts", 1),
    Ingredient("goldnugget", 2),
}, _G.TECH.NONE, {
    builder_tag = "clockmaker",
    atlas = "images/inventoryimages/pocketwatch_bloodbound.xml",
    image = "pocketwatch_bloodbound.tex",
    no_deconstruction = function(inst) return not inst:HasTag("pocketwatch_inactive") end,
}, { "CHARACTER" })

local function IsReadyWatch(item)
    return item.prefab == "pocketwatch_bloodbound"
        and item.components.pocketwatch ~= nil
        and item.components.pocketwatch:CanCast()
        and item.components.rechargeable ~= nil
        and item.components.rechargeable:IsCharged()
end

AddPrefabPostInit("wanda", function(inst)
    if not _G.TheWorld.ismastersim then return end
    local function RefreshMarker()
        if inst:IsValid() and inst.components.positionalwarp ~= nil and inst.components.inventory ~= nil then
            inst.components.positionalwarp:EnableMarker(
                not inst:HasTag("playerghost") and inst.components.inventory:HasItemWithTag("pocketwatch_warp", 1))
        end
    end
    local function QueueMarkerRefresh()
        inst:DoTaskInTime(0, RefreshMarker)
    end
    inst:ListenForEvent("itemget", QueueMarkerRefresh)
    inst:ListenForEvent("itemlose", QueueMarkerRefresh)
    inst:ListenForEvent("equip", QueueMarkerRefresh)
    inst:ListenForEvent("unequip", QueueMarkerRefresh)
    local combat = inst.components.combat
    -- Current DST routes both direct hits and DoAttack through the internal method.
    local attack_method = combat.GetAttacked_Internal ~= nil and "GetAttacked_Internal" or "GetAttacked"
    local old_getattacked = combat[attack_method]
    combat[attack_method] = function(self, attacker, damage, weapon, stimuli, spdamage, ...)
        local health, sg = inst.components.health, inst.sg
        local rider = inst.components.rider
        if ((damage or 0) > 0 or spdamage ~= nil)
            and health ~= nil and not health:IsDead() and not health:IsInvincible()
            and not inst.is_teleporting and sg ~= nil
            and not sg:HasStateTag("nointerrupt") and not sg:HasStateTag("jumping")
            and not (rider ~= nil and rider:IsRiding()) then
            local inventory = inst.components.inventory
            local warp = inst.components.positionalwarp
            local watch = inventory ~= nil and inventory:FindItem(IsReadyWatch) or nil
            local x, y, z
            if watch ~= nil and warp ~= nil then
                x, y, z = warp:GetHistoryPosition(false)
            end
            if x ~= nil then
                watch.components.rechargeable:Discharge(TUNING.POCKETWATCH_WARP_COOLDOWN)
                sg:GoToState("pocketwatch_warpback_pst", {
                    warpback_data = { dest_x = x, dest_y = y, dest_z = z },
                    castfxcolour = watch.castfxcolour,
                })
                return false
            end
        end
        return old_getattacked(self, attacker, damage, weapon, stimuli, spdamage, ...)
    end
end)

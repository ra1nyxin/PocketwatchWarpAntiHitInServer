local PocketWatchCommon = require "prefabs/pocketwatch_common"

local assets = {
    Asset("ANIM", "anim/pocketwatch.zip"),
    Asset("ANIM", "anim/pocketwatch_warp.zip"),
}

local function DoCast(inst, doer)
    if doer == nil or doer.prefab ~= "wanda" or doer.components.positionalwarp == nil then
        return false
    end
    local x, y, z = doer.components.positionalwarp:GetHistoryPosition(false)
    if x ~= nil then
        inst.components.rechargeable:Discharge(TUNING.POCKETWATCH_WARP_COOLDOWN)
        doer.sg.statemem.warpback = { dest_x = x, dest_y = y, dest_z = z }
        return true
    end
    x, y, z = doer.Transform:GetWorldPosition()
    if not IsTeleportingPermittedFromPointToPoint(x, y, z, x, y, z) then
        return false, "NO_TELEPORT_ZONE"
    end
    return false, "WARP_NO_POINTS_LEFT"
end

local function fn()
    local inst = PocketWatchCommon.common_fn("pocketwatch", "pocketwatch_warp", DoCast, true,
        { "pocketwatch_warp", "pocketwatch_warp_casting" })
    inst.GetActionVerb_CAST_POCKETWATCH = "WARP"
    inst.AnimState:SetMultColour(1, .22, .22, 1)
    if not TheWorld.ismastersim then return inst end
    inst.castfxcolour = { 1, .12, .12 }
    inst.components.inventoryitem.imagename = "pocketwatch_warp"
    return inst
end

return Prefab("pocketwatch_bloodbound", fn, assets, { "pocketwatch_warpback_fx", "pocketwatch_warpbackout_fx" })

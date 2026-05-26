local ESX = exports[Config.Settings.Core]:getSharedObject()

function Notify(message, type, duration)
    if duration == nil then
        duration = 3000
    end

    if Config.Settings.Notify == 'ft_notification' then
        exports.ft_notification:ShowNotify(message, type, duration)
    elseif Config.Settings.Notify == 'esx' then
        ESX.ShowNotification(message)
    elseif Config.Settings.Notify == 'ox_lib' then
        lib.notify({ title = L('notify.title'), description = message, position = 'top', type = type, showDuration = duration })
    end
end

RegisterNetEvent("ft_admin:doSelfRevive", function()
    TriggerServerEvent("txsv:req:healMyself")
    Notify(L('notify.revived'), 'success')
end)

RegisterNetEvent('ft_admin:TeleportToPlayerCoords', function(coords)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z + 1.0, false, false, false, true)
end)

local previousClothes = {}
local showDutyText = false

RegisterNUICallback("toggleDuty", function(data, cb)
    local enabled = data.enabled
    local ped = PlayerPedId()

    if Config.DutyTag then
        TriggerServerEvent("ft_admin:setDutyStatus", enabled)
    end

    local dutyClothSet = nil
    if isMale then
        dutyClothSet = Config.DutyCloth.male
    elseif isFemale then
        dutyClothSet = Config.DutyCloth.female
    else
        dutyClothSet = Config.DutyCloth.male
    end

    if enabled then

        if Config.DutyGodMode then
            SetEntityInvincible(ped, true)
            SetPlayerInvincible(playerId, true)
            SetPedCanRagdoll(ped, false)
            ClearPedBloodDamage(ped)
        end

        previousClothes = {}

        for k, cloth in pairs(dutyClothSet) do
            local originalDrawable = GetPedDrawableVariation(ped, cloth.drawable)
            local originalTexture = GetPedTextureVariation(ped, cloth.drawable)

            previousClothes[cloth.drawable] = {
                drawable = originalDrawable,
                texture = originalTexture
            }

            SetPedComponentVariation(ped, cloth.drawable, cloth.slot, cloth.texture, 2)
        end
    else
        if Config.DutyGodMode then
            SetEntityInvincible(ped, false)
            SetPlayerInvincible(playerId, false)
            SetPedCanRagdoll(ped, true)
        end

        for drawable, saved in pairs(previousClothes) do
            SetPedComponentVariation(ped, drawable, saved.drawable, saved.texture, 2)
        end

        previousClothes = {}
    end

    cb({})
end)
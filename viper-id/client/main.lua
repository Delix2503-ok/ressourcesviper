local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Envoi de position au serveur toutes les 3s ──────────────────────────────
CreateThread(function()
    while true do
        Wait(3000)
        local c = GetEntityCoords(PlayerPedId())
        TriggerServerEvent('viper-id:updatePos', c.x, c.y, c.z)
    end
end)

-- ─── ox_target : icône œil sur les joueurs ───────────────────────────────────
-- Utilise 'event' (TriggerEvent local) et non 'onSelect' (closure dans ox_target)
exports.ox_target:addGlobalPlayer({
    {
        name     = 'viper_view_id',
        icon     = 'fas fa-id-card',
        label    = 'Voir ID',
        distance = 5.0,
        event    = 'viper-id:localShowId',
    }
})

AddEventHandler('viper-id:localShowId', function(data)
    local ped = data.entity
    if not ped or ped == 0 then return end

    local localIdx = NetworkGetPlayerIndexFromPed(ped)

    if localIdx == -1 then
        for _, pid in ipairs(GetActivePlayers()) do
            if GetPlayerPed(pid) == ped then
                localIdx = pid
                break
            end
        end
    end

    if localIdx == -1 then return end

    local serverId = GetPlayerServerId(localIdx)
    local name     = GetPlayerName(localIdx) or 'Inconnu'

    QBCore.Functions.Notify('ID : ' .. serverId .. ' | ' .. name, 'primary', 6000)
end)

-- ─── Hologramme déco (style vipergun) ────────────────────────────────────────
local function drawTextAt(x, y, z, text)
    local cam  = GetGameplayCamCoords()
    local dist = #(cam - vector3(x, y, z))
    local fov  = (1 / GetGameplayCamFov()) * 100
    local size = math.min((1 / math.max(dist, 1)) * 2.5 * fov, 0.8)

    SetTextScale(size, size)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(57, 255, 20, 230)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

RegisterNetEvent('viper-id:showHologram', function(x, y, z, serverId, playerName, reason)
    CreateThread(function()
        local endTime = GetGameTimer() + 30000
        while GetGameTimer() < endTime do
            Wait(0)
            local t     = GetGameTimer() / 400.0
            local pulse = math.abs(math.sin(t)) * 0.25 + 0.2
            DrawMarker(28, x, y, z, 0,0,0, 0,0,0, pulse,pulse,pulse, 57,255,20,80, false, true, 2, false, nil, nil, false)
            drawTextAt(x, y, z + 1.7, ('ID : %d'):format(serverId))
            drawTextAt(x, y, z + 1.3, playerName)
            drawTextAt(x, y, z + 0.9, reason)
        end
    end)
end)

local QBCore    = exports['qb-core']:GetCoreObject()
local panelOpen = false

RegisterNetEvent('viper-hud:client:openAdmin', function(players, state)
    panelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action  = 'openAdmin',
        players = players,
        config  = {
            weather    = state.weather,
            traffic    = state.traffic,
            hunger     = state.hunger,
            blips      = state.blips,
            safeCoords = string.format('vector4(%.2f, %.2f, %.2f, %.2f)',
                state.safeCoords.x, state.safeCoords.y,
                state.safeCoords.z, state.safeCoords.h)
        }
    })
end)

RegisterNUICallback('closeAdmin', function(data, cb)
    panelOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

CreateThread(function()
    while true do
        Wait(0)
        if panelOpen and IsControlJustPressed(0, 200) then
            panelOpen = false
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'closeAdmin' })
        end
    end
end)

RegisterNUICallback('adminAction', function(data, cb)
    TriggerServerEvent('viper-hud:server:adminAction', data)
    cb('ok')
end)

RegisterNUICallback('getPlayers', function(data, cb)
    TriggerServerEvent('viper-hud:server:getPlayers')
    cb('ok')
end)

RegisterNetEvent('viper-hud:client:updatePlayerList', function(players)
    SendNUIMessage({ action = 'updatePlayers', players = players })
end)

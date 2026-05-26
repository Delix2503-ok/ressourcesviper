local adminOpen = false

-- ----------------------------------------------------------------
-- Commande /admingun
-- ----------------------------------------------------------------
RegisterCommand('admingun', function()
    TriggerServerEvent('vipergun:admin:getFullData')
end, false)

-- ----------------------------------------------------------------
-- Ouverture du panel
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:admin:openPanel', function(data)
    adminOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action  = 'openAdmin',
        coffres = data.coffres,
        peds    = data.peds,
    })
end)

-- ----------------------------------------------------------------
-- Mise à jour temps réel de la liste des PNJ (après add/remove)
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:admin:updatePeds', function(peds)
    SendNUIMessage({ action = 'updatePeds', peds = peds })
end)

-- ----------------------------------------------------------------
-- Callbacks NUI → Serveur
-- ----------------------------------------------------------------
RegisterNUICallback('admin:addPed', function(data, cb)
    TriggerServerEvent('vipergun:admin:addPed', data)
    cb('ok')
end)

RegisterNUICallback('admin:removePed', function(data, cb)
    TriggerServerEvent('vipergun:admin:removePed', data)
    cb('ok')
end)

RegisterNUICallback('admin:useMyPosition', function(_, cb)
    local ped     = PlayerPedId()
    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    cb({ x = coords.x, y = coords.y, z = coords.z, heading = heading })
end)

RegisterNUICallback('admin:updatePlayerCoffres', function(data, cb)
    TriggerServerEvent('vipergun:admin:updatePlayerCoffres', data)
    cb('ok')
end)

RegisterNUICallback('admin:tpToPed', function(data, cb)
    local x       = tonumber(data.x)
    local y       = tonumber(data.y)
    local z       = tonumber(data.z)
    local heading = tonumber(data.heading) or 0.0
    if x and y and z then
        local ped = PlayerPedId()
        -- Place d'abord en hauteur pour éviter de tomber dans le sol
        RequestCollisionAtCoord(x, y, z)
        SetEntityCoords(ped, x, y, z + 4.0, false, false, false, false)
        SetEntityHeading(ped, heading)
        -- Thread : attend que la collision charge puis pose sur le sol
        CreateThread(function()
            local tries = 0
            while not HasCollisionLoadedAroundEntity(ped) and tries < 40 do
                Wait(100)
                tries = tries + 1
            end
            Wait(150)
            local found, gz = GetGroundZFor_3dCoord(x, y, z + 5.0, false)
            if found and gz > 0.0 then
                SetEntityCoords(ped, x, y, gz + 0.5, false, false, false, false)
            else
                -- Fallback : on re-essaie une fois
                Wait(300)
                found, gz = GetGroundZFor_3dCoord(x, y, z + 5.0, false)
                if found and gz > 0.0 then
                    SetEntityCoords(ped, x, y, gz + 0.5, false, false, false, false)
                end
            end
        end)
    end
    cb('ok')
end)

RegisterNUICallback('closeAdmin', function(_, cb)
    adminOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- ----------------------------------------------------------------
-- Notifications depuis le serveur
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:admin:notify', function(msg, ntype)
    lib.notify({
        title       = 'Admin Panel',
        description = msg,
        type        = ntype or 'success',
        duration    = 3000,
    })
end)

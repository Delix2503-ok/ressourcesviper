local IsJailed      = false
local JailRemaining = 0
local JailLocation  = nil
local AdminOpen     = false

-- ─── Jail start ──────────────────────────────────────────────────────────────
RegisterNetEvent('viperjail:start', function(seconds, location)
    IsJailed      = true
    JailRemaining = seconds
    JailLocation  = location

    DoScreenFadeOut(500)
    Wait(600)
    local ped = PlayerPedId()
    SetEntityCoords(ped, location.x, location.y, location.z, false, false, false, false)
    SetEntityHeading(ped, location.heading or 0.0)
    DoScreenFadeIn(500)

    SendNUIMessage({ type = 'showJail', remaining = seconds })
end)

-- ─── Tick ────────────────────────────────────────────────────────────────────
RegisterNetEvent('viperjail:tick', function(remaining)
    JailRemaining = remaining
    SendNUIMessage({ type = 'tick', remaining = remaining })
end)

-- ─── Release ─────────────────────────────────────────────────────────────────
RegisterNetEvent('viperjail:release', function(spawn)
    IsJailed      = false
    JailRemaining = 0
    JailLocation  = nil

    -- Laisser un frame au thread d'enforcement pour qu'il voie IsJailed=false
    -- et sorte de son bloc avant qu'on dégèle
    Wait(0)

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)    -- désactivé dès que le thread d'enforcement s'arrête
    SetEntityCanBeDamaged(ped, true)

    DoScreenFadeOut(500)
    Wait(600)
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
    SetEntityHeading(ped, spawn.heading or 0.0)
    FreezeEntityPosition(ped, false)   -- sécurité : re-dégèle après TP
    SetEntityInvincible(ped, false)    -- redondant mais garanti après TP
    SetEntityCanBeDamaged(ped, true)
    DoScreenFadeIn(500)

    SendNUIMessage({ type = 'hideJail' })
    lib.notify({ title = 'Prison', description = 'Vous avez été libéré.', type = 'success', duration = 6000 })
end)

-- ─── Sync on load ────────────────────────────────────────────────────────────
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(4000)
    TriggerServerEvent('viperjail:requestSync')
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(5000)
    TriggerServerEvent('viperjail:requestSync')
end)

-- ─── Freeze + enforcement + inventory block ───────────────────────────────────
-- Wait(0) en PREMIER puis vérification IsJailed — évite la race condition
-- où le thread re-freeze après que le release handler ait dégelé.
CreateThread(function()
    while true do
        Wait(0)
        if not IsJailed then
            Wait(299)
        else
            local ped = PlayerPedId()

            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetEntityCanBeDamaged(ped, false)

            if JailLocation then
                local c  = GetEntityCoords(ped)
                local dx = c.x - JailLocation.x
                local dy = c.y - JailLocation.y
                local dz = c.z - JailLocation.z
                if math.sqrt(dx*dx + dy*dy + dz*dz) > Config.JailRadius then
                    SetEntityCoords(ped, JailLocation.x, JailLocation.y, JailLocation.z, false, false, false, false)
                end
            end

            DisableAllControlActions(0)
            EnableControlAction(0, 1,   true)  -- Look LR
            EnableControlAction(0, 2,   true)  -- Look UD
            EnableControlAction(0, 106, true)  -- Zoom
            EnableControlAction(0, 245, true)  -- Look behind

            pcall(function() exports['ox_inventory']:closeInventory() end)
        end
    end
end)

-- ─── Panel Admin ─────────────────────────────────────────────────────────────
RegisterNetEvent('viperjail:admin:open', function(online, offline, locations)
    AdminOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'openAdmin', online = online, offline = offline, locations = locations })
end)

RegisterNetEvent('viperjail:admin:locationAdded', function(loc)
    SendNUIMessage({ type = 'locationAdded', location = loc })
end)

RegisterNetEvent('viperjail:admin:locationDeleted', function(locId)
    SendNUIMessage({ type = 'locationDeleted', id = locId })
end)

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────
RegisterNUICallback('closeAdmin', function(_, cb)
    AdminOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback('jailPlayer', function(data, cb)
    TriggerServerEvent('viperjail:admin:jailPlayer', data.src, data.minutes, data.locationId, data.reason)
    cb({})
end)

RegisterNUICallback('unjailPlayer', function(data, cb)
    TriggerServerEvent('viperjail:admin:unjailPlayer', data.src)
    cb({})
end)

RegisterNUICallback('unjailOffline', function(data, cb)
    TriggerServerEvent('viperjail:admin:unjailOffline', data.citizenid)
    cb({})
end)

RegisterNUICallback('addLocation', function(data, cb)
    TriggerServerEvent('viperjail:admin:addLocation', data.name)
    cb({})
end)

RegisterNUICallback('deleteLocation', function(data, cb)
    TriggerServerEvent('viperjail:admin:deleteLocation', data.id)
    cb({})
end)

RegisterNUICallback('refreshAdmin', function(_, cb)
    cb({})
    TriggerServerEvent('viperjail:admin:refresh')
end)

RegisterNUICallback('getLogs', function(data, cb)
    cb({})
    TriggerServerEvent('viperjail:admin:getLogs', data.license or '')
end)

RegisterNetEvent('viperjail:admin:logsData', function(logs)
    SendNUIMessage({ type = 'logsData', logs = logs })
end)

-- ─── Nettoyage ───────────────────────────────────────────────────────────────
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if IsJailed then
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
        SetEntityCanBeDamaged(ped, true)
    end
    if AdminOpen then SetNuiFocus(false, false) end
    SendNUIMessage({ type = 'hideJail' })
end)

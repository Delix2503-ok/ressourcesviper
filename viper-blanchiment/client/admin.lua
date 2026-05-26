-- admin.lua partage les globales avec main.lua (même contexte Lua client)
-- isAdminPanelOpen est global pour que main.lua puisse y accéder

isAdminPanelOpen   = false
local isViperAdmin = false

-- ─── Statut admin reçu du serveur ─────────────────────────────────────────────

RegisterNetEvent('viper-blanchiment:client:adminStatus', function(status)
    isViperAdmin = status
end)

-- ─── Commande /blanchiradmin ──────────────────────────────────────────────────

RegisterCommand('blanchiradmin', function()
    if not isViperAdmin then
        QBCore.Functions.Notify('Accès refusé.', 'error', 3000)
        return
    end

    if isAdminPanelOpen then
        isAdminPanelOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeAdmin' })
        return
    end

    isAdminPanelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action    = 'openAdmin',
        spots     = spots,
        pedModels = Config.PedModels,
    })
end, false)

-- ─── Callbacks NUI Admin ──────────────────────────────────────────────────────

RegisterNUICallback('closeAdmin', function(_, cb)
    isAdminPanelOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('addSpot', function(data, cb)
    local playerPed = PlayerPedId()
    local coords    = GetEntityCoords(playerPed)
    local heading   = GetEntityHeading(playerPed)

    TriggerServerEvent('viper-blanchiment:server:addSpot', {
        name     = data.name or '',
        pedModel = data.pedModel or Config.PedModel,
        x        = coords.x,
        y        = coords.y,
        z        = coords.z,
        heading  = heading,
    })
    cb('ok')
end)

RegisterNUICallback('removeSpot', function(data, cb)
    TriggerServerEvent('viper-blanchiment:server:removeSpot', tonumber(data.id))
    cb('ok')
end)

RegisterNUICallback('teleportToSpot', function(data, cb)
    local id = tonumber(data.id)
    for _, s in ipairs(spots) do
        if s.id == id then
            local playerPed = PlayerPedId()
            SetEntityCoords(playerPed, s.x, s.y, s.z + 0.5, false, false, false, true)
            SetEntityHeading(playerPed, s.heading)
            QBCore.Functions.Notify('Téléporté sur : ' .. s.name, 'primary', 3000)
            break
        end
    end
    cb('ok')
end)

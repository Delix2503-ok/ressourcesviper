local QBCore = exports['qb-core']:GetCoreObject()

spots           = {}     -- global : partagé avec admin.lua
spawnedPeds     = {}     -- global : partagé avec admin.lua
local isMenuOpen    = false
isLaundering        = false  -- global : lu par admin.lua (proximité)
local launchCancelled = false
local activeRate    = Config.LaundryRate  -- taux appliqué à la session en cours

-- ─── Thread every-frame : contrôles bloqués + détection X ────────────────────
-- Ce thread tourne chaque frame pendant le blanchiment.
-- Il est le seul endroit fiable pour détecter IsControlJustPressed.
CreateThread(function()
    while true do
        if isLaundering then
            DisableControlAction(0, 30, true)   -- MoveLeftRight
            DisableControlAction(0, 31, true)   -- MoveUpDown
            DisableControlAction(0, 21, true)   -- Sprint
            DisableControlAction(0, 24, true)   -- Attack
            DisableControlAction(0, 25, true)   -- Aim
            DisableControlAction(0, 44, true)   -- Cover
            DisableControlAction(0, 37, true)   -- SelectWeapon
            DisableControlAction(0, 47, true)   -- EnterVehicle

            -- X = INPUT_VEH_EXIT (73) — détecté chaque frame
            if IsControlJustPressed(0, 73) or IsDisabledControlJustPressed(0, 73) then
                launchCancelled = true
            end

            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- ─── Chargement initial ───────────────────────────────────────────────────────

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        Wait(2000)
        TriggerServerEvent('viper-blanchiment:server:getSpots')
        TriggerServerEvent('viper-blanchiment:server:checkAdmin')
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    TriggerServerEvent('viper-blanchiment:server:getSpots')
    TriggerServerEvent('viper-blanchiment:server:checkAdmin')
end)

-- ─── Réception et spawn des PEDs ─────────────────────────────────────────────

RegisterNetEvent('viper-blanchiment:client:receiveSpots', function(newSpots)
    for _, data in pairs(spawnedPeds) do
        if DoesEntityExist(data.ped) then DeleteEntity(data.ped) end
        if data.blip and DoesBlipExist(data.blip) then RemoveBlip(data.blip) end
    end
    spawnedPeds = {}
    spots = newSpots

    for _, spot in ipairs(spots) do
        CreateThread(function() SpawnPedAtSpot(spot) end)
    end

    SendNUIMessage({ action = 'updateSpots', spots = spots })
end)

function SpawnPedAtSpot(spot)
    local model = GetHashKey(spot.pedModel or Config.PedModel)
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 150 do Wait(100); t = t + 1 end

    if not HasModelLoaded(model) then
        print(('[Viper] Modèle introuvable : %s'):format(spot.pedModel or Config.PedModel))
        return
    end

    local ped = CreatePed(4, model, spot.x, spot.y, spot.z - 1.0, spot.heading, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    FreezeEntityPosition(ped, true)
    SetPedFleeAttributes(ped, 0, 0)
    SetPedCombatAttributes(ped, 17, true)
    SetPedCanPlayAmbientAnims(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)

    local blip = AddBlipForCoord(spot.x, spot.y, spot.z)
    SetBlipSprite(blip, 469)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.75)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(spot.name or 'Blanchiment')
    EndTextCommandSetBlipName(blip)

    spawnedPeds[spot.id] = { ped = ped, blip = blip, spotId = spot.id }
    SetModelAsNoLongerNeeded(model)
end

-- ─── Boucle de proximité ─────────────────────────────────────────────────────

CreateThread(function()
    while true do
        local sleep = 800

        if not isLaundering then
            local playerPed   = PlayerPedId()
            local playerCoord = GetEntityCoords(playerPed)

            for spotId, data in pairs(spawnedPeds) do
                if DoesEntityExist(data.ped) then
                    local pedCoord = GetEntityCoords(data.ped)
                    local dist     = #(playerCoord - pedCoord)

                    if dist < 8.0 then
                        sleep = 0

                        if dist < Config.InteractionDistance then
                            DrawText3D(pedCoord.x, pedCoord.y, pedCoord.z + 1.15,
                                'Blanchir de l\'argent  [E]')

                            if IsControlJustPressed(0, 38) and not isMenuOpen then
                                TriggerEvent('viper-blanchiment:client:openMenu', { spotId = spotId })
                            end
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ─── Menu blanchiment ─────────────────────────────────────────────────────────

AddEventHandler('viper-blanchiment:client:openMenu', function(data)
    if isMenuOpen or isLaundering then return end
    isMenuOpen = true

    QBCore.Functions.TriggerCallback('viper-blanchiment:server:getBlackMoney', function(result)
        if not isMenuOpen then return end  -- annulé entre-temps
        activeRate = result.rate or Config.LaundryRate
        SetNuiFocus(true, true)
        SendNUIMessage({
            action      = 'openLaundry',
            blackMoney  = result.blackMoney or 0,
            laundryRate = activeRate,
            isVip       = result.isVip or false,
            minAmount   = Config.MinAmount,
            maxAmount   = Config.MaxAmount,
            duration    = Config.LaundryDuration,
            spotId      = data.spotId,
        })
    end)
end)

-- ─── Callbacks NUI ────────────────────────────────────────────────────────────

RegisterNUICallback('closeLaundry', function(_, cb)
    isMenuOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('startLaundry', function(data, cb)
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 or isLaundering then
        cb({ success = false })
        return
    end

    isMenuOpen      = false
    isLaundering    = true
    launchCancelled = false
    SetNuiFocus(false, false)

    -- IMPORTANT : cb() appelé AVANT tout Wait, sinon FiveM timeout le callback
    -- et isLaundering reste bloqué à true pour toujours
    cb({ success = true })

    CreateThread(function()
        local playerPed = PlayerPedId()

        -- Charger l'animation (en dehors du callback NUI maintenant)
        local dict = 'amb@world_human_clipboard@male@idle_a'
        RequestAnimDict(dict)
        local t = 0
        while not HasAnimDictLoaded(dict) and t < 50 do Wait(100); t = t + 1 end
        TaskPlayAnim(playerPed, dict, 'idle_a', 8.0, -8.0, -1, 1, 0, false, false, false)

        -- Afficher la barre NUI
        SendNUIMessage({
            action  = 'startProgress',
            amount  = amount,
            receive = math.floor(amount * activeRate),
        })

        -- Boucle principale : Wait(0) pour détecter X chaque frame
        local duration  = Config.LaundryDuration * 1000
        local startTime = GetGameTimer()
        local lastNUI   = 0

        while true do
            local now     = GetGameTimer()
            local elapsed = now - startTime
            local pct     = math.min((elapsed / duration) * 100, 100)

            -- Mise à jour NUI toutes les 100ms (pas chaque frame)
            if now - lastNUI >= 100 then
                local remaining = math.max(math.ceil((duration - elapsed) / 1000), 0)
                SendNUIMessage({ action = 'updateProgress', pct = pct, remaining = remaining })
                lastNUI = now
            end

            -- Flag mis par le thread every-frame dès que X est pressé
            if launchCancelled then break end

            -- Terminé
            if pct >= 100 then break end

            Wait(0)
        end

        local wasCancelled = launchCancelled

        -- Nettoyage dans tous les cas
        isLaundering    = false
        launchCancelled = false
        ClearPedTasks(playerPed)
        SendNUIMessage({ action = 'stopProgress' })

        if wasCancelled then
            QBCore.Functions.Notify('Blanchiment annulé.', 'error', 3000)
        else
            TriggerServerEvent('viper-blanchiment:server:launderMoney', amount)
        end
    end)
end)

-- ─── Résultats ────────────────────────────────────────────────────────────────

RegisterNetEvent('viper-blanchiment:client:launderSuccess', function(cleanAmount, fees)
    QBCore.Functions.Notify(
        ('Blanchiment réussi ! +$%s (frais : $%s)'):format(FormatMoney(cleanAmount), FormatMoney(fees)),
        'success', 6000
    )
end)

RegisterNetEvent('viper-blanchiment:client:notify', function(type, msg)
    QBCore.Functions.Notify(msg, type, 5000)
end)

-- ─── Nettoyage ────────────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for _, data in pairs(spawnedPeds) do
            if DoesEntityExist(data.ped) then DeleteEntity(data.ped) end
            if data.blip and DoesBlipExist(data.blip) then RemoveBlip(data.blip) end
        end
    end
end)

-- ─── Utilitaires ──────────────────────────────────────────────────────────────

function FormatMoney(n)
    local s = tostring(math.floor(n))
    return s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
end

function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    SetTextScale(0.38, 0.38)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 220)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(sx, sy)

    local factor = #text / 420
    DrawRect(sx, sy + 0.0145, 0.02 + factor, 0.034, 0, 0, 0, 120)
end

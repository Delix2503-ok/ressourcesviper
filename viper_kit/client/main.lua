local NPCHandle = nil
local DynCoords  = nil  -- position sauvegardée par l'admin (override Config.NPCCoords)
local SpawnGen   = 0   -- annule les spawns obsolètes (race onClientResourceStart vs syncNpcPos)

-- ─── Spawn PNJ (pattern physique vipergun/viper_ranked) ──────────────────────
local function SpawnNPC()
    if NPCHandle and DoesEntityExist(NPCHandle) then
        DeleteEntity(NPCHandle)
        NPCHandle = nil
    end

    SpawnGen = SpawnGen + 1
    local gen = SpawnGen

    local c = DynCoords or Config.NPCCoords
    local hash = GetHashKey(Config.NPCModel)

    -- Nettoyer les PNJ résiduels du même modèle (survivent au restart via MissionEntity)
    for _, p in ipairs(GetGamePool('CPed')) do
        if not IsPedAPlayer(p) and GetEntityModel(p) == hash then
            if #(GetEntityCoords(p) - vector3(c.x, c.y, c.z)) < 5.0 then
                SetEntityAsMissionEntity(p, true, true)
                DeletePed(p)
            end
        end
    end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 50 do
        Wait(100); t = t + 1
        if gen ~= SpawnGen then return end
    end
    if not HasModelLoaded(hash) or gen ~= SpawnGen then return end

    local ped = CreatePed(4, hash, c.x, c.y, c.z, c.w, false, true)
    if not DoesEntityExist(ped) then return end
    if gen ~= SpawnGen then DeleteEntity(ped); return end

    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, 0)
    SetEntityAsMissionEntity(ped, true, true)
    TaskStandStill(ped, -1)
    SetModelAsNoLongerNeeded(hash)
    NPCHandle = ped

    -- Blip
    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, 280)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Viper Kit')
    EndTextCommandSetBlipName(blip)

    -- Physique sol + freeze + maintenance (pattern vipergun)
    CreateThread(function()
        local w = 0
        while DoesEntityExist(ped) and gen == SpawnGen and not HasCollisionLoadedAroundEntity(ped) and w < 75 do
            Wait(200); w = w + 1
        end
        if gen ~= SpawnGen or not DoesEntityExist(ped) then return end

        local finalZ  = c.z
        local snapped = false
        for _ = 1, 30 do
            if not DoesEntityExist(ped) or gen ~= SpawnGen then return end
            local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 10.0, false)
            if found and gz > 0.0 and gz <= c.z + 1.0 then
                SetEntityCoords(ped, c.x, c.y, gz, false, false, false, false)
                finalZ  = gz
                snapped = true
                break
            end
            Wait(200)
        end
        if not DoesEntityExist(ped) or gen ~= SpawnGen then return end
        if not snapped then
            SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
        end

        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        TaskStandStill(ped, -1)

        -- Boucle de maintien : recorrige la dérive toutes les 500ms
        local tick = 0
        while DoesEntityExist(ped) and gen == SpawnGen do
            Wait(100)
            FreezeEntityPosition(ped, true)
            SetEntityCollision(ped, false, false)
            tick = tick + 1
            if tick >= 5 then
                tick = 0
                local _, _, cz = table.unpack(GetEntityCoords(ped))
                if math.abs(cz - finalZ) > 0.25 then
                    SetEntityCoords(ped, c.x, c.y, finalZ, false, false, false, false)
                end
            end
        end
    end)
end

-- Spawn au démarrage : demander la position sauvegardée, puis spawn
AddEventHandler('onClientResourceStart', function(name)
    if name ~= GetCurrentResourceName() then return end
    TriggerServerEvent('viper_kit:requestNpcPos')
    -- spawn immédiat avec Config.NPCCoords ; si le serveur envoie une pos sauvegardée,
    -- syncNpcPos refera le spawn à la bonne position
    SpawnNPC()
end)

-- Réception position sauvegardée (admin a déplacé le PNJ)
RegisterNetEvent('viper_kit:syncNpcPos', function(pos)
    DynCoords = vector4(pos.x, pos.y, pos.z, pos.w)
    SpawnNPC()  -- recrée toujours : tue l'ancien thread de maintenance proprement
end)

-- ─── Hologramme "KIT" ────────────────────────────────────────────────────────
local function DrawKitHolo(x, y, z, dist)
    -- Disque pulsant au sol
    if dist < Config.HoloDist then
        local pulse = (math.sin(GetGameTimer() / 400.0) + 1.0) * 0.5
        DrawMarker(28, x, y, z - 0.95,
            0.0,0.0,0.0, 0.0,0.0,0.0, 0.8,0.8,0.06,
            57, 255, 20, math.floor((120 + 95 * pulse) * 0.4),
            false, false, 2, false, nil, nil, false)
    end
    -- Texte flottant
    local onScreen, sx, sy = World3dToScreen2d(x, y, z + 1.25)
    if not onScreen then return end
    local camCoords = GetGameplayCamCoords()
    local d = #(camCoords - vector3(x, y, z))
    if d > Config.HoloDist then return end
    local scale = math.min((1 / d) * 2.8, 0.6) * (1 / GetGameplayCamFov()) * 100
    SetTextScale(0.0, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(57, 255, 20, 230)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 180)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(1)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName('KIT')
    EndTextCommandDisplayText(sx, sy)
end

-- ─── Boucle interaction PNJ ──────────────────────────────────────────────────
CreateThread(function()
    while true do
        if NPCHandle and DoesEntityExist(NPCHandle) then
            local myCoords = GetEntityCoords(PlayerPedId())
            local npcCoords = GetEntityCoords(NPCHandle)
            local dist = #(myCoords - npcCoords)

            if dist < Config.HoloDist then
                DrawKitHolo(npcCoords.x, npcCoords.y, npcCoords.z, dist)

                if dist < Config.InteractDist then
                    -- Prompt [E]
                    SetTextScale(0.4, 0.4)
                    SetTextFont(0)
                    SetTextProportional(1)
                    SetTextColour(255, 255, 255, 220)
                    SetTextOutline()
                    SetTextEntry('STRING')
                    SetTextCentre(true)
                    AddTextComponentString('[E] Viper Kit')
                    DrawText(0.5, 0.9)

                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('viper_kit:getMyKits')
                    end
                end
                Wait(0)
            else
                Wait(500)
            end
        else
            Wait(1000)
        end
    end
end)

-- ─── Commandes ───────────────────────────────────────────────────────────────
RegisterCommand('adminkit', function()
    TriggerServerEvent('viper_kit:adminOpen')
end, false)

RegisterCommand('kit', function()
    TriggerServerEvent('viper_kit:getMyKits')
end, false)

-- ─── Réception données admin ─────────────────────────────────────────────────
RegisterNetEvent('viper_kit:adminReceiveKits', function(kits)
    SendNUIMessage({ type = 'openAdmin', kits = kits })
    SetNuiFocus(true, true)
end)

-- ─── Réception données joueur ────────────────────────────────────────────────
RegisterNetEvent('viper_kit:receiveMyKits', function(kits)
    if not kits or #kits == 0 then
        TriggerEvent('QBCore:Notify', 'Aucun kit disponible.', 'error', 4000)
        return
    end
    SendNUIMessage({ type = 'openPlayer', kits = kits })
    SetNuiFocus(true, true)
end)

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('adminCreate', function(data, cb)
    TriggerServerEvent('viper_kit:adminCreate', data)
    cb('ok')
end)

RegisterNUICallback('adminEdit', function(data, cb)
    TriggerServerEvent('viper_kit:adminEdit', data)
    cb('ok')
end)

RegisterNUICallback('adminDelete', function(data, cb)
    TriggerServerEvent('viper_kit:adminDelete', data.id)
    cb('ok')
end)

RegisterNUICallback('claim', function(data, cb)
    TriggerServerEvent('viper_kit:claim', data.id)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('spawnNpcHere', function(_, cb)
    local ped     = PlayerPedId()
    local pos     = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    TriggerServerEvent('viper_kit:saveNpcPos', pos.x, pos.y, pos.z, heading)
    cb('ok')
end)

-- ─── Nettoyage au stop ───────────────────────────────────────────────────────
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    if NPCHandle and DoesEntityExist(NPCHandle) then
        DeleteEntity(NPCHandle)
        NPCHandle = nil
    end
end)

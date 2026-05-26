local QBCore        = exports['qb-core']:GetCoreObject()
local Npcs          = {}   -- [id] = npcData
local Zones         = {}   -- [id] = zoneData
local SpawnedNpcs   = {}   -- [id] = ped handle (type 'npc' seulement)
local ActiveMarkers = {}   -- [id] = true (type 'marker')
local NpcSyncGen    = 0
local AdminOpen    = false
local TpSelectOpen = false
local TpDestination = nil
local InReviveZone  = false
local TextUIShown   = false

-- ─── Hologramme 3D ───────────────────────────────────────────────────────
local function DrawText3D(x, y, z, text, smallScale)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    local cam  = GetGameplayCamCoords()
    local dist = #(cam - vector3(x, y, z))
    if dist > Config.LabelDistance then return end
    local baseScale = smallScale and 0.38 or 0.6
    local scale = math.min((1 / dist) * 2.8, baseScale) * (1 / GetGameplayCamFov()) * 100
    SetTextScale(0.0, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(57, 255, 20, 230)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 180)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

-- ─── Spawn PNJ (même physique que vipergun) ───────────────────────────────
local function SpawnNpc(data, gen)
    CreateThread(function()
        if SpawnedNpcs[data.id] and DoesEntityExist(SpawnedNpcs[data.id]) then
            DeleteEntity(SpawnedNpcs[data.id])
            SpawnedNpcs[data.id] = nil
        end

        local models = Config.NpcModels
        local mHash  = GetHashKey(models[math.random(#models)])
        RequestModel(mHash)
        local t = 0
        while not HasModelLoaded(mHash) and t < 40 do Wait(50); t = t + 1 end
        if not HasModelLoaded(mHash) then return end
        if gen ~= NpcSyncGen then SetModelAsNoLongerNeeded(mHash); return end

        local ped = CreatePed(4, mHash, data.x, data.y, data.z, data.heading, false, true)
        SetModelAsNoLongerNeeded(mHash)

        -- Flags — collision ON pour le snap au sol
        SetEntityInvincible(ped, true)
        SetEntityCanBeDamaged(ped, false)
        SetPedCanRagdoll(ped, false)
        SetPedCanBeDraggedOut(ped, false)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 17, false)
        SetEntityAsMissionEntity(ped, true, true)
        TaskStandStill(ped, -1)

        -- Attendre que la collision soit chargée autour du ped
        local w = 0
        while DoesEntityExist(ped) and not HasCollisionLoadedAroundEntity(ped) and w < 50 do
            Wait(200); w = w + 1
        end

        local finalZ  = data.z
        local snapped = false
        for _ = 1, 30 do
            if not DoesEntityExist(ped) then return end
            local found, gz = GetGroundZFor_3dCoord(data.x, data.y, data.z + 10.0, false)
            if found and gz > 0.0 and gz >= data.z - 2.0 and gz <= data.z + 1.0 then
                SetEntityCoords(ped, data.x, data.y, gz, false, false, false, false)
                finalZ  = gz
                snapped = true; break
            end
            Wait(200)
        end
        if not snapped and DoesEntityExist(ped) then
            SetEntityCoords(ped, data.x, data.y, data.z, false, false, false, false)
        end

        if gen ~= NpcSyncGen then
            if DoesEntityExist(ped) then DeleteEntity(ped) end
            return
        end

        if DoesEntityExist(ped) then
            FreezeEntityPosition(ped, true)
            SetEntityCollision(ped, false, false)
            TaskStandStill(ped, -1)
        end

        SpawnedNpcs[data.id] = ped

        local snapTick = 0
        while DoesEntityExist(ped) and SpawnedNpcs[data.id] == ped do
            Wait(100)
            FreezeEntityPosition(ped, true)
            SetEntityCollision(ped, false, false)
            snapTick = snapTick + 1
            if snapTick >= 5 then
                snapTick = 0
                local cx, cy, cz = table.unpack(GetEntityCoords(ped))
                local found, gz = GetGroundZFor_3dCoord(cx, cy, cz + 5.0, false)
                if found and gz > 0.0 and gz >= data.z - 2.0 and gz <= data.z + 1.0 and math.abs(gz - cz) > 0.15 then
                    SetEntityCoords(ped, cx, cy, gz, false, false, false, false)
                    finalZ = gz
                elseif math.abs(cz - finalZ) > 0.25 then
                    SetEntityCoords(ped, data.x, data.y, finalZ, false, false, false, false)
                end
            end
        end
    end)
end

-- ─── Réception sync ──────────────────────────────────────────────────────
RegisterNetEvent('vipertpramp:sync', function(npcs, zones)
    NpcSyncGen = NpcSyncGen + 1
    local gen = NpcSyncGen

    for _, ped in pairs(SpawnedNpcs) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    SpawnedNpcs   = {}
    ActiveMarkers = {}
    Npcs          = {}
    Zones         = {}

    for _, n in ipairs(npcs) do
        Npcs[n.id] = n
        if n.type == 'marker' then
            ActiveMarkers[n.id] = true
        else
            SpawnNpc(n, gen)
        end
    end
    for _, z in ipairs(zones) do
        Zones[z.id] = z
    end
end)

-- ─── Zones revive : détection ────────────────────────────────────────────
CreateThread(function()
    local wasIn = false
    while true do
        Wait(500)
        local coords = GetEntityCoords(PlayerPedId())
        InReviveZone = false
        for _, z in pairs(Zones) do
            local dx = coords.x - z.x
            local dy = coords.y - z.y
            if (dx*dx + dy*dy) <= (z.radius * z.radius) then
                InReviveZone = true
                break
            end
        end
        if InReviveZone ~= wasIn then
            wasIn = InReviveZone
            if InReviveZone then
                lib.notify({ title = 'Zone Revive', description = 'Tapez /r pour vous relever dans cette zone.', type = 'success', duration = 5000 })
            end
        end
    end
end)

-- Stamina illimitée dans la zone
CreateThread(function()
    while true do
        if InReviveZone then
            Wait(0)
            RestorePlayerStamina(PlayerId(), 1.0)
        else
            Wait(500)
        end
    end
end)

-- Dessin des zones (contour vert)
CreateThread(function()
    local steps = 32
    local pi2   = math.pi * 2
    while true do
        local drawn = false
        for _, z in pairs(Zones) do
            drawn = true
            DrawMarker(1, z.x, z.y, z.z - 1.0, 0,0,0, 0,0,0,
                z.radius * 2.0, z.radius * 2.0, 1.2,
                20, 200, 20, 18,
                false, false, 2, false, nil, nil, false)
            for i = 0, steps - 1 do
                local a1 = (i / steps)       * pi2
                local a2 = ((i + 1) / steps) * pi2
                DrawLine(
                    z.x + z.radius * math.cos(a1), z.y + z.radius * math.sin(a1), z.z + 0.5,
                    z.x + z.radius * math.cos(a2), z.y + z.radius * math.sin(a2), z.z + 0.5,
                    40, 220, 40, 200)
            end
        end
        Wait(drawn and 0 or 500)
    end
end)

-- ─── /r : se relever dans une zone revive ────────────────────────────────
RegisterCommand('r', function()
    if not InReviveZone then
        lib.notify({ title = 'Zone Revive', description = 'Vous n\'êtes pas dans une zone de revive.', type = 'error', duration = 3000 })
        return
    end
    if not LocalPlayer.state.rzDead then
        lib.notify({ title = 'Zone Revive', description = 'Vous n\'êtes pas au sol.', type = 'error', duration = 3000 })
        return
    end
    TriggerServerEvent('vipertpramp:selfRevive')
end, false)

-- ─── Dessin des marqueurs rouges ─────────────────────────────────────────
CreateThread(function()
    local steps = 32
    local pi2   = math.pi * 2
    local r     = 2.0
    while true do
        local drawn = false
        for id, _ in pairs(ActiveMarkers) do
            local n = Npcs[id]
            if n then
                drawn = true
                DrawMarker(1, n.x, n.y, n.z - 0.05, 0,0,0, 0,0,0,
                    r * 2.0, r * 2.0, 0.4,
                    200, 30, 30, 90,
                    false, false, 2, false, nil, nil, false)
                for i = 0, steps - 1 do
                    local a1 = (i / steps)       * pi2
                    local a2 = ((i + 1) / steps) * pi2
                    DrawLine(
                        n.x + r * math.cos(a1), n.y + r * math.sin(a1), n.z + 0.05,
                        n.x + r * math.cos(a2), n.y + r * math.sin(a2), n.z + 0.05,
                        220, 40, 40, 220)
                end
            end
        end
        Wait(drawn and 0 or 500)
    end
end)

-- ─── Thread principal : hologramme + touche E ────────────────────────────
CreateThread(function()
    while true do
        local hasAny = next(SpawnedNpcs) or next(ActiveMarkers)
        if not hasAny then
            Wait(500)
        else
            Wait(0)
            local myCoords = GetEntityCoords(PlayerPedId())
            local nearId   = nil
            local minDist  = Config.InteractionDistance

            -- PNJ physiques
            for id, ped in pairs(SpawnedNpcs) do
                if DoesEntityExist(ped) then
                    local c = GetEntityCoords(ped)
                    local d = #(myCoords - c)
                    if d < Config.LabelDistance then
                        DrawText3D(c.x, c.y, c.z + 1.25, 'TP RAMPS', false)
                    end
                    if d < minDist then minDist = d; nearId = id end
                end
            end

            -- Marqueurs au sol
            for id, _ in pairs(ActiveMarkers) do
                local n = Npcs[id]
                if n then
                    local d = #(myCoords - vector3(n.x, n.y, n.z))
                    if d < Config.LabelDistance then
                        DrawText3D(n.x, n.y, n.z + 1.5, 'TP RAMPS', false)
                    end
                    if d < minDist then minDist = d; nearId = id end
                end
            end

            if nearId and not TpSelectOpen and not AdminOpen then
                local npcName = Npcs[nearId] and Npcs[nearId].name or 'Ramp'
                if not TextUIShown then
                    lib.showTextUI('[E] Téléporter — ' .. npcName, { position = 'left-center', icon = 'location-arrow' })
                    TextUIShown = true
                end
                if IsControlJustPressed(0, 38) then
                    local list = {}
                    for _, n in pairs(Npcs) do list[#list+1] = n end
                    table.sort(list, function(a, b) return a.name < b.name end)
                    if #list == 0 then
                        lib.notify({ title = 'TP Ramps', description = 'Aucune destination disponible.', type = 'error', duration = 3000 })
                    else
                        TpSelectOpen = true
                        SetNuiFocus(true, true)
                        SendNUIMessage({ type = 'showTpSelect', npcs = list })
                    end
                end
            else
                if TextUIShown then
                    lib.hideTextUI()
                    TextUIShown = false
                end
            end
        end
    end
end)

-- ─── Panel Admin ─────────────────────────────────────────────────────────
RegisterCommand('admintpramps', function()
    TriggerServerEvent('vipertpramp:admin:open')
end, false)

RegisterNetEvent('vipertpramp:admin:denied', function()
    lib.notify({ title = 'Admin', description = 'Accès refusé.', type = 'error', duration = 3000 })
end)

RegisterNetEvent('vipertpramp:admin:opened', function(npcs, zones)
    AdminOpen = true
    if TextUIShown then lib.hideTextUI(); TextUIShown = false end
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'openAdmin', npcs = npcs, zones = zones })
end)

RegisterNetEvent('vipertpramp:admin:npcList', function(list)
    SendNUIMessage({ type = 'npcList', npcs = list })
end)

RegisterNetEvent('vipertpramp:admin:zoneList', function(list)
    SendNUIMessage({ type = 'zoneList', zones = list })
end)

-- ─── NUI Callbacks ───────────────────────────────────────────────────────
RegisterNUICallback('closeAdmin', function(_, cb)
    AdminOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback('createNpc', function(data, cb)
    TriggerServerEvent('vipertpramp:admin:npc:create', data.name, data.type)
    cb({})
end)

RegisterNUICallback('deleteNpc', function(data, cb)
    TriggerServerEvent('vipertpramp:admin:npc:delete', data.id)
    cb({})
end)

RegisterNUICallback('adminTpToNpc', function(data, cb)
    local id = tonumber(data.id)
    if id and Npcs[id] then TpDestination = Npcs[id] end
    cb({})
end)

RegisterNUICallback('createZone', function(data, cb)
    TriggerServerEvent('vipertpramp:admin:zone:create', data.name, data.radius)
    cb({})
end)

RegisterNUICallback('deleteZone', function(data, cb)
    TriggerServerEvent('vipertpramp:admin:zone:delete', data.id)
    cb({})
end)

RegisterNUICallback('closeTpSelect', function(_, cb)
    TpSelectOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback('tpSelectChoose', function(data, cb)
    TpSelectOpen = false
    SetNuiFocus(false, false)
    local id = tonumber(data.id)
    if id and Npcs[id] then TpDestination = Npcs[id] end
    cb({})
end)

-- ─── Thread TP (fade + SetEntityCoords depuis un vrai thread) ────────────
CreateThread(function()
    while true do
        if TpDestination then
            local dest = TpDestination
            TpDestination = nil
            DoScreenFadeOut(300)
            Wait(350)
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then
                SetEntityCoords(veh, dest.x, dest.y, dest.z, false, false, false, false)
            else
                SetEntityCoords(ped, dest.x, dest.y, dest.z, false, false, false, false)
            end
            DoScreenFadeIn(300)
            lib.notify({ title = 'TP Ramps', description = 'Téléporté vers ' .. (dest.name or '?'), type = 'success', duration = 3000 })
        else
            Wait(50)
        end
    end
end)

-- ─── Init ────────────────────────────────────────────────────────────────
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(2000)
    TriggerServerEvent('vipertpramp:requestSync')
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('vipertpramp:requestSync')
end)

-- ─── Nettoyage ───────────────────────────────────────────────────────────
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in pairs(SpawnedNpcs) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    if TextUIShown then lib.hideTextUI() end
    if AdminOpen or TpSelectOpen then SetNuiFocus(false, false) end
end)

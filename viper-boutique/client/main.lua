local QBCore = exports['qb-core']:GetCoreObject()

-- ─── State ────────────────────────────────────────────────────────────────────
local GarageNpcs     = {}
local GarageNpcPeds  = {}
local GarageSpawning = {}
local NearGarageNpc  = nil
local CurrentGarageVeh = nil

local CustomNpcs     = {}
local CustomNpcPeds  = {}
local CustomSpawning = {}
local NearCustomNpc  = nil

local CurrentVehicleModel = nil
local CurrentVehicleMods  = {}

local function SaveCurrentMods()
    if not CurrentVehicleModel then return end
    TriggerServerEvent('boutique:saveVehicleMods', CurrentVehicleModel, CurrentVehicleMods)
end

local function ApplyVehicleMods(veh, mods)
    if not mods then return end
    SetVehicleModKit(veh, 0)
    if mods.primary_color   then local _, s = GetVehicleColours(veh); SetVehicleColours(veh, mods.primary_color, s) end
    if mods.secondary_color then local p, _ = GetVehicleColours(veh); SetVehicleColours(veh, p, mods.secondary_color) end
    if mods.pearl_color or mods.wheel_color then
        local pc, wc = GetVehiclePearlescentColour(veh)
        SetVehiclePearlescentColour(veh, mods.pearl_color or pc, mods.wheel_color or wc)
    end
    if mods.wheel_type then SetVehicleWheelType(veh, mods.wheel_type) end
    if mods.wheel_mod  then SetVehicleMod(veh, 23, mods.wheel_mod, false) end
    if mods.window_tint then SetVehicleWindowTint(veh, mods.window_tint) end
    if mods.xenon_enabled == 1 then
        SetVehicleXenonLightsEnabled(veh, true)
        if mods.xenon_color then SetVehicleXenonLightsColor(veh, mods.xenon_color) end
    end
    if mods.neon_left == 1 or mods.neon_right == 1 or mods.neon_front == 1 or mods.neon_back == 1 then
        SetVehicleNeonLights(veh, mods.neon_r or 0, mods.neon_g or 255, mods.neon_b or 0)
        SetVehicleNeonEnabled(veh, 0, mods.neon_left  == 1)
        SetVehicleNeonEnabled(veh, 1, mods.neon_right == 1)
        SetVehicleNeonEnabled(veh, 2, mods.neon_front == 1)
        SetVehicleNeonEnabled(veh, 3, mods.neon_back  == 1)
    end
    if mods.body_mods then
        local t = mods.body_mods
        if type(t) == 'string' then
            local ok, decoded = pcall(json.decode, t)
            if ok and decoded then t = decoded else t = {} end
        end
        for modType, modIdx in pairs(t) do
            SetVehicleMod(veh, tonumber(modType), tonumber(modIdx), false)
        end
    end
end

-- ─── DrawText3D (même style que vipergun/drawPedLabel) ───────────────────────
local function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z + 1.25)
    if not onScreen then return end
    local camCoords = GetGameplayCamCoords()
    local dist = #(camCoords - vector3(x, y, z))
    if dist > 25.0 then return end
    local scale = math.min((1 / dist) * 2.8, 0.6) * ((1 / GetGameplayCamFov()) * 100)
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
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

-- ─── /boutique ────────────────────────────────────────────────────────────────
RegisterCommand('boutique', function()
    TriggerServerEvent('boutique:requestOpen')
end, false)

-- ─── /adminboutique ───────────────────────────────────────────────────────────
RegisterCommand('adminboutique', function()
    TriggerServerEvent('boutique:requestAdminOpen')
end, false)

-- ─── Sync NPCs garage depuis le serveur ──────────────────────────────────────
RegisterNetEvent('boutique:syncGarageNpcs', function(npcs)
    for id, ped in pairs(GarageNpcPeds) do
        if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    GarageNpcPeds  = {}
    GarageSpawning = {}
    GarageNpcs     = {}
    for _, n in ipairs(npcs) do
        GarageNpcs[#GarageNpcs + 1] = {
            id            = n.id,
            name          = n.name,
            x             = n.x,
            y             = n.y,
            z             = n.z,
            heading       = n.heading,
            spawn_x       = n.spawn_x,
            spawn_y       = n.spawn_y,
            spawn_z       = n.spawn_z,
            spawn_heading = n.spawn_heading,
        }
    end
end)

-- ─── Spawn NPC garage ─────────────────────────────────────────────────────────
local function SpawnGarageNpc(npcData)
    local id    = npcData.id
    local model = GetHashKey(Config.GarageNpcModel)
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) do
        if GetGameTimer() - t > 10000 then GarageSpawning[id] = nil; return end
        Wait(100)
    end

    local ped = CreatePed(4, model, npcData.x, npcData.y, npcData.z, npcData.heading, false, true)
    GarageNpcPeds[id] = ped
    SetModelAsNoLongerNeeded(model)

    -- Flags comportement (collision ON pour snap)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetPedCanRagdoll(ped, false)
    SetPedCanBeDraggedOut(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, false)
    TaskStandStill(ped, -1)

    -- Attendre collision monde
    local w = 0
    while DoesEntityExist(ped) and not HasCollisionLoadedAroundEntity(ped) and w < 50 do
        Wait(200); w = w + 1
    end

    local finalZ  = npcData.z
    local snapped = false
    for _ = 1, 30 do
        if not DoesEntityExist(ped) then GarageSpawning[id] = nil; return end
        local found, gz = GetGroundZFor_3dCoord(npcData.x, npcData.y, npcData.z + 10.0, false)
        if found and gz > 0.0 and gz >= npcData.z - 2.0 and gz <= npcData.z + 1.0 then
            SetEntityCoords(ped, npcData.x, npcData.y, gz, false, false, false, false)
            finalZ  = gz
            snapped = true
            break
        end
        Wait(200)
    end
    if not snapped and DoesEntityExist(ped) then
        SetEntityCoords(ped, npcData.x, npcData.y, npcData.z, false, false, false, false)
    end

    if DoesEntityExist(ped) then
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        TaskStandStill(ped, -1)
    end

    GarageSpawning[id] = nil

    CreateThread(function()
        local snapTick = 0
        while DoesEntityExist(ped) and GarageNpcPeds[id] == ped do
            Wait(100)
            FreezeEntityPosition(ped, true)
            SetEntityCollision(ped, false, false)
            snapTick = snapTick + 1
            if snapTick >= 5 then
                snapTick = 0
                local cx, cy, cz = table.unpack(GetEntityCoords(ped))
                local found, gz = GetGroundZFor_3dCoord(cx, cy, cz + 5.0, false)
                if found and gz > 0.0 and gz >= npcData.z - 2.0 and gz <= npcData.z + 1.0 and math.abs(gz - cz) > 0.15 then
                    SetEntityCoords(ped, cx, cy, gz, false, false, false, false)
                    finalZ = gz
                elseif math.abs(cz - finalZ) > 0.25 then
                    SetEntityCoords(ped, npcData.x, npcData.y, finalZ, false, false, false, false)
                end
            end
        end
    end)
end

-- ─── Thread principal : hologrammes + interaction ────────────────────────────
CreateThread(function()
    while true do
        if #GarageNpcs == 0 then
            Wait(500)
        else
            Wait(0)

            local playerPed    = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local closest, closestDist = nil, 3.0

            for i = 1, #GarageNpcs do
                local n = GarageNpcs[i]
                local d = #(playerCoords - vector3(n.x, n.y, n.z))

                if d < 20.0 then
                    DrawText3D(n.x, n.y, n.z, 'GARAGE V.I.P')
                end

                -- Spawn à la demande si ped mort/absent
                local ped = GarageNpcPeds[n.id]
                if not (ped and DoesEntityExist(ped)) and not GarageSpawning[n.id] then
                    GarageNpcPeds[n.id] = nil
                    GarageSpawning[n.id] = true
                    local nd = n
                    CreateThread(function() SpawnGarageNpc(nd) end)
                end

                if d < closestDist then closest = n; closestDist = d end
            end

            -- Hint interaction (DrawText direct, même pattern que viperpvp_redzone)
            if closest and closestDist < 2.5 then
                NearGarageNpc = closest
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(0.38, 0.38)
                SetTextColour(255, 255, 255, 230)
                SetTextDropShadow()
                SetTextOutline()
                SetTextEntry('STRING')
                AddTextComponentString('~g~[E]~w~ Acceder au garage')
                DrawText(0.5, 0.9)
            else
                NearGarageNpc = nil
            end

            -- Touche E
            if NearGarageNpc and IsControlJustReleased(0, 38) then
                TriggerServerEvent('boutique:requestGarage', NearGarageNpc.id)
            end
        end
    end
end)

-- ─── Réception : ouvrir garage (ox_lib context menu) ─────────────────────────
RegisterNetEvent('boutique:openGarage', function(vehicles, npcId)
    if not vehicles or #vehicles == 0 then
        lib.notify({ title = 'Garage V.I.P', description = 'Aucun véhicule dans votre garage.', type = 'error' })
        return
    end

    local options = {}
    for _, v in ipairs(vehicles) do
        table.insert(options, {
            title       = v.vehicle_label,
            description = v.vehicle_model,
            icon        = 'car',
            onSelect    = function()
                TriggerServerEvent('boutique:spawnVehicle', v.vehicle_model, npcId)
            end,
        })
    end

    lib.registerContext({
        id      = 'boutique_garage',
        title   = '🚗 Garage V.I.P',
        options = options,
    })
    lib.showContext('boutique_garage')
end)

-- ─── Réception : spawner le véhicule ─────────────────────────────────────────
RegisterNetEvent('boutique:doSpawnVehicle', function(model, spawnData, mods, plate)
    if CurrentGarageVeh and DoesEntityExist(CurrentGarageVeh) and not IsEntityDead(CurrentGarageVeh) then
        lib.notify({ title = 'Garage V.I.P', description = 'Votre véhicule est déjà sorti. Détruisez-le ou attendez qu\'il disparaisse.', type = 'error' })
        return
    end
    CurrentGarageVeh = nil

    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        if GetGameTimer() - t > 10000 then
            lib.notify({ title = 'Garage', description = 'Modèle introuvable : ' .. model, type = 'error' })
            return
        end
        Wait(100)
    end

    local sx, sy, sz, sh
    if spawnData then
        sx, sy, sz, sh = spawnData.x, spawnData.y, spawnData.z, spawnData.heading
    else
        local ped = PlayerPedId()
        local c   = GetEntityCoords(ped)
        local h   = GetEntityHeading(ped)
        sx = c.x + math.cos(math.rad(h)) * 5.0
        sy = c.y + math.sin(math.rad(h)) * 5.0
        local found, gz = GetGroundZFor_3dCoord(sx, sy, c.z + 5.0, false)
        sz = found and gz or c.z
        sh = h
    end

    local veh = CreateVehicle(hash, sx, sy, sz, sh, true, false)
    if plate then SetVehicleNumberPlateText(veh, plate) end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetModelAsNoLongerNeeded(hash)
    CurrentGarageVeh    = veh
    CurrentVehicleModel = model
    CurrentVehicleMods  = {}
    CurrentVehicleMods.body_mods = {}

    local plate = GetVehicleNumberPlateText(veh)
    TriggerEvent('qb-vehiclekeys:client:AddKeys', plate)
    TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
    TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), 1)

    Wait(300)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    SetVehicleEngineOn(veh, true, true, false)

    -- Réappliquer les mods sauvegardés
    if mods then
        ApplyVehicleMods(veh, mods)
        CurrentVehicleMods = {
            primary_color   = mods.primary_color,
            secondary_color = mods.secondary_color,
            pearl_color     = mods.pearl_color,
            wheel_color     = mods.wheel_color,
            wheel_type      = mods.wheel_type,
            wheel_mod       = mods.wheel_mod,
            window_tint     = mods.window_tint,
            xenon_enabled   = mods.xenon_enabled == 1,
            xenon_color     = mods.xenon_color,
            neon_left       = mods.neon_left  == 1,
            neon_right      = mods.neon_right == 1,
            neon_front      = mods.neon_front == 1,
            neon_back       = mods.neon_back  == 1,
            neon_r          = mods.neon_r,
            neon_g          = mods.neon_g,
            neon_b          = mods.neon_b,
        }
    end

    lib.notify({ title = 'Garage V.I.P', description = 'Véhicule sorti !', type = 'success' })
end)

-- ─── Réception : ouvrir panel joueur ─────────────────────────────────────────
RegisterNetEvent('boutique:open', function(items, coins, ownedIds)
    SetNuiFocus(true, true)
    SendNUIMessage({
        type       = 'openPlayer',
        items      = items,
        coins      = coins,
        categories = Config.Categories,
        tebexUrl   = Config.TebexUrl,
        ownedIds   = ownedIds or {},
    })
end)

RegisterNetEvent('boutique:adminLogsData', function(logs, coins)
    SendNUIMessage({ type = 'adminLogsData', logs = logs, coins = coins })
end)

-- ─── Réception : ouvrir panel admin ──────────────────────────────────────────
RegisterNetEvent('boutique:adminOpen', function(items)
    local npcs = {}
    for _, n in ipairs(GarageNpcs) do
        table.insert(npcs, {
            id            = n.id,
            name          = n.name,
            x             = n.x,
            y             = n.y,
            z             = n.z,
            heading       = n.heading,
            spawn_x       = n.spawn_x,
            spawn_y       = n.spawn_y,
            spawn_z       = n.spawn_z,
            spawn_heading = n.spawn_heading,
        })
    end
    local cnpcs = {}
    for _, n in ipairs(CustomNpcs) do
        table.insert(cnpcs, { id = n.id, name = n.name, x = n.x, y = n.y, z = n.z, heading = n.heading })
    end
    SetNuiFocus(true, true)
    SendNUIMessage({
        type       = 'openAdmin',
        items      = items,
        npcs       = npcs,
        customNpcs = cnpcs,
        categories = Config.Categories,
    })
end)

-- ─── Sync admin NPCs ──────────────────────────────────────────────────────────
RegisterNetEvent('boutique:adminGarageNpcSync', function(npcs)
    SendNUIMessage({ type = 'adminGarageNpcSync', npcs = npcs })
end)

-- ─── Réception : mise à jour coins ───────────────────────────────────────────
RegisterNetEvent('boutique:updateCoins', function(coins)
    SendNUIMessage({ type = 'updateCoins', coins = coins })
end)

-- ─── Réception : sync items admin ────────────────────────────────────────────
RegisterNetEvent('boutique:adminSync', function(items)
    SendNUIMessage({ type = 'adminSync', items = items })
end)

-- ─── NUI callbacks ────────────────────────────────────────────────────────────
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback('adminGetLogs', function(_, cb)
    TriggerServerEvent('boutique:adminGetLogs')
    cb({})
end)

RegisterNUICallback('buy', function(data, cb)
    TriggerServerEvent('boutique:buy', data.id, data.qty)
    cb({})
end)

RegisterNUICallback('adminSave', function(data, cb)
    TriggerServerEvent('boutique:adminSave', data)
    cb({})
end)

RegisterNUICallback('adminDelete', function(data, cb)
    TriggerServerEvent('boutique:adminDelete', data.id)
    cb({})
end)

RegisterNUICallback('placeGarageNpc', function(data, cb)
    local ped     = PlayerPedId()
    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    TriggerServerEvent('boutique:placeGarageNpc', { x = coords.x, y = coords.y, z = coords.z }, heading, data.name or 'Garage')
    cb({})
end)

RegisterNUICallback('setGarageNpcSpawn', function(data, cb)
    local ped     = PlayerPedId()
    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    TriggerServerEvent('boutique:setGarageNpcSpawn', data.id, { x = coords.x, y = coords.y, z = coords.z }, heading)
    cb({})
end)

RegisterNUICallback('deleteGarageNpc', function(data, cb)
    TriggerServerEvent('boutique:deleteGarageNpc', data.id)
    cb({})
end)

-- ─── Sync Custom NPCs ────────────────────────────────────────────────────────
RegisterNetEvent('boutique:syncCustomNpcs', function(npcs)
    for id, ped in pairs(CustomNpcPeds) do
        if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    CustomNpcPeds  = {}
    CustomSpawning = {}
    CustomNpcs     = {}
    for _, n in ipairs(npcs) do
        CustomNpcs[#CustomNpcs + 1] = { id = n.id, name = n.name, x = n.x, y = n.y, z = n.z, heading = n.heading }
    end
end)

RegisterNetEvent('boutique:adminCustomNpcSync', function(npcs)
    SendNUIMessage({ type = 'adminCustomNpcSync', npcs = npcs })
end)

-- ─── Spawn NPC Atelier ────────────────────────────────────────────────────────
local function SpawnCustomNpc(npcData)
    local id    = npcData.id
    local model = GetHashKey(Config.CustomNpcModel)
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) do
        if GetGameTimer() - t > 10000 then CustomSpawning[id] = nil; return end
        Wait(100)
    end
    local ped = CreatePed(4, model, npcData.x, npcData.y, npcData.z, npcData.heading, false, true)
    CustomNpcPeds[id] = ped
    SetModelAsNoLongerNeeded(model)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetPedCanRagdoll(ped, false)
    SetPedCanBeDraggedOut(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, false)
    TaskStandStill(ped, -1)
    local w = 0
    while DoesEntityExist(ped) and not HasCollisionLoadedAroundEntity(ped) and w < 50 do
        Wait(200); w = w + 1
    end
    local finalZ  = npcData.z
    local snapped = false
    for _ = 1, 30 do
        if not DoesEntityExist(ped) then CustomSpawning[id] = nil; return end
        local found, gz = GetGroundZFor_3dCoord(npcData.x, npcData.y, npcData.z + 10.0, false)
        if found and gz > 0.0 and gz >= npcData.z - 2.0 and gz <= npcData.z + 1.0 then
            SetEntityCoords(ped, npcData.x, npcData.y, gz, false, false, false, false)
            finalZ  = gz
            snapped = true
            break
        end
        Wait(200)
    end
    if not snapped and DoesEntityExist(ped) then
        SetEntityCoords(ped, npcData.x, npcData.y, npcData.z, false, false, false, false)
    end
    if DoesEntityExist(ped) then
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        TaskStandStill(ped, -1)
    end
    CustomSpawning[id] = nil
    CreateThread(function()
        local snapTick = 0
        while DoesEntityExist(ped) and CustomNpcPeds[id] == ped do
            Wait(100)
            FreezeEntityPosition(ped, true)
            SetEntityCollision(ped, false, false)
            snapTick = snapTick + 1
            if snapTick >= 5 then
                snapTick = 0
                local cx, cy, cz = table.unpack(GetEntityCoords(ped))
                local found, gz = GetGroundZFor_3dCoord(cx, cy, cz + 5.0, false)
                if found and gz > 0.0 and gz >= npcData.z - 2.0 and gz <= npcData.z + 1.0 and math.abs(gz - cz) > 0.15 then
                    SetEntityCoords(ped, cx, cy, gz, false, false, false, false)
                    finalZ = gz
                elseif math.abs(cz - finalZ) > 0.25 then
                    SetEntityCoords(ped, npcData.x, npcData.y, finalZ, false, false, false, false)
                end
            end
        end
    end)
end

-- ─── Thread Atelier NPCs ──────────────────────────────────────────────────────
CreateThread(function()
    while true do
        if #CustomNpcs == 0 then
            Wait(500)
        else
            Wait(0)
            local playerPed    = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local closest, closestDist = nil, 3.0

            for i = 1, #CustomNpcs do
                local n = CustomNpcs[i]
                local d = #(playerCoords - vector3(n.x, n.y, n.z))

                if d < 20.0 then
                    DrawText3D(n.x, n.y, n.z, 'ATELIER V.I.P')
                end

                local ped = CustomNpcPeds[n.id]
                if not (ped and DoesEntityExist(ped)) and not CustomSpawning[n.id] then
                    CustomNpcPeds[n.id] = nil
                    CustomSpawning[n.id] = true
                    local nd = n
                    CreateThread(function() SpawnCustomNpc(nd) end)
                end

                if d < closestDist then closest = n; closestDist = d end
            end

            if closest and closestDist < 2.5 then
                NearCustomNpc = closest
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(0.38, 0.38)
                SetTextColour(255, 255, 255, 230)
                SetTextDropShadow()
                SetTextOutline()
                SetTextEntry('STRING')
                AddTextComponentString('~g~[E]~w~ Atelier V.I.P')
                DrawText(0.5, 0.92)
            else
                NearCustomNpc = nil
            end

            if NearCustomNpc and IsControlJustReleased(0, 38) then
                TriggerServerEvent('boutique:requestCustomShop')
            end
        end
    end
end)

-- ─── Ouvrir panel custom shop ─────────────────────────────────────────────────
RegisterNetEvent('boutique:openCustomShop', function()
    if not CurrentGarageVeh or not DoesEntityExist(CurrentGarageVeh) then
        lib.notify({ title = 'Atelier V.I.P', description = 'Sortez votre véhicule garage pour le personnaliser.', type = 'error' })
        return
    end
    SetVehicleModKit(CurrentGarageVeh, 0)
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'openCustomShop' })
end)

-- ─── NUI callbacks Atelier ────────────────────────────────────────────────────
RegisterNUICallback('applyColor', function(data, cb)
    local veh = CurrentGarageVeh
    if not veh or not DoesEntityExist(veh) then cb({}); return end
    local slot = data.slot
    if slot == 'primary' then
        ClearVehicleCustomPrimaryColour(veh)
        local _, sec = GetVehicleColours(veh)
        SetVehicleColours(veh, data.index, sec)
        CurrentVehicleMods.primary_color = data.index
    elseif slot == 'secondary' then
        ClearVehicleCustomSecondaryColour(veh)
        local pri, _ = GetVehicleColours(veh)
        SetVehicleColours(veh, pri, data.index)
        CurrentVehicleMods.secondary_color = data.index
    elseif slot == 'pearlescent' then
        local _, wc = GetVehiclePearlescentColour(veh)
        SetVehiclePearlescentColour(veh, data.index, wc)
        CurrentVehicleMods.pearl_color = data.index
    elseif slot == 'wheelcolor' then
        local pc, _ = GetVehiclePearlescentColour(veh)
        SetVehiclePearlescentColour(veh, pc, data.index)
        CurrentVehicleMods.wheel_color = data.index
    end
    SaveCurrentMods()
    cb({})
end)

RegisterNUICallback('applyWheelType', function(data, cb)
    local veh = CurrentGarageVeh
    if not veh or not DoesEntityExist(veh) then cb({ count = 0 }); return end
    SetVehicleWheelType(veh, data.wheelType)
    SetVehicleMod(veh, 23, 0, false)
    CurrentVehicleMods.wheel_type = data.wheelType
    CurrentVehicleMods.wheel_mod  = 0
    SaveCurrentMods()
    local count = GetNumVehicleMods(veh, 23)
    cb({ count = count })
end)

RegisterNUICallback('applyWheelMod', function(data, cb)
    local veh = CurrentGarageVeh
    if not veh or not DoesEntityExist(veh) then cb({}); return end
    SetVehicleMod(veh, 23, data.modIndex, false)
    CurrentVehicleMods.wheel_mod = data.modIndex
    SaveCurrentMods()
    cb({})
end)

RegisterNUICallback('applyTint', function(data, cb)
    local veh = CurrentGarageVeh
    if not veh or not DoesEntityExist(veh) then cb({}); return end
    SetVehicleWindowTint(veh, data.tint)
    CurrentVehicleMods.window_tint = data.tint
    SaveCurrentMods()
    cb({})
end)

RegisterNUICallback('applyXenon', function(data, cb)
    local veh = CurrentGarageVeh
    if not veh or not DoesEntityExist(veh) then cb({}); return end
    SetVehicleXenonLightsEnabled(veh, data.enabled)
    if data.enabled and data.colorIndex ~= nil then
        SetVehicleXenonLightsColor(veh, data.colorIndex)
        CurrentVehicleMods.xenon_color = data.colorIndex
    end
    CurrentVehicleMods.xenon_enabled = data.enabled
    SaveCurrentMods()
    cb({})
end)

RegisterNUICallback('applyNeon', function(data, cb)
    local veh = CurrentGarageVeh
    if not veh or not DoesEntityExist(veh) then cb({}); return end
    SetVehicleNeonLights(veh, data.r or 0, data.g or 255, data.b or 0)
    SetVehicleNeonEnabled(veh, 0, data.left  or false)
    SetVehicleNeonEnabled(veh, 1, data.right or false)
    SetVehicleNeonEnabled(veh, 2, data.front or false)
    SetVehicleNeonEnabled(veh, 3, data.back  or false)
    CurrentVehicleMods.neon_left  = data.left  or false
    CurrentVehicleMods.neon_right = data.right or false
    CurrentVehicleMods.neon_front = data.front or false
    CurrentVehicleMods.neon_back  = data.back  or false
    CurrentVehicleMods.neon_r     = data.r or 0
    CurrentVehicleMods.neon_g     = data.g or 255
    CurrentVehicleMods.neon_b     = data.b or 0
    SaveCurrentMods()
    cb({})
end)

RegisterNUICallback('getBodyModCounts', function(data, cb)
    local veh = CurrentGarageVeh
    if not veh or not DoesEntityExist(veh) then cb({}); return end
    SetVehicleModKit(veh, 0)
    local counts = {}
    for _, mt in ipairs({0,1,2,3,4,5,6,7,8,9,10}) do
        counts[tostring(mt)] = GetNumVehicleMods(veh, mt)
    end
    cb(counts)
end)

RegisterNUICallback('applyBodyMod', function(data, cb)
    local veh = CurrentGarageVeh
    if not veh or not DoesEntityExist(veh) then cb({}); return end
    local modType = tonumber(data.modType)
    local modIdx  = tonumber(data.modIndex)
    SetVehicleModKit(veh, 0)
    SetVehicleMod(veh, modType, modIdx, false)
    if not CurrentVehicleMods.body_mods then CurrentVehicleMods.body_mods = {} end
    CurrentVehicleMods.body_mods[tostring(modType)] = modIdx
    SaveCurrentMods()
    cb({})
end)

RegisterNUICallback('placeCustomNpc', function(data, cb)
    local ped     = PlayerPedId()
    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    TriggerServerEvent('boutique:placeCustomNpc', { x = coords.x, y = coords.y, z = coords.z }, heading, data.name or 'Atelier')
    cb({})
end)

RegisterNUICallback('deleteCustomNpc', function(data, cb)
    TriggerServerEvent('boutique:deleteCustomNpc', data.id)
    cb({})
end)

-- ─── Chargement initial ───────────────────────────────────────────────────────
TriggerServerEvent('boutique:requestGarageNpcs')
TriggerServerEvent('boutique:requestCustomNpcs')

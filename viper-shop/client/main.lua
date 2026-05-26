local NPCs         = { weapons = nil,  ammo = nil,  illegal = nil  }
local Positions    = { weapons = nil,  ammo = nil,  illegal = nil  }
local Spawning     = { weapons = false, ammo = false, illegal = false }
local Blips        = {}

local function UpdateBlip(shopType, pos)
    if Blips[shopType] and DoesBlipExist(Blips[shopType]) then
        RemoveBlip(Blips[shopType])
    end
    local shop = Config.Shops[shopType]
    local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(blip, 110)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, shop.blipColor)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(shop.label)
    EndTextCommandSetBlipName(blip)
    Blips[shopType] = blip
end

-- ─── Spawn PNJ (physique vipergun) ────────────────────────────────────────────
local function SpawnNPC(shopType)
    if Spawning[shopType] then return end
    Spawning[shopType] = true

    if NPCs[shopType] and DoesEntityExist(NPCs[shopType]) then
        SetEntityAsMissionEntity(NPCs[shopType], false, true)
        DeleteEntity(NPCs[shopType])
        NPCs[shopType] = nil
    end

    local pos = Positions[shopType]
    if not pos then Spawning[shopType] = false; return end

    local shop = Config.Shops[shopType]
    local hash = GetHashKey(shop.model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 50 do Wait(100); t = t + 1 end
    if not HasModelLoaded(hash) then Spawning[shopType] = false; return end

    local ped = CreatePed(4, hash, pos.x, pos.y, pos.z, pos.w, false, true)
    if not DoesEntityExist(ped) then Spawning[shopType] = false; return end
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, 0)
    SetPedDiesWhenInjured(ped, false)
    SetEntityAsMissionEntity(ped, true, true)
    TaskStandStill(ped, -1)
    -- collision active ici : HasCollisionLoadedAroundEntity en a besoin
    SetModelAsNoLongerNeeded(hash)
    NPCs[shopType] = ped
    Spawning[shopType] = false

    CreateThread(function()
        local w = 0
        while DoesEntityExist(ped) and w < 50 do
            if HasCollisionLoadedAroundEntity(ped) then break end
            Wait(200); w = w + 1
        end

        local finalZ  = pos.z
        local snapped = false
        for _ = 1, 30 do
            if not DoesEntityExist(ped) then return end
            local found, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 10.0, false)
            if found and gz > 0.0 and gz >= pos.z - 2.0 and gz <= pos.z + 1.0 then
                SetEntityCoords(ped, pos.x, pos.y, gz, false, false, false, false)
                finalZ  = gz
                snapped = true
                break
            end
            Wait(200)
        end
        if not snapped and DoesEntityExist(ped) then
            SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
        end

        if not DoesEntityExist(ped) then return end
        -- GEL + désactivation collision APRÈS le snap
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        TaskStandStill(ped, -1)

        local tick = 0
        while DoesEntityExist(ped) do
            Wait(100)
            FreezeEntityPosition(ped, true)
            SetEntityCollision(ped, false, false)
            tick = tick + 1
            if tick >= 5 then
                tick = 0
                local cx, cy, cz = table.unpack(GetEntityCoords(ped))
                local found, gz = GetGroundZFor_3dCoord(cx, cy, cz + 5.0, false)
                if found and gz > 0.0 and gz >= pos.z - 2.0 and gz <= pos.z + 1.0 and math.abs(gz - cz) > 0.15 then
                    SetEntityCoords(ped, cx, cy, gz, false, false, false, false)
                    finalZ = gz
                elseif math.abs(cz - finalZ) > 0.25 then
                    SetEntityCoords(ped, pos.x, pos.y, finalZ, false, false, false, false)
                end
            end
        end
    end)

end

-- ─── Hologramme ───────────────────────────────────────────────────────────────
local function DrawHolo(shopType, x, y, z, dist)
    local shop = Config.Shops[shopType]
    local c    = shop.holoColor

    if dist < Config.HoloDist then
        local pulse = (math.sin(GetGameTimer() / 400.0) + 1.0) * 0.5
        DrawMarker(28, x, y, z - 0.95,
            0,0,0, 0,0,0, 0.8, 0.8, 0.06,
            c.r, c.g, c.b, math.floor((120 + 95 * pulse) * 0.4),
            false, false, 2, false, nil, nil, false)
    end

    local onScreen, sx, sy = World3dToScreen2d(x, y, z + 1.25)
    if not onScreen then return end
    local camCoords = GetGameplayCamCoords()
    local d = #(camCoords - vector3(x, y, z))
    if d > Config.HoloDist then return end
    local scale = math.min((1 / d) * 2.8, 0.6) * (1 / GetGameplayCamFov()) * 100
    SetTextScale(0.0, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(c.r, c.g, c.b, 230)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 180)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(1)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(shop.holoText)
    EndTextCommandDisplayText(sx, sy)
end

-- ─── Sync positions ────────────────────────────────────────────────────────────
RegisterNetEvent('viper_shop:syncPositions', function(positions)
    print('^2[viper-shop client]^7 syncPositions reçu: ' .. json.encode(positions))
    for shopType, pos in pairs(positions) do
        if Config.Shops[shopType] and pos then
            Positions[shopType] = pos
            UpdateBlip(shopType, pos)
            SpawnNPC(shopType)
        end
    end
end)

RegisterNetEvent('viper_shop:syncNpcPos', function(shopType, pos)
    Positions[shopType] = pos
    UpdateBlip(shopType, pos)
    if NPCs[shopType] and DoesEntityExist(NPCs[shopType]) then
        local ped = NPCs[shopType]
        FreezeEntityPosition(ped, false)
        SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
        SetEntityHeading(ped, pos.w)
        Wait(300)
        local found, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 10.0, false)
        if found and gz > 0.0 and gz >= pos.z - 2.0 and gz <= pos.z + 1.0 then
            SetEntityCoords(ped, pos.x, pos.y, gz, false, false, false, false)
        end
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        TaskStandStill(ped, -1)
    else
        SpawnNPC(shopType)
    end
end)

-- ─── Boucle interaction — hologrammes pour TOUS les NPCs ─────────────────────
CreateThread(function()
    while true do
        local myCoords = GetEntityCoords(PlayerPedId())
        local nearest  = nil
        local nearDist = Config.InteractDist + 1.0
        local anyVisible = false

        for shopType, ped in pairs(NPCs) do
            if ped and DoesEntityExist(ped) then
                local npcCoords = GetEntityCoords(ped)
                local dist      = #(myCoords - npcCoords)

                -- Hologramme pour chaque NPC visible
                if dist <= Config.HoloDist + 1.0 then
                    DrawHolo(shopType, npcCoords.x, npcCoords.y, npcCoords.z, dist)
                    anyVisible = true
                end

                -- Suivre le plus proche pour l'interaction
                if dist < nearDist then
                    nearDist = dist
                    nearest  = { type = shopType, coords = npcCoords, dist = dist }
                end
            end
        end

        if nearest and nearest.dist < Config.InteractDist then
            SetTextScale(0.4, 0.4)
            SetTextFont(0)
            SetTextProportional(1)
            SetTextColour(255, 255, 255, 220)
            SetTextOutline()
            SetTextEntry('STRING')
            SetTextCentre(true)
            AddTextComponentString('[E] ' .. Config.Shops[nearest.type].label)
            DrawText(0.5, 0.9)

            if IsControlJustPressed(0, 38) then
                TriggerServerEvent('viper_shop:openShop', nearest.type)
            end
        end

        if anyVisible or (nearest and nearest.dist < Config.InteractDist) then
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- ─── Surveillance PNJs — respawn toutes les 2s si un PNJ disparaît ──────────
CreateThread(function()
    while true do
        Wait(2000)
        local ok, err = pcall(function()
            for shopType, pos in pairs(Positions) do
                if pos then
                    local ped = NPCs[shopType]
                    if not ped or not DoesEntityExist(ped) then
                        if not Spawning[shopType] then
                            SpawnNPC(shopType)
                        end
                    end
                end
            end
        end)
        if not ok then print('^3[viper-shop] Surveillance error: ' .. tostring(err) .. '^0') end
    end
end)

-- ─── Démarrage / arrêt ───────────────────────────────────────────────────────
AddEventHandler('onClientResourceStart', function(name)
    if name ~= GetCurrentResourceName() then return end
    TriggerServerEvent('viper_shop:requestPositions')
end)

-- Demande immédiate + retries jusqu'à réception des positions
TriggerServerEvent('viper_shop:requestPositions')
CreateThread(function()
    local delays = { 1000, 3000, 6000, 12000, 20000 }
    for _, delay in ipairs(delays) do
        Wait(delay)
        local hasAny = false
        for _, p in pairs(Positions) do if p then hasAny = true; break end end
        if hasAny then return end
        print('^3[viper-shop client]^7 retry requestPositions (positions vides)')
        TriggerServerEvent('viper_shop:requestPositions')
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    for shopType, ped in pairs(NPCs) do
        if ped and DoesEntityExist(ped) then
            DeleteEntity(ped)
            NPCs[shopType] = nil
        end
    end
    for _, blip in pairs(Blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)

-- ─── Commande admin ───────────────────────────────────────────────────────────
RegisterCommand('adminshop', function()
    TriggerServerEvent('viper_shop:adminOpen')
end, false)

-- ─── Réception données ───────────────────────────────────────────────────────
RegisterNetEvent('viper_shop:adminReceiveItems', function(items)
    SendNUIMessage({ type = 'openAdmin', items = items })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('viper_shop:receiveShop', function(shopType, items, sellItems)
    SendNUIMessage({
        type      = 'openShop',
        shopType  = shopType,
        shopLabel = Config.Shops[shopType].label,
        items     = items,
        sellItems = sellItems or {},
    })
    SetNuiFocus(true, true)
end)

-- ─── NUI Callbacks ────────────────────────────────────────────────────────────
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('adminCreate', function(data, cb)
    TriggerServerEvent('viper_shop:adminCreate', data)
    cb('ok')
end)

RegisterNUICallback('adminEdit', function(data, cb)
    TriggerServerEvent('viper_shop:adminEdit', data)
    cb('ok')
end)

RegisterNUICallback('adminDelete', function(data, cb)
    TriggerServerEvent('viper_shop:adminDelete', data.id)
    cb('ok')
end)

RegisterNUICallback('spawnNpcHere', function(data, cb)
    local ped     = PlayerPedId()
    local pos     = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    TriggerServerEvent('viper_shop:saveNpcPos', data.shopType, pos.x, pos.y, pos.z, heading)
    cb('ok')
end)

RegisterNUICallback('tpToNpc', function(data, cb)
    local npc = NPCs[data.shopType]
    if npc and DoesEntityExist(npc) then
        local coords = GetEntityCoords(npc)
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
    end
    cb('ok')
end)

RegisterNUICallback('buy', function(data, cb)
    TriggerServerEvent('viper_shop:buy', data.id, data.qty)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('sell', function(data, cb)
    TriggerServerEvent('viper_shop:sell', data.name, data.qty)
    SetNuiFocus(false, false)
    cb('ok')
end)
